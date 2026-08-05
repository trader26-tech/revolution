"""Family member routes.

The head of family (the account, carried by X-Owner-Id) manages their members.
Listing auto-creates the head's own "You" record so the family always has at
least one member to attach reminders to.
"""
from fastapi import APIRouter, Header, HTTPException

from app.schemas.family_member import (
    FamilyMember,
    FamilyMemberCreate,
    FamilyMemberUpdate,
)
from app.services import family_members as svc

router = APIRouter(prefix="/family/members", tags=["family"])


@router.get("", response_model=list[FamilyMember])
async def list_members(x_owner_id: str = Header(...)) -> list[dict]:
    # Guarantee the head's own record exists, then return everyone.
    svc.ensure_self(x_owner_id)
    return svc.list_members(x_owner_id)


@router.post("", response_model=FamilyMember, status_code=201)
async def create_member(
    payload: FamilyMemberCreate, x_owner_id: str = Header(...)
) -> dict:
    return svc.create_member(x_owner_id, payload)


@router.patch("/{member_id}", response_model=FamilyMember)
async def update_member(
    member_id: str, payload: FamilyMemberUpdate, x_owner_id: str = Header(...)
) -> dict:
    row = svc.update_member(x_owner_id, member_id, payload)
    if row is None:
        raise HTTPException(status_code=404, detail="Member not found")
    return row


@router.delete("/{member_id}", status_code=204)
async def delete_member(member_id: str, x_owner_id: str = Header(...)) -> None:
    if not svc.delete_member(x_owner_id, member_id):
        raise HTTPException(
            status_code=400,
            detail="Member not found, or the head-of-family record can't be removed.",
        )
