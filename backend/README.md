# Orbit API (FastAPI)

Subscription-tracker backend for the Orbit PWA. Layered architecture with a
swappable data store (Supabase or in-memory fallback).

```
app/
├── main.py                  application factory + router wiring
├── config.py                settings (env / .env)
├── supabase_client.py       cached Supabase client (optional)
├── schemas/                 Pydantic models (subscription.py)
├── repositories/            data access behind a Protocol
│                            (Supabase + in-memory implementations)
├── services/                business logic (subscription_service.py)
└── api/routes/              endpoints (health.py, subscriptions.py)
sql/
└── subscriptions.sql        table + trigger for Supabase
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
cp .env.example .env   # optional: add Supabase URL + key for persistence
```

## Run

```bash
uvicorn app.main:app --reload
```

- API root: http://localhost:8000
- Interactive docs: http://localhost:8000/docs
- Health: http://localhost:8000/health → reports `persistence: supabase | in-memory`

Without Supabase credentials the API still boots and serves full CRUD from an
in-memory store — handy for local dev and demos.

## Endpoints

| Method | Path                       | Purpose                 |
|--------|----------------------------|-------------------------|
| GET    | `/api/subscriptions`       | list all                |
| POST   | `/api/subscriptions`       | create                  |
| GET    | `/api/subscriptions/{id}`  | fetch one               |
| PATCH  | `/api/subscriptions/{id}`  | partial update          |
| DELETE | `/api/subscriptions/{id}`  | delete                  |

## Supabase

Set `SUPABASE_URL` and `SUPABASE_KEY` in `.env` (from **Settings → API**), then
run [`sql/subscriptions.sql`](sql/subscriptions.sql) in the Supabase SQL editor
to create the `subscriptions` table. The API switches to Supabase automatically.
