Supabase Edge Function: create-admin

Purpose

- Create a new Supabase Auth user using the Service Role key
- Insert a matching row in `admin_users` with `role = 'admin'`
- Return the generated temporary password to the caller (so no email provider needed)

Secrets (set with `supabase secrets set` or in dashboard)

- `SERVICE_ROLE` — your Supabase service_role key
- `SUPABASE_URL` — your Supabase project URL
- `ALLOWED_ORIGINS` — (optional) comma-separated list of allowed CORS origins (e.g., `https://admin.example.com,https://staging.example.com`)

Deploy

1. Install Supabase CLI and login: `supabase login`
2. From repository root run:

```bash
supabase functions deploy create-admin --project-ref <your-project-ref>
```

3. Set secrets:

```bash
supabase secrets set SERVICE_ROLE="<service-role>" SUPABASE_URL="https://xyz.supabase.co" ALLOWED_ORIGINS="https://your-admin-dashboard.com"
```

Call example (from admin frontend):

```js
const res = await fetch("/functions/v1/create-admin", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    Authorization: `Bearer ${accessToken}`,
  },
  body: JSON.stringify({ email: "new@domain.tld", nama: "Nama" }),
});
const data = await res.json();
console.log(data);
```

Notes

- The function requires the caller to be authenticated and have `role = 'super_admin'` in `admin_users`.
- This function returns the plain password to the caller (super_admin). Do not expose SERVICE_ROLE to clients.
- If you prefer email delivery of credentials, configure an SMTP provider in Supabase or use an external provider; that may incur third-party costs.
