"""Brand-logo routes — the manually-curated logo overrides the app matches
against. Public read; no auth needed (logos aren't user-specific)."""
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter
from pydantic import BaseModel

from app.services import brand_logos as svc

router = APIRouter(prefix="/brand-logos", tags=["brand-logos"])


class BrandLogo(BaseModel):
    id: UUID
    name: str
    keywords: str
    logo_url: str
    created_at: datetime
    updated_at: datetime


@router.get("", response_model=list[BrandLogo])
async def list_brand_logos() -> list[dict]:
    return svc.list_logos()
