"""FastAPI application entrypoint.

Wires the app together: config, CORS, and the versioned API router.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.router import api_router
from app.core.config import settings


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.version,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Lightweight liveness endpoint. Kept dependency-free so the platform's
    # health check passes even if Supabase / WhatsApp env vars are unset.
    @app.get("/", tags=["health"], include_in_schema=False)
    async def root() -> dict:
        return {
            "name": settings.app_name,
            "version": settings.version,
            "status": "ok",
        }

    app.include_router(api_router)
    return app


app = create_app()
