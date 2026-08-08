"""The weekly 'call me to remind' digest.

Preferences live ON the users row (users.call_reminder); see
app.services.users.update_prefs for writes. The digest lists every CLAIMED
user who opted in AND has something due in the upcoming calendar week (next
Mon–Sun), so the operator knows who to WhatsApp-call and what to say.
"""
from datetime import date, datetime, timedelta, timezone
from typing import Any, Optional

from app.core.supabase import get_supabase

_USERS = "users"
_TASKS = "tasks"


def _next_calendar_week(today: date) -> tuple[date, date]:
    """The upcoming Mon–Sun block. If today is mid-week, it's NEXT week's Mon–Sun."""
    this_monday = today - timedelta(days=today.weekday())
    next_monday = this_monday + timedelta(days=7)
    next_sunday = next_monday + timedelta(days=6)
    return next_monday, next_sunday


def weekly_digest(today: Optional[date] = None) -> dict[str, Any]:
    """Everyone who opted in and has tasks due in the upcoming calendar week."""
    today = today or datetime.now(timezone.utc).date()
    start, end = _next_calendar_week(today)
    sb = get_supabase()

    # Opted-in, claimed accounts (anonymous rows have no phone to call).
    people_rows = (
        sb.table(_USERS)
        .select("id, phone, display_name, call_reminder")
        .eq("call_reminder", True)
        .eq("status", "claimed")
        .execute()
    ).data or []

    # Live tasks due within the window (inclusive). due_at is a timestamp.
    start_dt = f"{start.isoformat()}T00:00:00"
    end_dt = f"{end.isoformat()}T23:59:59"
    tasks = (
        sb.table(_TASKS)
        .select("user_id, title, due_at, icon_name, amount, currency")
        .eq("archived", False)
        .gte("due_at", start_dt)
        .lte("due_at", end_dt)
        .execute()
    ).data or []

    by_user: dict[str, list[dict[str, Any]]] = {}
    for t in tasks:
        by_user.setdefault(t["user_id"], []).append(
            {
                "title": t.get("title"),
                "due_at": t.get("due_at"),
                "icon_name": t.get("icon_name"),
                "amount": t.get("amount"),
                "currency": t.get("currency"),
            }
        )

    people = []
    for p in people_rows:
        items = by_user.get(p["id"], [])
        if not items:
            continue  # opted in but nothing next week → skip
        items.sort(key=lambda x: x["due_at"] or "")
        people.append(
            {
                "user_id": p["id"],
                "phone": p.get("phone"),
                "name": p.get("display_name"),
                "items": items,
            }
        )

    return {
        "week_start": start.isoformat(),
        "week_end": end.isoformat(),
        "count": len(people),
        "people": people,
    }
