"""Revolution API.

FastAPI app: liveness + the tasks API (Supabase-backed, owner-scoped).
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import (
    app_version,
    brand_logos,
    claim,
    prefs,
    reminders,
    suggestions,
    tasks,
    users,
)

app = FastAPI(title="Revolution API", version="0.1.1")

# The app is a native mobile client, so CORS is permissive (CORS only affects
# browsers anyway).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tasks.router)
app.include_router(brand_logos.router)
app.include_router(prefs.router)
app.include_router(claim.router)
app.include_router(app_version.router)
app.include_router(reminders.router)
app.include_router(suggestions.router)
app.include_router(users.router)


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {"name": "Revolution API", "status": "ok"}


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
