"""Suggestions (Ideas board) persistence — a thin layer over Supabase.

The idea text is anonymous; author_id is stored only to flag "mine" for that
account, never exposed to others. Votes are one row per (suggestion, user), and
suggestions.score is kept correct by a DB trigger (see schema_suggestions.sql),
so the list read never needs a GROUP BY.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.services import users as users_svc

_SUGGESTIONS = "suggestions"
_VOTES = "suggestion_votes"


def _shape(row: dict[str, Any], my_vote: int, user_id: str) -> dict[str, Any]:
    """The API view of a suggestion for a given caller."""
    return {
        "id": str(row["id"]),
        "text": row.get("text", ""),
        "score": row.get("score", 0) or 0,
        "status": row.get("status", "open"),
        "my_vote": my_vote,
        "mine": row.get("author_id") == user_id,
        "created_at": row.get("created_at"),
    }


def list_suggestions(user_id: str) -> list[dict[str, Any]]:
    """Visible ideas, most-popular first, annotated with THIS user's vote."""
    sb = get_supabase()
    rows = (
        sb.table(_SUGGESTIONS)
        .select("*")
        .eq("is_hidden", False)
        .order("score", desc=True)
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )
    if not rows:
        return []

    # One query for all of the caller's votes, then map in memory.
    ids = [r["id"] for r in rows]
    votes = (
        sb.table(_VOTES)
        .select("suggestion_id, value")
        .eq("user_id", user_id)
        .in_("suggestion_id", ids)
        .execute()
        .data
        or []
    )
    my = {v["suggestion_id"]: v["value"] for v in votes}
    return [_shape(r, my.get(r["id"], 0), user_id) for r in rows]


def create_suggestion(user_id: str, text: str) -> dict[str, Any]:
    # Materialise the users row so the author_id FK always holds.
    users_svc.ensure_user(user_id)
    row = (
        get_supabase()
        .table(_SUGGESTIONS)
        .insert({"text": text.strip(), "author_id": user_id})
        .execute()
        .data[0]
    )
    return _shape(row, 0, user_id)


def _get(sb, suggestion_id: str) -> Optional[dict[str, Any]]:
    res = (
        sb.table(_SUGGESTIONS)
        .select("*")
        .eq("id", suggestion_id)
        .limit(1)
        .execute()
        .data
    )
    return res[0] if res else None


def vote(user_id: str, suggestion_id: str, value: int) -> Optional[dict[str, Any]]:
    """Set the caller's vote (-1/0/+1). 0 clears it. Returns {score, my_vote},
    or None if the suggestion doesn't exist."""
    users_svc.ensure_user(user_id)
    sb = get_supabase()

    if _get(sb, suggestion_id) is None:
        return None

    if value == 0:
        sb.table(_VOTES).delete().eq("suggestion_id", suggestion_id).eq(
            "user_id", user_id
        ).execute()
    else:
        # Upsert on the (suggestion_id, user_id) primary key. The score trigger
        # applies the delta whether this inserts or updates.
        sb.table(_VOTES).upsert(
            {
                "suggestion_id": suggestion_id,
                "user_id": user_id,
                "value": value,
            },
            on_conflict="suggestion_id,user_id",
        ).execute()

    row = _get(sb, suggestion_id)
    return {"score": (row or {}).get("score", 0) or 0, "my_vote": value}


def delete_suggestion(user_id: str, suggestion_id: str) -> bool:
    """Delete a suggestion — ONLY its own author may. Returns True if a row that
    belongs to the caller was deleted (votes cascade via the FK)."""
    res = (
        get_supabase()
        .table(_SUGGESTIONS)
        .delete()
        .eq("id", suggestion_id)
        .eq("author_id", user_id)  # author-only: someone else's id deletes nothing
        .execute()
        .data
    )
    return bool(res)
