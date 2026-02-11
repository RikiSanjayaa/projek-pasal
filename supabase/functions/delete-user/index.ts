// Supabase Edge Function: delete-user
// Deletes a mobile app user from both auth and database (any active admin)

// deno-lint-ignore-file no-explicit-any
// @ts-nocheck


import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

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

Deno.serve(async (req) => {
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
    const body = await req.json().catch(() => ({})) as { user_id?: string };
    const userId = (body.user_id || '').trim();

    if (!userId) return json({ error: 'user_id is required' }, 400)

    // Verify the user exists and get full data for audit log
    const { data: targetUser, error: targetErr } = await supabaseAdmin.from('users').select('*').eq('id', userId).single();
    if (targetErr || !targetUser) {
      return json({ error: 'User not found' }, 404)
    }

    // Delete the user record from users table (cascade should handle user_devices)
    const { error: deleteUserErr } = await supabaseAdmin.from('users').delete().eq('id', userId);
    if (deleteUserErr) {
      return json({ error: deleteUserErr.message || 'Failed to delete user record' }, 500)
    }

    // Delete the auth user
    const { error: deleteAuthErr } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteAuthErr) {
      // User record already deleted, log but don't fail
      console.error('Failed to delete auth user:', deleteAuthErr.message);
      // Still return success since the user record is deleted
    }

    // Manual audit log (since service role bypasses RLS triggers)
    // Wrapped in try-catch to ensure audit failure doesn't affect the operation
    try {
      const { data: adminData } = await supabaseAdmin.from('admin_users').select('email').eq('id', callerId).single();
      await supabaseAdmin.from('audit_logs').insert({
        admin_id: callerId,
        admin_email: adminData?.email || null,
        action: 'DELETE' as any,
        table_name: 'users',
        record_id: userId,
        old_data: targetUser,
        new_data: null
      });
    } catch (auditErr) {
      console.error('Audit log error:', auditErr);
      // Continue - audit failure should not fail the operation
    }

    return json({ success: true, email: targetUser.email }, 200)
  } catch (err: any) {
    console.error('Delete user error:', err);
    return json({ 
      error: 'Internal server error',
      details: err.message || String(err)
    }, 500)
  }
});
