"""Pydantic schemas for family members.

The account holder is the head of the family; every member (including the head's
own "You" record) is scoped to that account by owner_id (the X-Owner-Id header).
"""
from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field

# The relations we offer in the UI; free text is still allowed on the wire.
COMMON_RELATIONS = [
    "Self",
    "Spouse",
    "Son",
    "Daughter",
    "Father",
    "Mother",
    "Brother",
    "Sister",
    "Other",
]


class FamilyMemberBase(BaseModel):
    name: str = Field(..., examples=["Priya Sharma"], min_length=1)
    relation: str = Field("Self", examples=["Spouse"])
    metadata: dict[str, Any] = Field(default_factory=dict)


class FamilyMemberCreate(FamilyMemberBase):
    """Create a member. owner_id comes from the header, not the body."""

    is_self: bool = False


class FamilyMemberUpdate(BaseModel):
    """Patch semantics — all fields optional."""

    name: Optional[str] = None
    relation: Optional[str] = None
    metadata: Optional[dict[str, Any]] = None
    is_active: Optional[bool] = None


class FamilyMember(FamilyMemberBase):
    id: UUID
    owner_id: str
    is_self: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime
