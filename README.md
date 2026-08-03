# Revolution

A starter monorepo: **FastAPI** backend + **Angular PWA** frontend, both wired
for **Supabase**.

```
revolution/
├── backend/    FastAPI + supabase-py
└── frontend/   Angular 18 PWA + @supabase/supabase-js
```

## Quick start

**Backend**

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # add your Supabase URL + key
uvicorn app.main:app --reload
```

**Frontend**

```bash
cd frontend
npm install
# edit src/environments/environment.ts with your Supabase URL + key
npm start
```

## Supabase

Both apps read Supabase credentials from config that ships with placeholder
values — no real keys are committed:

- Backend: `backend/.env` (from `.env.example`)
- Frontend: `frontend/src/environments/environment.ts`

Grab your project URL and keys from **Supabase → Project Settings → API**.
The examples assume an `items` table; see `backend/README.md` for the schema.

## License

MIT
