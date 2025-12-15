import { serve } from 'https://deno.land/std/http/server.ts';
import { createClient } from 'jsr:@supabase/supabase-js';

serve(async (req) => {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SERVICE_ROLE = Deno.env.get('SERVICE_ROLE');
    if (!SUPABASE_URL || !SERVICE_ROLE) {
      return new Response(JSON.stringify({ error: 'Missing SUPABASE_URL or SERVICE_ROLE' }), { status: 500 });
    }

    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

    // Only allow POST
    if (req.method !== 'POST') return new Response(null, { status: 405 });

    const authHeader = req.headers.get('authorization') || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });

    // verify caller
    const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(token);
    if (userErr || !userData?.user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
    const callerId = userData.user.id;

    const { data: profile, error: profileErr } = await supabaseAdmin.from('admin_users').select('role, is_active').eq('id', callerId).single();
    if (profileErr || !profile || profile.role !== 'super_admin' || profile.is_active !== true) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403 });
    }

    const body = await req.json().catch(() => ({}));
    const email = (body.email || '').trim();
    const nama = body.nama || null;
    if (!email) return new Response(JSON.stringify({ error: 'Email is required' }), { status: 400 });
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) return new Response(JSON.stringify({ error: 'Invalid email' }), { status: 400 });

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
      return new Response(JSON.stringify({ error: createErr.message || String(createErr) }), { status: 500 });
    }
    if (!created || !created.user || !created.user.id) {
      console.error('createUser returned no user data', created);
      return new Response(JSON.stringify({ error: 'Failed to create user' }), { status: 500 });
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
      return new Response(JSON.stringify({ error: adminInsertErr.message || String(adminInsertErr) }), { status: 500 });
    }

    // optionally upsert profiles.must_change_password
    try {
      await supabaseAdmin.from('profiles').upsert({ id: userId, must_change_password: true }, { onConflict: 'id' });
    } catch (pErr) {
      console.warn('profiles upsert warning:', pErr);
    }

    return new Response(JSON.stringify({ email, password }), { status: 200 });
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
