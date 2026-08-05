"""Top-level API router that aggregates all route modules."""
from fastapi import APIRouter

from app.api.routes import health, phone_verification, reminders

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(reminders.router, tags=["reminders"])
api_router.include_router(phone_verification.router)
