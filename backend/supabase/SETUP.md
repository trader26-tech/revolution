# Supabase setup (one-time)

Everything is stored in Supabase and written **only** by the FastAPI backend.

## 1. Create the project
1. Go to https://supabase.com → **New project**.
2. Give it a name (e.g. `revolution`) and a database password.
3. Wait for it to provision (~2 min).

## 2. Create the table
1. Open **SQL Editor → New query**.
2. Paste the contents of [`schema.sql`](./schema.sql) and click **Run**.

## 3. Grab your keys
In **Project Settings → API** copy:
- **Project URL** → `SUPABASE_URL`
- **`service_role` secret** (NOT the anon key) → `SUPABASE_SERVICE_ROLE_KEY`

> The service role key bypasses Row Level Security. Keep it server-side only —
> never put it in the Flutter app.

## 4. Tell the backend
Create `backend/.env` (copy from `.env.example`) and fill in:

```
SUPABASE_URL=https://xxxxxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...
CORS_ORIGINS=*
```

## 5. Run it
```
cd backend
python -m venv .venv && source .venv/bin/activate   # if not already
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Open http://localhost:8000/docs to try the `/reminders` endpoints.
