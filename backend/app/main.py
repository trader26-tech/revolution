from __future__ import annotations

from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .config import get_settings
from .supabase_client import get_supabase

settings = get_settings()

app = FastAPI(
    title="Revolution API",
    description="FastAPI backend with Supabase connectivity.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Item(BaseModel):
    name: str
    description: Optional[str] = None


@app.get("/")
def root() -> dict:
    return {"app": "Revolution API", "status": "running"}


@app.get("/health")
def health() -> dict:
    """Liveness probe; reports whether Supabase is configured."""
    return {"status": "ok", "supabase_configured": get_supabase() is not None}


@app.get("/api/items")
def list_items() -> dict:
    """Example read from a Supabase `items` table.

    Create the table in your Supabase project, then this returns its rows.
    """
    supabase = get_supabase()
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured.")
    response = supabase.table("items").select("*").execute()
    return {"items": response.data}


@app.post("/api/items", status_code=201)
def create_item(item: Item) -> dict:
    """Example insert into a Supabase `items` table."""
    supabase = get_supabase()
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured.")
    response = supabase.table("items").insert(item.model_dump()).execute()
    return {"item": response.data}
