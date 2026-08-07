"""Build the daily reminder text from a user's tasks.

Groups a user's open tasks into Pending (overdue), Today, and Upcoming, and
formats a friendly, branded WhatsApp message. Mirrors the app's Home grouping.
"""
from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any

from app.services import tasks as task_svc

# Currency symbols for the amount line (matches the app).
_SYMBOLS = {"INR": "₹", "USD": "$", "KWD": "KD "}


def _as_date(value: Any) -> date | None:
    """Parse a Supabase due_at (ISO string or datetime) to a date."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    try:
        # Supabase returns e.g. "2026-08-07T00:00:00+00:00".
        return datetime.fromisoformat(str(value).replace("Z", "+00:00")).date()
    except ValueError:
        return None


def _amount_str(task: dict) -> str:
    amt = task.get("amount")
    if amt is None:
        return ""
    sym = _SYMBOLS.get(task.get("currency", "INR"), "")
    # Whole rupees look cleaner in a message; keep decimals only if present.
    n = int(amt) if float(amt) == int(amt) else amt
    return f" — {sym}{n:,}"


def _line(task: dict) -> str:
    return f"• {task.get('title', 'Untitled')}{_amount_str(task)}"


def build_reminder(owner_id: str, *, today: date | None = None) -> str | None:
    """Build the reminder message for a user, or None if nothing is due.

    A task counts if it's not done and has a due date of today or earlier
    (pending), or today (due today). Undated tasks are ignored for reminders.
    """
    today = today or datetime.now(timezone.utc).date()
    tasks = task_svc.list_tasks(owner_id)

    pending: list[dict] = []
    due_today: list[dict] = []

    for t in tasks:
        if t.get("done"):
            continue
        d = _as_date(t.get("due_at"))
        if d is None:
            continue
        if d < today:
            pending.append(t)
        elif d == today:
            due_today.append(t)

    if not pending and not due_today:
        return None

    parts: list[str] = ["*Revolution* — your reminders for today 📌", ""]

    if pending:
        parts.append(f"⚠️ *Pending ({len(pending)})* — overdue")
        parts += [_line(t) for t in pending]
        parts.append("")

    if due_today:
        parts.append(f"📅 *Today ({len(due_today)})*")
        parts += [_line(t) for t in due_today]
        parts.append("")

    parts.append("Open Revolution to mark them done. ✅")
    return "\n".join(parts).strip()
