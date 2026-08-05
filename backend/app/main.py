"""Revolution API — clean slate.

A bare FastAPI app with a liveness endpoint. Build features on top of this.
"""
from fastapi import FastAPI

app = FastAPI(title="Revolution API", version="0.1.0")


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {"name": "Revolution API", "status": "ok"}


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
