# Deploying to Railway

This monorepo hosts **two** Railway services from one repo:

| Service    | Root directory | What it runs                                  |
| ---------- | -------------- | --------------------------------------------- |
| `backend`  | `backend/`     | FastAPI via `uvicorn` on `$PORT`              |
| `frontend` | `frontend/`    | Vite build served statically via `vite preview` |

Railway auto-detects both with Nixpacks. The `railway.json` in each folder
sets the start command; you only need to set the **Root Directory** per service
and the environment variables below.

## 1. Create the project

```bash
# once, from the repo root
npm i -g @railway/cli   # or: brew install railway
railway login
railway init            # creates a new project
```

Or use the Railway dashboard: **New Project → Deploy from GitHub repo**.

## 2. Backend service

- **Root Directory:** `backend`
- **Start command:** already set in `backend/railway.json`
  (`uvicorn app.main:app --host 0.0.0.0 --port $PORT`) — no override needed.
- **Health check:** `/health` (configured).
- **Variables** (Settings → Variables):

  ```
  SUPABASE_URL=https://your-project-ref.supabase.co
  SUPABASE_KEY=your-service-role-or-anon-key
  CORS_ORIGINS=https://<your-frontend-service>.up.railway.app
  ```

  `CORS_ORIGINS` must include the frontend's public URL, or the browser will
  block API calls. You can add several, comma-separated.

Railway injects `$PORT` automatically — do **not** set it yourself.

## 3. Frontend service

- **Root Directory:** `frontend`
- **Build:** Nixpacks runs `npm install` then `npm run build`.
- **Start command:** already set in `frontend/railway.json`
  (`npm run serve:prod`), which serves `dist/revolution-frontend/browser`
  on `$PORT` with SPA fallback routing.
- **Pointing the frontend at the backend:** edit
  `frontend/src/environments/environment.prod.ts` before deploying and set:

  ```ts
  apiUrl: 'https://<your-backend-service>.up.railway.app',
  supabaseUrl: 'https://your-project-ref.supabase.co',
  supabaseKey: 'your-anon-key',
  ```

  (Angular bakes these in at build time, so they must be committed or injected
  before `npm run build`. Use the **anon** key here — this value ships to the
  browser.)

## 4. Generate public domains

For each service: **Settings → Networking → Generate Domain**. Then update
`CORS_ORIGINS` (backend) and `apiUrl` (frontend) with the real URLs and redeploy.

## Deploy order

1. Deploy **backend**, generate its domain.
2. Put that domain in `environment.prod.ts` `apiUrl`, and the frontend domain in
   the backend's `CORS_ORIGINS`.
3. Deploy **frontend**.

## Local parity

The exact commands Railway runs work locally too:

```bash
# backend
cd backend && pip install -r requirements.txt
PORT=8000 uvicorn app.main:app --host 0.0.0.0 --port $PORT

# frontend
cd frontend && npm install && npm run build
PORT=8080 npm run serve:prod
```
