"""Family member persistence — thin layer over Supabase.

Every member is scoped to the head-of-family account (owner_id). The head's own
"You" record (is_self) is created on demand so the very first reminder always
has a member to attach to.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.schemas.family_member import FamilyMemberCreate, FamilyMemberUpdate

_TABLE = "family_members"


def _serialize(payload: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in payload.items():
        if hasattr(value, "isoformat"):
            out[key] = value.isoformat()
        else:
            out[key] = value
    return out


def list_members(owner_id: str) -> list[dict[str, Any]]:
    """All active members for the account, the head's 'Self' first."""
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("owner_id", owner_id)
        .eq("is_active", True)
        .order("is_self", desc=True)
        .order("created_at")
        .execute()
    )
    return res.data or []


def get_member(owner_id: str, member_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", member_id)
        .eq("owner_id", owner_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def get_self(owner_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("owner_id", owner_id)
        .eq("is_self", True)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def ensure_self(owner_id: str, name: str = "You") -> dict[str, Any]:
    """Return the head's own member, creating it if it doesn't exist yet."""
    existing = get_self(owner_id)
    if existing is not None:
        return existing
    created = (
        get_supabase()
        .table(_TABLE)
        .insert(
            {
                "owner_id": owner_id,
                "name": name,
                "relation": "Self",
                "is_self": True,
            }
        )
        .execute()
    )
    return created.data[0]


def create_member(owner_id: str, data: FamilyMemberCreate) -> dict[str, Any]:
    # A second 'self' would violate the partial unique index; guard early with a
    # clear result instead of a DB error.
    if data.is_self:
        existing_self = get_self(owner_id)
        if existing_self is not None:
            return existing_self
    row = _serialize(data.model_dump())
    row["owner_id"] = owner_id
    res = get_supabase().table(_TABLE).insert(row).execute()
    return res.data[0]


def update_member(
    owner_id: str, member_id: str, data: FamilyMemberUpdate
) -> Optional[dict[str, Any]]:
    patch = _serialize(data.model_dump(exclude_unset=True))
    if not patch:
        return get_member(owner_id, member_id)
    res = (
        get_supabase()
        .table(_TABLE)
        .update(patch)
        .eq("id", member_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return res.data[0] if res.data else None


def delete_member(owner_id: str, member_id: str) -> bool:
    """Soft delete — flip is_active. The head's own 'Self' cannot be removed."""
    member = get_member(owner_id, member_id)
    if member is None or member.get("is_self"):
        return False
    res = (
        get_supabase()
        .table(_TABLE)
        .update({"is_active": False})
        .eq("id", member_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return bool(res.data)
