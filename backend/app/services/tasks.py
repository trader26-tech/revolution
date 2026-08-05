"""Task persistence — a thin layer over Supabase.

Every query is scoped by owner_id (the X-Owner-Id header = the logged-in user),
so users only ever see their own tasks.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.schemas.task import TaskCreate, TaskUpdate

_TABLE = "tasks"


def _serialize(payload: dict[str, Any]) -> dict[str, Any]:
    """Convert date/datetime values to ISO strings for the JSON API."""
    out: dict[str, Any] = {}
    for key, value in payload.items():
        out[key] = value.isoformat() if hasattr(value, "isoformat") else value
    return out


def list_tasks(owner_id: str) -> list[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("owner_id", owner_id)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


def create_task(owner_id: str, data: TaskCreate) -> dict[str, Any]:
    row = _serialize(data.model_dump())
    row["owner_id"] = owner_id
    res = get_supabase().table(_TABLE).insert(row).execute()
    return res.data[0]


def get_task(owner_id: str, task_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", task_id)
        .eq("owner_id", owner_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def update_task(
    owner_id: str, task_id: str, data: TaskUpdate
) -> Optional[dict[str, Any]]:
    payload = data.model_dump(exclude_unset=True)
    clear = payload.pop("clear_due_at", False)
    patch = _serialize(payload)
    if clear:
        patch["due_at"] = None
    if not patch:
        return get_task(owner_id, task_id)
    res = (
        get_supabase()
        .table(_TABLE)
        .update(patch)
        .eq("id", task_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return res.data[0] if res.data else None


def delete_task(owner_id: str, task_id: str) -> bool:
    res = (
        get_supabase()
        .table(_TABLE)
        .delete()
        .eq("id", task_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return bool(res.data)
