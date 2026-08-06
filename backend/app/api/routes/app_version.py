"""In-app update check.

The Android app (sideloaded APK) calls GET /app-version on launch with its
current build number and asks: is there something newer? The response drives an
in-app "Update available" prompt — dismissible normally, blocking when the
installed build is below `min_supported`.

Values come from settings (env), so you roll out a new build by bumping
LATEST_VERSION + APK_URL in the environment — no code change.
"""
from fastapi import APIRouter
from pydantic import BaseModel

from app.core.config import settings

router = APIRouter(tags=["app-version"])


class AppVersion(BaseModel):
    latest_version: int
    min_supported_version: int
    apk_url: str
    notes: str


@router.get("/app-version", response_model=AppVersion)
async def app_version() -> AppVersion:
    return AppVersion(
        latest_version=settings.latest_version,
        min_supported_version=settings.min_supported_version,
        apk_url=settings.apk_url,
        notes=settings.update_notes,
    )
