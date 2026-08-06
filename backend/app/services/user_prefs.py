"""User preferences + the weekly 'call me to remind' digest.

Stores one row per owner (phone + call_reminder). The digest lists every user
who opted in AND has something due in the upcoming calendar week (next Mon–Sun),
so the operator knows who to WhatsApp-call and what to say.
"""
from datetime import date, datetime, timedelta
from typing import Any, Optional

from app.core.supabase import get_supabase

_PREFS = "user_prefs"
_TASKS = "tasks"


def upsert_prefs(
    owner_id: str,
    *,
    phone: Optional[str] = None,
    call_reminder: Optional[bool] = None,
) -> dict[str, Any]:
    row: dict[str, Any] = {"owner_id": owner_id}
    if phone is not None:
        row["phone"] = phone
    if call_reminder is not None:
        row["call_reminder"] = call_reminder
    res = (
        get_supabase()
        .table(_PREFS)
        .upsert(row, on_conflict="owner_id")
        .execute()
    )
    return res.data[0] if res.data else row


def _next_calendar_week(today: date) -> tuple[date, date]:
    """The upcoming Mon–Sun block. If today is mid-week, it's NEXT week's Mon–Sun."""
    # Monday of this week.
    this_monday = today - timedelta(days=today.weekday())
    next_monday = this_monday + timedelta(days=7)
    next_sunday = next_monday + timedelta(days=6)
    return next_monday, next_sunday


def weekly_digest(today: Optional[date] = None) -> dict[str, Any]:
    """Everyone who opted in and has tasks due in the upcoming calendar week."""
    today = today or datetime.utcnow().date()
    start, end = _next_calendar_week(today)
    sb = get_supabase()

    # Opted-in users.
    prefs = (
        sb.table(_PREFS)
        .select("owner_id, phone, call_reminder")
        .eq("call_reminder", True)
        .execute()
    ).data or []

    # Tasks due within the window (inclusive). due_at is a timestamp.
    start_dt = f"{start.isoformat()}T00:00:00"
    end_dt = f"{end.isoformat()}T23:59:59"
    tasks = (
        sb.table(_TASKS)
        .select("owner_id, title, due_at, icon_name")
        .gte("due_at", start_dt)
        .lte("due_at", end_dt)
        .execute()
    ).data or []

    by_owner: dict[str, list[dict[str, Any]]] = {}
    for t in tasks:
        by_owner.setdefault(t["owner_id"], []).append(
            {"title": t.get("title"), "due_at": t.get("due_at"),
             "icon_name": t.get("icon_name")}
        )

    people = []
    for p in prefs:
        items = by_owner.get(p["owner_id"], [])
        if not items:
            continue  # opted in but nothing next week → skip
        items.sort(key=lambda x: x["due_at"] or "")
        people.append(
            {"owner_id": p["owner_id"], "phone": p.get("phone"), "items": items}
        )

    return {
        "week_start": start.isoformat(),
        "week_end": end.isoformat(),
        "count": len(people),
        "people": people,
    }
