"""Task persistence — a thin layer over Supabase.

Every query is scoped by user_id (the X-User-Id header — the app-generated
account uuid), so users only ever see their own tasks. Deletes are SOFT
(archived = true) so history and undo stay intact; the list query's partial
index makes "live tasks for this user" a single index scan.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.schemas.task import TaskCreate, TaskUpdate
from app.services import users as users_svc

_TABLE = "tasks"


def _serialize(payload: dict[str, Any]) -> dict[str, Any]:
    """Convert date/datetime values to ISO strings for the JSON API."""
    out: dict[str, Any] = {}
    for key, value in payload.items():
        out[key] = value.isoformat() if hasattr(value, "isoformat") else value
    return out


def list_tasks(user_id: str) -> list[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("user_id", user_id)
        .eq("archived", False)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


def create_task(user_id: str, data: TaskCreate) -> dict[str, Any]:
    # The app generates its uuid locally, so this may be the server's first
    # sight of it — materialise the users row so the FK always holds.
    users_svc.ensure_user(user_id)
    row = _serialize(data.model_dump())
    row["user_id"] = user_id
    res = get_supabase().table(_TABLE).insert(row).execute()
    return res.data[0]


def get_task(user_id: str, task_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", task_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def update_task(
    user_id: str, task_id: str, data: TaskUpdate
) -> Optional[dict[str, Any]]:
    payload = data.model_dump(exclude_unset=True)
    clear = payload.pop("clear_due_at", False)
    patch = _serialize(payload)
    if clear:
        patch["due_at"] = None
    if not patch:
        return get_task(user_id, task_id)
    res = (
        get_supabase()
        .table(_TABLE)
        .update(patch)
        .eq("id", task_id)
        .eq("user_id", user_id)
        .execute()
    )
    return res.data[0] if res.data else None


def delete_task(user_id: str, task_id: str) -> bool:
    """Soft delete — archive the row so undo/history keep working."""
    res = (
        get_supabase()
        .table(_TABLE)
        .update({"archived": True})
        .eq("id", task_id)
        .eq("user_id", user_id)
        .execute()
    )
    return bool(res.data)
