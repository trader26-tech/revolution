"""Claim route — the pairing between an anonymous install and a phone account.

The app calls this right after phone verification succeeds, still under its
ANONYMOUS uuid (the header). The server runs the atomic `claim_user` pairing
and returns the canonical account id — the same uuid if the phone is new, or
the existing account's uuid if this phone already had one (re-install / second
device; the anonymous session's tasks are moved over first). The app must use
the returned `user_id` from then on.
"""
from typing import Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.api.deps import current_user_id
from app.services import users as users_svc

router = APIRouter(prefix="/claim", tags=["claim"])


class ClaimRequest(BaseModel):
    # The verified phone, E.164 (e.g. '+919876543210').
    phone: str
    # Display name captured on the onboarding finish sheet.
    name: Optional[str] = None
    # Optional explicit anonymous id; defaults to the header identity.
    anon_user_id: Optional[str] = None


@router.post("")
async def claim_session(
    payload: ClaimRequest, user_id: str = Depends(current_user_id)
) -> dict:
    anon = payload.anon_user_id or user_id
    return users_svc.claim(anon, payload.phone, payload.name)
