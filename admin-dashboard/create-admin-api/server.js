import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path'
import { fileURLToPath } from 'url'
import crypto from 'crypto';
import { createClient } from '@supabase/supabase-js';

// Load .env from the same directory as this file (create-admin-api/.env)
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
dotenv.config({ path: path.join(__dirname, '.env') })

const PORT = process.env.PORT || 3001;
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env');
  process.exit(1);
}

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false }
});

const app = express();
app.use(cors());
app.use(express.json());

async function getProfileByAccessToken(accessToken) {
  if (!accessToken) return null;
  // Try to get user info from token
  const { data: userData, error: userErr } = await supabaseAdmin.auth.getUser(accessToken);
  if (userErr || !userData?.user) return null;
  const userId = userData.user.id;
  // Check admin role from admin_users table
  const { data: profile, error: profileErr } = await supabaseAdmin
    .from('admin_users')
    .select('role')
    .eq('id', userId)
    .single();
  if (profileErr) return null;
  return { id: userId, profile };
}

app.post('/api/create-admin', async (req, res) => {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return res.status(401).json({ error: 'Unauthorized' });

    const caller = await getProfileByAccessToken(token);
    if (!caller || caller.profile?.role !== 'super_admin') {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // required email and optional nama from super_admin
    const { email, nama } = req.body || {};
    if (!email || typeof email !== 'string') {
      return res.status(400).json({ error: 'Email is required' });
    }
    const emailRaw = email.trim()
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    if (!emailRegex.test(emailRaw)) {
      return res.status(400).json({ error: 'Invalid email format' })
    }
    const password = crypto.randomUUID();

    // create user using service role
    const { data: created, error: createErr } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    });
    if (createErr) {
      console.error('createUser error:', createErr);
      return res.status(500).json({ error: createErr.message || String(createErr) });
    }
    if (!created || !created.user || !created.user.id) {
      console.error('createUser returned no user data', created);
      return res.status(500).json({ error: 'Failed to create user' });
    }

    const userId = created.user.id;

    // Insert into admin_users table (used by frontend) — do not store password here
    const { data: adminInsert, error: adminInsertErr } = await supabaseAdmin.from('admin_users').insert({
      id: userId,
      email,
      nama: nama ?? null,
      role: 'admin',
      is_active: true
    });
    if (adminInsertErr) {
      console.error('admin_users insert error:', adminInsertErr);
      // Rollback: try to remove created auth user to avoid orphaned auth record
      try {
        await supabaseAdmin.auth.admin.deleteUser(userId);
      } catch (delErr) {
        console.error('Failed to rollback created user:', delErr);
      }
      return res.status(500).json({ error: adminInsertErr.message || String(adminInsertErr) });
    }

    // Set profiles.must_change_password = true if profiles row exists or create it
    try {
      // Upsert profile row: if profiles table exists and has id PK
      await supabaseAdmin.from('profiles').upsert({ id: userId, must_change_password: true }, { onConflict: 'id' });
    } catch (pErr) {
      console.warn('profiles upsert warning:', pErr);
      // not fatal
    }

    return res.json({ email, password });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: String(err) });
  }
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
