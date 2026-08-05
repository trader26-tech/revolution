"""Reminder persistence — thin layer over Supabase.

Keeps all table knowledge in one place so routes stay declarative.
"""
from typing import Any, Optional

from app.core.supabase import get_supabase
from app.schemas.reminder import ReminderCreate, ReminderUpdate

_TABLE = "reminders"


def _serialize(payload: dict[str, Any]) -> dict[str, Any]:
    """Convert date/datetime values to ISO strings for the JSON API."""
    out: dict[str, Any] = {}
    for key, value in payload.items():
        if hasattr(value, "isoformat"):
            out[key] = value.isoformat()
        else:
            out[key] = value
    return out


def list_reminders(owner_id: str) -> list[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("owner_id", owner_id)
        .eq("is_active", True)
        .order("remind_on")
        .execute()
    )
    return res.data or []


def create_reminder(owner_id: str, data: ReminderCreate) -> dict[str, Any]:
    row = _serialize(data.model_dump())
    row["owner_id"] = owner_id
    res = get_supabase().table(_TABLE).insert(row).execute()
    return res.data[0]


def update_reminder(
    owner_id: str, reminder_id: str, data: ReminderUpdate
) -> Optional[dict[str, Any]]:
    patch = _serialize(data.model_dump(exclude_unset=True))
    if not patch:
        return get_reminder(owner_id, reminder_id)
    res = (
        get_supabase()
        .table(_TABLE)
        .update(patch)
        .eq("id", reminder_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return res.data[0] if res.data else None


def get_reminder(owner_id: str, reminder_id: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", reminder_id)
        .eq("owner_id", owner_id)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def delete_reminder(owner_id: str, reminder_id: str) -> bool:
    """Soft delete — flip is_active so tracking/history stays intact."""
    res = (
        get_supabase()
        .table(_TABLE)
        .update({"is_active": False})
        .eq("id", reminder_id)
        .eq("owner_id", owner_id)
        .execute()
    )
    return bool(res.data)
