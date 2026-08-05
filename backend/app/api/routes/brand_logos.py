"""Brand-logo routes — the manually-curated logo overrides the app matches
against. Public read; no auth needed (logos aren't user-specific)."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter
from pydantic import BaseModel

from app.services import brand_logos as svc

router = APIRouter(prefix="/brand-logos", tags=["brand-logos"])


class BrandLogo(BaseModel):
    id: UUID
    name: str
    category: str = "Other"
    keywords: str = ""
    logo_url: str


class BrandLogoCreate(BaseModel):
    name: str
    logo_url: str
    category: str = "Other"
    keywords: str = ""


@router.get("", response_model=list[BrandLogo])
async def list_brand_logos() -> list[dict]:
    return svc.list_logos()


@router.post("", response_model=BrandLogo)
async def add_brand_logo(payload: BrandLogoCreate) -> dict:
    """Auto-save a logo the user picked (idempotent by name), so the curated
    set grows from real usage."""
    return svc.upsert_logo(
        payload.name,
        payload.logo_url,
        category=payload.category,
        keywords=payload.keywords,
        source="user",
    )
