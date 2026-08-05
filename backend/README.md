# Revolution — backend

Clean slate. A bare FastAPI app with a `/health` endpoint. Build features on top.

The Supabase **SQL structure is preserved** in [`supabase/`](supabase/) —
`schema.sql` and `SETUP.md`.

## Run

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload   # http://localhost:8000  (docs at /docs)
```
