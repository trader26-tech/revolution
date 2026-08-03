"""Orbit API — FastAPI application factory.

Layered architecture:

    api/routes  ->  services  ->  repositories  ->  Supabase

Routes stay thin; business logic lives in services; data access is isolated in
repositories behind a Protocol so the store is swappable.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.routes import health, subscriptions
from .config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title="Orbit API",
        description="Subscription tracker backend for the Orbit PWA.",
        version="1.0.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(subscriptions.router)

    return app


app = create_app()
