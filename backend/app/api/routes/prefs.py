"""User-preference routes + the weekly 'call me to remind' digest.

- The app saves the user's phone + call_reminder choice via PUT /prefs.
- The operator pulls GET /prefs/weekly-digest to see who to WhatsApp-call this
  week and what's coming up for each of them.
"""
from typing import Optional

from fastapi import APIRouter, Header
from pydantic import BaseModel

from app.services import user_prefs as svc

router = APIRouter(prefix="/prefs", tags=["prefs"])


class PrefsUpdate(BaseModel):
    phone: Optional[str] = None
    call_reminder: Optional[bool] = None


@router.put("")
async def update_prefs(
    payload: PrefsUpdate, x_owner_id: str = Header(...)
) -> dict:
    return svc.upsert_prefs(
        x_owner_id,
        phone=payload.phone,
        call_reminder=payload.call_reminder,
    )


@router.get("/weekly-digest")
async def weekly_digest() -> dict:
    """Everyone opted in with something due next calendar week (Mon–Sun)."""
    return svc.weekly_digest()
