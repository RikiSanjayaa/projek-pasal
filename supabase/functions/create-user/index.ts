// Supabase Edge Function: create-user
// Creates a new mobile app user with temporary password (any active admin)
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

serve(async (req) => {
  const requestOrigin = req.headers.get('origin');
  const allowedOrigin = getAllowedOrigin(requestOrigin);

  const CORS_HEADERS = {
    'Access-Control-Allow-Origin': allowedOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400', // Cache preflight for 24 hours
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
    const { data: profile, error: profileErr } = await supabaseAdmin.from('admin_users').select('role, is_active').eq('id', callerId).single();
    if (profileErr || !profile || profile.is_active !== true) {
      return json({ error: 'Forbidden' }, 403)
    }

    // Parse and validate request body
    const body = await req.json().catch(() => ({})) as { email?: string; nama?: string; password?: string };
    const email = (body.email || '').trim();
    const customPassword = (body.password || '').trim();

    // Nama defaults to email prefix if not provided
    let nama = (body.nama || '').trim();
    if (!nama && email) {
      nama = email.split('@')[0];
    }

    if (!email) return json({ error: 'Email is required' }, 400)

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) return json({ error: 'Invalid email format' }, 400)
    if (email.length > 254) return json({ error: 'Email too long' }, 400)
    if (nama.length > 255) return json({ error: 'Nama too long' }, 400)

    // Validate password if provided
    if (customPassword) {
      if (customPassword.length < 6) return json({ error: 'Password harus minimal 6 karakter' }, 400)
      if (!/\d/.test(customPassword)) return json({ error: 'Password harus mengandung minimal 1 angka' }, 400)
    }

    // Generate temporary password or use custom
    const password = customPassword || crypto.randomUUID();

    // Create auth user
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true  // Skip email verification
    } as any);

    if (createErr) {
      return json({ error: createErr.message || 'Failed to create user' }, 500)
    }
    if (!created?.user?.id) {
      return json({ error: 'Failed to create user' }, 500)
    }

    const userId = created.user.id;

    // Calculate expiry date (3 years from now)
    const now = new Date();
    const expiresAt = new Date(now.getTime() + (3 * 365 * 24 * 60 * 60 * 1000)); // 3 years in milliseconds

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
      return json({ error: userInsertErr.message || 'Failed to create user record' }, 500)
    }

    // Manual audit log (since service role bypasses RLS triggers)
    // Wrapped in try-catch to ensure audit failure doesn't affect user creation
    try {
      const { data: adminData } = await supabaseAdmin.from('admin_users').select('email').eq('id', callerId).single();
      await supabaseAdmin.from('audit_logs').insert({
        admin_id: callerId,
        admin_email: adminData?.email || null,
        action: 'CREATE' as any,
        table_name: 'users',
        record_id: userId,
        old_data: null,
        new_data: {
          id: userId,
          email,
          nama,
          is_active: true,
          expires_at: expiresAt.toISOString(),
          created_by: callerId
        }
      });
    } catch (auditErr) {
      console.error('Audit log error:', auditErr);
      // Continue - audit failure should not fail the operation
    }

    return json({ email, password, expires_at: expiresAt.toISOString() }, 200)
  } catch (err) {
    return json({ error: 'Internal server error' }, 500)
  }
});
