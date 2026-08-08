"""Claim route — attach an anonymous session's data to the verified account.

The client calls this right after phone verification succeeds: the X-Owner-Id
header is the NEW verified id (the phone), and the body carries the anonymous
id the onboarding tasks were created under. Every matching row is re-keyed to
the verified id.
"""
from typing import Optional

from fastapi import APIRouter, Header
from pydantic import BaseModel

from app.services import claim as svc

router = APIRouter(prefix="/claim", tags=["claim"])


class ClaimRequest(BaseModel):
    anon_owner_id: str
    # The display name captured on the onboarding finish sheet, so the account
    # record (users) + prefs are created with a name in the same call.
    name: Optional[str] = None


@router.post("")
async def claim_session(
    payload: ClaimRequest, x_owner_id: str = Header(...)
) -> dict:
    return svc.claim(payload.anon_owner_id, x_owner_id, name=payload.name)
