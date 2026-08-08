"""The users table — one row per person, anonymous-first.

The APP generates a uuid at install and sends it as X-User-Id on every request;
[ensure_user] materialises the row the first time the server sees the id, so
onboarding never waits on an account round-trip. Phone login runs [claim]
(the `claim_user` SQL function): it either claims that same row in place or —
if the phone already has an account — atomically re-points the anonymous
user's data onto it and returns the account's id.
"""
from datetime import datetime, timezone
from typing import Any, Optional

from app.core.supabase import get_supabase

_USERS = "users"


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_user(user_id: str) -> None:
    """Materialise the (anonymous) users row for an app-generated id. No-op if
    it already exists — never overwrites anything."""
    get_supabase().table(_USERS).upsert(
        {"id": user_id}, on_conflict="id", ignore_duplicates=True
    ).execute()


def get_user(user_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_USERS)
        .select("*")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def claim(
    anon_user_id: str, phone: str, name: Optional[str] = None
) -> dict[str, Any]:
    """Run the atomic pairing (see schema_v2.sql::claim_user) and return
    `{"user_id": <canonical id>, "user": <row>}`. The app must switch to the
    returned id — it may differ from the anonymous one when the phone already
    had an account (re-install / second device)."""
    res = (
        get_supabase()
        .rpc(
            "claim_user",
            {
                "p_anon_id": anon_user_id,
                "p_phone": phone,
                "p_display_name": name,
            },
        )
        .execute()
    )
    user_id = str(res.data)
    return {"user_id": user_id, "user": get_user(user_id)}


def update_prefs(
    user_id: str,
    *,
    call_reminder: Optional[bool] = None,
    display_name: Optional[str] = None,
) -> dict[str, Any]:
    """Update the user's preference fields (prefs live ON the users row).

    The phone is identity and only ever set via [claim] — it is deliberately
    not updatable here.
    """
    ensure_user(user_id)
    patch: dict[str, Any] = {"last_seen_at": _now()}
    if call_reminder is not None:
        patch["call_reminder"] = call_reminder
    trimmed = (display_name or "").strip()
    if trimmed:
        patch["display_name"] = trimmed
    res = (
        get_supabase().table(_USERS).update(patch).eq("id", user_id).execute()
    )
    return res.data[0] if res.data else patch
