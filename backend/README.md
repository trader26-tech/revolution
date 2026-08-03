# Revolution API (FastAPI)

FastAPI backend with Supabase connectivity.

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then fill in your Supabase URL and key
```

## Run

```bash
uvicorn app.main:app --reload
```

- API root: http://localhost:8000
- Interactive docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

## Supabase

Set `SUPABASE_URL` and `SUPABASE_KEY` in `.env` (from your project's
**Settings → API**). The `/api/items` endpoints expect an `items` table:

```sql
create table items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text
);
```
