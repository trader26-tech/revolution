"""Claim an anonymous session's data for a verified account.

Onboarding creates tasks under a per-install anonymous owner id (e.g.
"dev-<timestamp>"). When the user finally verifies their phone, we re-key every
row from that anonymous id to the phone id, so nothing they set up is lost and
it all shows up under their account on the next fetch.

Idempotent and safe: if the anonymous id has no rows (already claimed, or a
fresh verified login), it simply reports zero moved.
"""
from typing import Any

from app.core.supabase import get_supabase

_TASKS = "tasks"
_PREFS = "user_prefs"


def claim(anon_owner_id: str, new_owner_id: str) -> dict[str, Any]:
    """Reassign all tasks (and prefs) from [anon_owner_id] to [new_owner_id].

    No-ops when the two ids are equal or the anon id is empty. Returns how many
    task rows moved so the caller can log/verify.
    """
    if not anon_owner_id or anon_owner_id == new_owner_id:
        return {"moved_tasks": 0, "moved_prefs": 0, "skipped": True}

    sb = get_supabase()

    # Move tasks: every row still owned by the anonymous id becomes the user's.
    moved = (
        sb.table(_TASKS)
        .update({"owner_id": new_owner_id})
        .eq("owner_id", anon_owner_id)
        .execute()
    ).data or []

    # Move prefs too, but only if the verified account doesn't already have a
    # prefs row (its phone-verified row wins). If it does, drop the anon one so
    # we never leave a duplicate owner_id collision behind.
    moved_prefs = 0
    existing = (
        sb.table(_PREFS)
        .select("owner_id")
        .eq("owner_id", new_owner_id)
        .limit(1)
        .execute()
    ).data
    if existing:
        sb.table(_PREFS).delete().eq("owner_id", anon_owner_id).execute()
    else:
        moved_prefs = len(
            (
                sb.table(_PREFS)
                .update({"owner_id": new_owner_id})
                .eq("owner_id", anon_owner_id)
                .execute()
            ).data
            or []
        )

    return {
        "moved_tasks": len(moved),
        "moved_prefs": moved_prefs,
        "skipped": False,
    }
