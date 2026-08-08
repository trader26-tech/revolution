"""Claim an anonymous session's data for a verified account.

Onboarding creates tasks under a per-install anonymous owner id (e.g.
"dev-<timestamp>"). When the user finally verifies their phone, we re-key every
row from that anonymous id to the phone id, so nothing they set up is lost and
it all shows up under their account on the next fetch.

Idempotent and safe: if the anonymous id has no rows (already claimed, or a
fresh verified login), it simply reports zero moved.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.services import user_prefs, users

_TASKS = "tasks"
_PREFS = "user_prefs"


def claim(
    anon_owner_id: str,
    new_owner_id: str,
    *,
    name: Optional[str] = None,
) -> dict[str, Any]:
    """Attach an anonymous session to the verified account.

    This is the single place login lands, so it does the whole identity link:
      1. Upsert the canonical `users` row (find-or-create by phone) — the
         primary account record tying phone + name to a stable UUID PK.
      2. Upsert `user_prefs` (phone + name + call_reminder) for the digest.
      3. Re-key every task (and any orphan prefs) from the anonymous id onto the
         verified id, so the reminders set up during onboarding show up under the
         account immediately.

    Steps 1–2 always run (so a plain login with no onboarding still creates the
    account). Step 3 no-ops when there's nothing to move.
    """
    # 1) The canonical account record (primary key lives here).
    account = users.upsert_user(new_owner_id, name=name)

    # 2) Prefs row for the weekly call digest — phone + name + default opt-in.
    user_prefs.upsert_prefs(
        new_owner_id, phone=new_owner_id, name=name, call_reminder=True
    )

    # 3) Move the anonymous session's data onto the account.
    if not anon_owner_id or anon_owner_id == new_owner_id:
        return {
            "user": account,
            "moved_tasks": 0,
            "moved_prefs": 0,
            "skipped": True,
        }

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
        "user": account,
        "moved_tasks": len(moved),
        "moved_prefs": moved_prefs,
        "skipped": False,
    }
