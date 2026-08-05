# Revolution — FastAPI backend

Layered API: **routes → services → repositories → models**, with Pydantic
schemas at the edges and settings loaded from the environment.

## Structure

```
app/
├── main.py                 create_app(): CORS + router wiring
├── core/
│   └── config.py           Settings (pydantic-settings, .env)
├── api/
│   ├── router.py           Aggregates all route modules
│   └── routes/
│       └── health.py       GET /health
├── schemas/                Pydantic request/response models
│   └── health.py
├── services/               Business logic (use-case layer)
├── repositories/           Data access (DB / external stores)
└── models/                 ORM / persistence models
tests/
└── test_health.py
```

Add a feature by creating a route in `api/routes/`, a schema in `schemas/`,
a service in `services/`, and a repository in `repositories/`, then registering
the route in `api/router.py`.

## Run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
uvicorn app.main:app --reload    # http://localhost:8000  (docs at /docs)
```

## Test

```bash
pytest
```

## Deploy to Railway

The service is configured to deploy with **Railpack** and never fail on boot.

**One-time setup in the Railway dashboard:**

1. **New Project → Deploy from GitHub repo** (or `railway up`).
2. Open the service → **Settings → Root Directory** → set it to **`backend`**.
   (The repo root also holds `frontend/`, so the service must build from here.)
3. **Settings → Variables** — add:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `CORS_ORIGINS` — `*`, a comma list, or a JSON array (all accepted).
   - `OTP_DEBUG_RETURN_CODE=false` for production.
   - WhatsApp vars only if you use phone verification.
4. Deploy. Railway injects `$PORT`; the start command binds it automatically.

**What makes the deploy robust:**

- [`railway.json`](./railway.json) sets the start command
  (`uvicorn app.main:app --host 0.0.0.0 --port $PORT`), a `/health` health check,
  and an on-failure restart policy. [`Procfile`](./Procfile) is a fallback.
- [`.python-version`](./.python-version) pins Python 3.11.
- `requirements.txt` pins tested versions with upper caps, so an upstream
  breaking release can't fail the build.
- `CORS_ORIGINS` is parsed tolerantly — no value can crash startup.
- `/` and `/health` respond even when Supabase/WhatsApp env vars are unset.

Verify locally before pushing:

```bash
pytest -q
uvicorn app.main:app --host 0.0.0.0 --port 8000   # the exact prod command
```
