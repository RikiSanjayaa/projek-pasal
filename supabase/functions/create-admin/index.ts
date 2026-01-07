// Supabase Edge Function: create-admin
// Creates a new admin user with temporary password (super_admin only)

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

  const text = (str: string, status = 200) => new Response(str, { status, headers: { 'Content-Type': 'text/plain;charset=UTF-8', ...CORS_HEADERS } })

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

    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Unauthorized' }, 401)

    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userData?.user) return json({ error: 'Unauthorized' }, 401)
    const callerId = userData.user.id;

    const { data: profile, error: profileErr } = await supabaseAdmin.from('admin_users').select('role, is_active').eq('id', callerId).single();
    if (profileErr || !profile || profile.role !== 'super_admin' || profile.is_active !== true) {
      return json({ error: 'Forbidden' }, 403)
    }

    const body = await req.json().catch(() => ({})) as { email?: string; nama?: string };
    const email = (body.email || '').trim();
    const nama = body.nama || null;
    if (!email) return json({ error: 'Email is required' }, 400)

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) return json({ error: 'Invalid email' }, 400)
    if (email.length > 254) return json({ error: 'Email too long' }, 400)

    const password = crypto.randomUUID();

    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    } as any);

    if (createErr) {
      return json({ error: createErr.message || 'Failed to create user' }, 500)
    }
    if (!created?.user?.id) {
      return json({ error: 'Failed to create user' }, 500)
    }

    const userId = created.user.id;

    const { error: adminInsertErr } = await supabaseAdmin.from('admin_users').insert({
      id: userId,
      email,
      nama: nama ?? null,
      role: 'admin',
      is_active: true
    });

    if (adminInsertErr) {
      await supabaseAdmin.auth.admin.deleteUser(userId).catch(() => { });
      return json({ error: adminInsertErr.message || 'Failed to create admin record' }, 500)
    }

    await supabaseAdmin.from('profiles').upsert({ id: userId, must_change_password: true }, { onConflict: 'id' }).catch(() => { });

    return json({ email, password }, 200)
  } catch (err) {
    return json({ error: 'Internal server error' }, 500)
  }
});
