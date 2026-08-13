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


def create_anonymous() -> dict[str, Any]:
    """Mint a brand-new anonymous account. The DATABASE generates the uuid
    (users.id default) — the server owns its primary keys; the app just stores
    what this returns."""
    res = (
        get_supabase()
        .table(_USERS)
        .insert({"status": "anonymous"})
        .execute()
    )
    return res.data[0]


def ensure_user(user_id: str) -> None:
    """Self-heal: materialise the users row for an id the server handed out
    earlier (e.g. the row was wiped in a reset). No-op if it exists — never
    overwrites anything."""
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


def delete_account(user_id: str) -> None:
    """HARD-delete everything for this account: all of its tasks, then the user
    row itself. Used by the app's "Delete data & log off" — this is a real,
    irreversible wipe from the database (not the soft archive that task deletes
    use). Scoped strictly by user_id so it can only ever remove the caller's own
    data."""
    supabase = get_supabase()
    # Remove the account's tasks first (FK-safe), then the account row.
    supabase.table("tasks").delete().eq("user_id", user_id).execute()
    supabase.table(_USERS).delete().eq("id", user_id).execute()


def update_prefs(
    user_id: str,
    *,
    call_reminder: Optional[bool] = None,
    display_name: Optional[str] = None,
    groq_api_key: Optional[str] = None,
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
    # The Groq key: a non-None value updates it; an empty string CLEARS it
    # (the user removing their key). None = leave unchanged.
    if groq_api_key is not None:
        patch["groq_api_key"] = groq_api_key.strip() or None
    res = (
        get_supabase().table(_USERS).update(patch).eq("id", user_id).execute()
    )
    return res.data[0] if res.data else patch


def has_groq_key(user_id: str) -> bool:
    """Whether the user has a Groq key set — for GET /prefs, so the app can show
    'connected' without ever receiving the raw key."""
    row = (
        get_supabase()
        .table(_USERS)
        .select("groq_api_key")
        .eq("id", user_id)
        .limit(1)
        .execute()
    ).data
    return bool(row and (row[0].get("groq_api_key") or "").strip())
