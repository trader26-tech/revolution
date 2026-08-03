"""Liveness / readiness endpoints."""

from __future__ import annotations

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/")
def root() -> dict:
    return {"app": "Revolution API", "status": "running"}


@router.get("/health")
def health() -> dict:
    """Liveness probe. Persistence is always Supabase (the only store)."""
    return {"status": "ok", "persistence": "supabase"}
