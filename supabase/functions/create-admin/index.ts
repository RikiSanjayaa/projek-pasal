// Suppress type/lint errors for this Edge Function (runtime is Deno/Supabase)
// - `// @ts-nocheck` disables TypeScript checking for this file
// - `// deno-lint-ignore-file` disables Deno linter warnings
// - `/* eslint-disable */` disables ESLint for this file
// Use these sparingly; keep function logic reviewed for security.
// @ts-nocheck
// deno-lint-ignore-file
/* eslint-disable */

import { serve } from 'https://deno.land/std/http/server.ts';
import { createClient } from 'jsr:@supabase/supabase-js';

serve(async (req) => {
  const CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as Record<string, string>

  const json = (obj: unknown, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json', ...CORS_HEADERS } })

  const text = (str: string, status = 200) => new Response(str, { status, headers: { 'Content-Type': 'text/plain;charset=UTF-8', ...CORS_HEADERS } })

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS })
  }
  try {
    // Support multiple common secret names (dashboard may store service role under different keys)
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || Deno.env.get('NEXT_PUBLIC_SUPABASE_URL') || Deno.env.get('SUPABASE_URL');
    const SERVICE_ROLE = Deno.env.get('SERVICE_ROLE') || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_SERVICE_ROLE');

    if (!SUPABASE_URL || !SERVICE_ROLE) {
      const missing: string[] = []
      if (!SUPABASE_URL) missing.push('SUPABASE_URL')
      if (!SERVICE_ROLE) missing.push('SERVICE_ROLE or SUPABASE_SERVICE_ROLE_KEY')
      return json({ error: `Missing environment secrets: ${missing.join(', ')}` }, 500)
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    // Only allow POST
    if (req.method !== 'POST') return new Response(null, { status: 405, headers: CORS_HEADERS });

    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json({ error: 'Unauthorized' }, 401)

    // verify caller
    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userData?.user) return json({ error: 'Unauthorized' }, 401)
    const callerId = userData.user.id;

    const { data: profile, error: profileErr } = await supabaseAdmin.from('admin_users').select('role, is_active').eq('id', callerId).single();
    if (profileErr || !profile || profile.role !== 'super_admin' || profile.is_active !== true) {
      return json({ error: 'Forbidden' }, 403)
    }

    const body = await req.json().catch(() => ({}));
    const email = (body.email || '').trim();
    const nama = body.nama || null;
    if (!email) return json({ error: 'Email is required' }, 400)
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) return json({ error: 'Invalid email' }, 400)

    // generate a temporary password
    const password = crypto.randomUUID();

    // create user using service role
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    } as any);

    if (createErr) {
      console.error('createUser error:', createErr);
      return json({ error: createErr.message || String(createErr) }, 500)
    }
    if (!created || !created.user || !created.user.id) {
      console.error('createUser returned no user data', created);
      return json({ error: 'Failed to create user' }, 500)
    }

    const userId = created.user.id;

    // insert into admin_users
    const { data: adminInsert, error: adminInsertErr } = await supabaseAdmin.from('admin_users').insert({
      id: userId,
      email,
      nama: nama ?? null,
      role: 'admin',
      is_active: true
    });
    if (adminInsertErr) {
      console.error('admin_users insert error:', adminInsertErr);
      // rollback created auth user
      try { await supabaseAdmin.auth.admin.deleteUser(userId); } catch (delErr) { console.error('Rollback failed:', delErr); }
      return json({ error: adminInsertErr.message || String(adminInsertErr) }, 500)
    }

    // optionally upsert profiles.must_change_password
    try {
      await supabaseAdmin.from('profiles').upsert({ id: userId, must_change_password: true }, { onConflict: 'id' });
    } catch (pErr) {
      console.warn('profiles upsert warning:', pErr);
    }

    return json({ email, password }, 200)
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500)
  }
});
