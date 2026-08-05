"""User accounts — phone-number login, backed by Supabase.

The phone number is the identity. `login_or_create` is the whole auth model
for now: find the user by phone, or create one. The returned id is what the
client uses as its X-Owner-Id, so every user's data is naturally scoped to them.
"""
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.supabase import get_supabase

_TABLE = "users"


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def get_by_phone(phone: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("phone", phone)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def get_by_id(user_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def login_or_create(phone: str) -> tuple[dict[str, Any], bool]:
    """Return (user, is_new) for the given phone number.

    If an account with this phone exists we return it (this is the "link to the
    existing account" behaviour); otherwise we create a new one. Either way the
    caller gets a stable user id to scope their data by.
    """
    existing = get_by_phone(phone)
    if existing is not None:
        # Touch last_login_at so we know they came back. Best-effort.
        try:
            updated = (
                get_supabase()
                .table(_TABLE)
                .update({"last_login_at": _now_iso()})
                .eq("id", existing["id"])
                .execute()
            )
            if updated.data:
                return updated.data[0], False
        except Exception:
            pass
        return existing, False

    created = (
        get_supabase()
        .table(_TABLE)
        .insert({"phone": phone, "last_login_at": _now_iso()})
        .execute()
    )
    return created.data[0], True
