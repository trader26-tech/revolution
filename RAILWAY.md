# Deploying to Railway

This monorepo hosts **two** Railway services from one repo:

| Service    | Root directory | What it runs                                    |
| ---------- | -------------- | ----------------------------------------------- |
| `backend`  | `backend/`     | FastAPI via `uvicorn` on `$PORT`                |
| `frontend` | `frontend/`    | Vite build served via `vite preview` on `$PORT` |

> **The #1 thing to get right:** each service's **Root Directory** must point at
> its folder (`backend` or `frontend`). If it's left at the repo root, the
> builder analyzes the root — which has no app manifest — and the build fails
> with "the app contents … contains ./ backend/ frontend/ …". Set the Root
> Directory and each service builds from its own `railpack.json` / `railway.json`.

Each folder ships a `railpack.json` (build + start) and a `railway.json`
(builder = `RAILPACK`, restart policy, health check). You only set the Root
Directory and the variables below.

## 1. Create the project

Railway dashboard: **New Project → Deploy from GitHub repo** → pick this repo.
This creates one service; you'll add the second and point each at its folder.

## 2. Backend service

- **Settings → Source → Root Directory:** `backend`
- **Build / Start:** from `backend/railpack.json` + `backend/railway.json`
  (`uvicorn app.main:app --host 0.0.0.0 --port $PORT`). No override needed.
- **Health check:** `/health` (returns 200 even before Supabase is set, so the
  deploy goes live; data endpoints need the variables below).
- **Variables** (Settings → Variables) — **required**, the backend is
  Supabase-only and its data endpoints 500 without them:

  ```
  SUPABASE_URL=https://your-project-ref.supabase.co
  SUPABASE_KEY=your-service-role-or-anon-key
  CORS_ORIGINS=https://<your-frontend-service>.up.railway.app
  ```

  `CORS_ORIGINS` must include the frontend's public URL (comma-separated for
  several), or the browser blocks API calls.

Railway injects `$PORT` automatically — do **not** set it yourself. Run
[`backend/sql/subscriptions.sql`](backend/sql/subscriptions.sql) in the Supabase
SQL editor once to create the table.

## 3. Frontend service

- **New service** (same repo) → **Settings → Source → Root Directory:** `frontend`
- **Build:** `npm ci` then `npm run build` (from `frontend/railpack.json`).
- **Start:** `npm run serve:prod` → `vite preview` on `$PORT` (host + allowedHosts
  are enabled in `vite.config.ts`, so the public domain is accepted).
- **Point the frontend at the backend** (Settings → Variables):

  ```
  VITE_API_BASE_URL=https://<your-backend-service>.up.railway.app
  ```

  Vite bakes `VITE_*` vars in **at build time**, so set this **before** the
  build (it's read during `npm run build`). Leaving it unset makes the frontend
  run local-only (localStorage, no sync) — a valid deploy on its own.

## 4. Generate public domains

For each service: **Settings → Networking → Generate Domain**. Then fill the
real URLs into `CORS_ORIGINS` (backend) and `VITE_API_BASE_URL` (frontend) and
redeploy.

## Deploy order

1. Deploy **backend**, generate its domain, add the Supabase vars.
2. Put the backend domain in the frontend's `VITE_API_BASE_URL`, and the
   frontend domain in the backend's `CORS_ORIGINS`.
3. Deploy **frontend** (rebuild so the API URL is baked in).

## Local parity

The exact commands Railway runs work locally too:

```bash
# backend
cd backend && pip install -r requirements.txt
SUPABASE_URL=... SUPABASE_KEY=... PORT=8000 \
  uvicorn app.main:app --host 0.0.0.0 --port $PORT

# frontend
cd frontend && npm ci && npm run build
PORT=8080 npm run serve:prod
```
