"""User-preference routes + the weekly 'call me to remind' digest.

- The app saves the user's call_reminder choice (and optionally name) via
  PUT /prefs — prefs live ON the users row, keyed by X-User-Id.
- The operator pulls GET /prefs/weekly-digest to see who to WhatsApp-call this
  week and what's coming up for each of them.
"""
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.deps import current_user_id
from app.services import user_prefs as digest_svc
from app.services import users as users_svc

router = APIRouter(prefix="/prefs", tags=["prefs"])


class PrefsUpdate(BaseModel):
    call_reminder: Optional[bool] = None
    name: Optional[str] = None
    # Accepted for backward compatibility but IGNORED — the phone is identity
    # and is only ever set through /claim.
    phone: Optional[str] = None


@router.put("")
async def update_prefs(
    payload: PrefsUpdate, user_id: str = Depends(current_user_id)
) -> dict:
    return users_svc.update_prefs(
        user_id,
        call_reminder=payload.call_reminder,
        display_name=payload.name,
    )


@router.get("/weekly-digest")
async def weekly_digest() -> dict:
    """Everyone opted in with something due next calendar week (Mon–Sun)."""
    return digest_svc.weekly_digest()
