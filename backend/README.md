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
