# Orbit API (FastAPI)

Subscription-tracker backend for the Orbit PWA. Layered architecture with
**Supabase as the sole data store** — there is no local fallback, so the API
requires Supabase credentials to run.

```
app/
├── main.py                  application factory + router wiring
├── config.py                settings (env / .env)
├── supabase_client.py       cached Supabase client (optional)
├── schemas/                 Pydantic models (subscription.py)
├── repositories/            data access behind a Protocol
│                            (Supabase implementation)
├── services/                business logic (subscription_service.py)
└── api/routes/              endpoints (health.py, subscriptions.py)
```

Data flows one direction: **routes → services → repositories → store**. Routes
stay thin, logic lives in services, and the store is isolated behind a Protocol
so swapping Supabase for another backend never touches business logic.

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # required: add your Supabase URL + key
```

## Run

```bash
uvicorn app.main:app --reload
```

- API root: http://localhost:8000
- Interactive docs: http://localhost:8000/docs
- Health: http://localhost:8000/health → reports `persistence: supabase`

Supabase is required: without `SUPABASE_URL` / `SUPABASE_KEY` the API raises a
clear `SupabaseNotConfigured` error on first request. All data lives in
Supabase — nothing is stored locally. Provision the table before running (see
**Supabase** below).

## Endpoints

| Method | Path                       | Purpose                 |
|--------|----------------------------|-------------------------|
| GET    | `/api/subscriptions`       | list all                |
| POST   | `/api/subscriptions`       | create                  |
| GET    | `/api/subscriptions/{id}`  | fetch one               |
| PATCH  | `/api/subscriptions/{id}`  | partial update          |
| DELETE | `/api/subscriptions/{id}`  | delete                  |

## Supabase

Set `SUPABASE_URL` and `SUPABASE_KEY` in `backend/.env` (from **Settings → API**;
use the **service_role** key — it stays server-side and is never sent to the
browser). This is required — the API stores all data in Supabase and has no
local fallback. `.env` is gitignored, so credentials are never committed.

The `subscriptions` table it expects:

```sql
create table if not exists public.subscriptions (
  id             text primary key,
  name           text        not null,
  color          text        not null default '#8a1cff',
  mark           text        not null default '○',
  amount         numeric     not null default 0 check (amount >= 0),
  currency       text        not null default 'USD',
  cycle          text        not null default 'monthly',
  category       text        not null default 'Other',
  "list"         text        not null default 'Personal',
  payment_method text        not null default '',
  anchor_date    date        not null,
  is_trial       boolean     not null default false,
  trial_ends     date,
  notes          text,
  created_at     timestamptz not null default now()
);
```
