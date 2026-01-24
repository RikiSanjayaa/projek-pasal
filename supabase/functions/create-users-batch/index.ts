// Supabase Edge Function: create-users-batch
// Creates multiple mobile app users in batch with required passwords
// Users have 3-year access expiry

// deno-lint-ignore-file no-explicit-any
// @ts-nocheck

import { serve } from 'https://deno.land/std/http/server.ts';
import { createClient } from 'jsr:@supabase/supabase-js';

// Security: Get allowed origins from environment or use restrictive default
const getAllowedOrigin = (requestOrigin: string | null): string => {
  const allowedOrigins = Deno.env.get('ALLOWED_ORIGINS')?.split(',') || [];

  // If ALLOWED_ORIGINS is set, validate against it
  if (allowedOrigins.length > 0 && requestOrigin) {
    const normalizedOrigin = requestOrigin.replace(/\/$/, '');
    if (allowedOrigins.some(o => o.trim() === normalizedOrigin)) {
      return normalizedOrigin;
    }
  }

  // Fallback: Use SUPABASE_URL origin (same-origin requests from dashboard)
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  if (supabaseUrl && requestOrigin) {
    try {
      const supabaseOrigin = new URL(supabaseUrl).origin;
      if (requestOrigin === supabaseOrigin) {
        return supabaseOrigin;
      }
    } catch { /* ignore parse errors */ }
  }

  // Default: no origin allowed (will fail CORS for cross-origin requests)
  return '';
};

interface UserInput {
  email: string;
  nama?: string;
  password: string;
}

interface UserResult {
  email: string;
  nama: string;
  success: boolean;
  error?: string;
}

serve(async (req) => {
  const requestOrigin = req.headers.get('origin');
  const allowedOrigin = getAllowedOrigin(requestOrigin);

  const CORS_HEADERS = {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  } as Record<string, string>

  const json = (obj: unknown, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } })

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS })
  }

  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || Deno.env.get('NEXT_PUBLIC_SUPABASE_URL');
    const SERVICE_ROLE = Deno.env.get('SERVICE_ROLE') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!SUPABASE_URL || !SERVICE_ROLE) {
      const missing: string[] = []
      if (!SUPABASE_URL) missing.push('SUPABASE_URL')
      if (!SERVICE_ROLE) missing.push('SERVICE_ROLE')
      return json({ error: `Missing environment secrets: ${missing.join(', ')}` }, 500)
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    if (req.method !== 'POST') return new Response(null, { status: 405, headers: CORS_HEADERS });

    // Validate authorization header
    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Unauthorized' }, 401)

    // Verify the caller is an authenticated user
    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userData?.user) return json({ error: 'Unauthorized' }, 401)
    const callerId = userData.user.id;

    // Verify the caller is an active admin (any admin, not just super_admin)
    const { data: profile, error: profileErr } = await supabaseAdmin.from('admin_users').select('role, is_active, email').eq('id', callerId).single();
    if (profileErr || !profile || profile.is_active !== true) {
      return json({ error: 'Forbidden' }, 403)
    }

    // Parse and validate request body
    const body = await req.json().catch(() => ({})) as { users?: UserInput[] };
    const users = body.users;

    if (!users || !Array.isArray(users)) {
      return json({ error: 'Request body must contain "users" array' }, 400)
    }

    if (users.length === 0) {
      return json({ error: 'Users array cannot be empty' }, 400)
    }

    if (users.length > 500) {
      return json({ error: 'Maximum 500 users per batch' }, 400)
    }

    // Validate all users upfront
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const validationErrors: string[] = [];
    const seenEmails = new Set<string>();

    for (let i = 0; i < users.length; i++) {
      const user = users[i];
      const rowNum = i + 1;

      if (!user.email || typeof user.email !== 'string') {
        validationErrors.push(`Row ${rowNum}: Email is required`);
        continue;
      }

      const email = user.email.trim().toLowerCase();

      if (!emailRegex.test(email)) {
        validationErrors.push(`Row ${rowNum}: Invalid email format (${user.email})`);
      }

      if (email.length > 254) {
        validationErrors.push(`Row ${rowNum}: Email too long`);
      }

      if (seenEmails.has(email)) {
        validationErrors.push(`Row ${rowNum}: Duplicate email (${email})`);
      }
      seenEmails.add(email);

      if (!user.password || typeof user.password !== 'string') {
        validationErrors.push(`Row ${rowNum}: Password is required`);
        continue;
      }

      if (user.password.length < 6) {
        validationErrors.push(`Row ${rowNum}: Password must be at least 6 characters`);
      }
      if (!/\d/.test(user.password)) {
        validationErrors.push(`Row ${rowNum}: Password must contain at least 1 number`);
      }

      if (user.nama && user.nama.length > 255) {
        validationErrors.push(`Row ${rowNum}: Nama too long`);
      }
    }

    if (validationErrors.length > 0) {
      return json({
        error: 'Validation failed',
        validation_errors: validationErrors
      }, 400)
    }

    // Calculate expiry date (3 years from now)
    const now = new Date();
    const expiresAt = new Date(now.getTime() + (3 * 365 * 24 * 60 * 60 * 1000));

    // Process users
    const results: UserResult[] = [];
    let successCount = 0;
    let failedCount = 0;

    for (const userInput of users) {
      const email = userInput.email.trim().toLowerCase();
      const password = userInput.password;
      const nama = (userInput.nama || '').trim() || email.split('@')[0];

      try {
        // Create auth user
        const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true
        } as any);

        if (createErr) {
          results.push({ email, nama, success: false, error: createErr.message });
          failedCount++;
          continue;
        }

        if (!created?.user?.id) {
          results.push({ email, nama, success: false, error: 'Failed to create auth user' });
          failedCount++;
          continue;
        }

        const userId = created.user.id;

        // Create users table record
        const { error: userInsertErr } = await supabaseAdmin.from('users').insert({
          id: userId,
          email,
          nama,
          is_active: true,
          created_at: now.toISOString(),
          expires_at: expiresAt.toISOString(),
          created_by: callerId
        });

        if (userInsertErr) {
          // Rollback: delete the auth user if users record creation fails
          await supabaseAdmin.auth.admin.deleteUser(userId).catch(() => { });
          results.push({ email, nama, success: false, error: userInsertErr.message });
          failedCount++;
          continue;
        }

        results.push({ email, nama, success: true });
        successCount++;

        // Audit log for this individual user
        try {
          await supabaseAdmin.from('audit_logs').insert({
            admin_id: callerId,
            admin_email: profile.email || null,
            action: 'CREATE' as any,
            table_name: 'users',
            record_id: userId,
            old_data: null,
            new_data: {
              email,
              nama,
              expires_at: expiresAt.toISOString(),
              batch_import: true
            }
          });
        } catch (auditErr) {
          console.error('Audit log error for user:', email, auditErr);
        }

      } catch (err: any) {
        results.push({ email, nama, success: false, error: err?.message || 'Unknown error' });
        failedCount++;
      }
    }

    return json({
      success_count: successCount,
      failed_count: failedCount,
      results
    }, 200)

  } catch (err) {
    console.error('Batch create error:', err);
    return json({ error: 'Internal server error' }, 500)
  }
});
