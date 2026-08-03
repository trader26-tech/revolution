# Orbit

A subscription tracker with the exact UI/UX and design language of
[tryorbit.com](https://tryorbit.com) — the signature orbit animation, Magic
Import, and a native-feeling installable PWA. Full-stack: **FastAPI** backend +
**React (Vite) PWA** frontend, backed by **Supabase** (the sole data store).

```
revolution/
├── backend/    FastAPI — layered subscriptions API (Supabase-only store)
└── frontend/   React + Vite PWA — feature-based, sync-aware, offline-capable
```

## Quick start

**Backend** — full CRUD backed by Supabase. Requires Supabase credentials and a
provisioned table (see **Supabase** below) before it will serve requests.

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # required: add Supabase URL + key
uvicorn app.main:app --reload   # http://localhost:8000  (docs at /docs)
```

**Frontend** — runs local-only by default; opt into cloud sync with one env var.

```bash
cd frontend
npm install
npm run dev                 # http://localhost:5173

# optional cloud sync against the backend:
cp .env.example .env.local  # sets VITE_API_BASE_URL=http://localhost:8000
```

## How it fits together

- The frontend store is **optimistic + offline-first**: mutations update the UI
  and localStorage instantly, then write through to the API when sync is on.
- On launch it hydrates from the backend, seeding the backend from local data if
  the backend is empty, and falls back to the local cache if it's unreachable.
- The backend is **layered** (routes → services → repositories) with the data
  store isolated behind a Protocol; Supabase is the only implementation.

## Supabase (required)

The backend stores all data in Supabase — there is no local store. Set
`SUPABASE_URL` / `SUPABASE_KEY` in `backend/.env` (from **Project Settings →
API**, service_role key). Credentials live server-side only and are never
exposed to the frontend. The `subscriptions` table schema is in
[`backend/README.md`](backend/README.md#supabase).

See [`frontend/README.md`](frontend/README.md) and
[`backend/README.md`](backend/README.md) for details.

## License

MIT
