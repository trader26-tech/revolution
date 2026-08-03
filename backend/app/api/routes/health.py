"""Liveness / readiness endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends

from ...services.subscription_service import (
    SubscriptionService,
    get_subscription_service,
)

router = APIRouter(tags=["health"])


@router.get("/")
def root() -> dict:
    return {"app": "Orbit API", "status": "running"}


@router.get("/health")
def health(
    service: SubscriptionService = Depends(get_subscription_service),
) -> dict:
    """Reports whether persistence is backed by Supabase or in-memory."""
    return {
        "status": "ok",
        "persistence": "supabase" if service.is_persistent else "in-memory",
    }
