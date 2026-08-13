"""Catchy daily one-liners for the Home "today" feed, via Groq.

The Home screen shows each of today's reminders as ONE unified, tailor-made
sentence ("Netflix's ₹649 slips out at 6pm — still worth the binge?"). Those
sentences are written by an LLM (Groq) so they feel human and specific, and are
generated ONCE PER DAY per user, then cached in `daily_task_lines`.

Flow (all lazy, no cron needed):
  • GET /tasks/lines → get_lines_for_today(user_id)
  • If today's rows already exist, return them (cheap read).
  • Else: load today's tasks, ask Groq for one line each, cache, return.
  • If the user has no Groq key (or Groq errors), return {} — the app then
    renders its own local fallback sentence, so the feed always reads well.

The user's Groq key lives on the users row (entered in Settings, shared across
devices). We never return the key to the client.
"""
from __future__ import annotations

import json
from datetime import date, datetime, timedelta, timezone
from typing import Any, Optional

import httpx

from app.core.config import settings
from app.core.supabase import get_supabase

_TASKS = "tasks"
_LINES = "daily_task_lines"

_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"


def _today() -> date:
    return datetime.now(timezone.utc).date()


def _day_bounds(d: date) -> tuple[str, str]:
    return f"{d.isoformat()}T00:00:00", f"{d.isoformat()}T23:59:59"


def _groq_key() -> Optional[str]:
    """The app-wide Groq key from the backend env (never per-user / DB)."""
    key = (settings.groq_api_key or "").strip()
    return key or None


def _tasks_due_today(user_id: str, d: date) -> list[dict[str, Any]]:
    start, end = _day_bounds(d)
    return (
        get_supabase()
        .table(_TASKS)
        .select("id, title, category, sub_category, amount, currency, due_at")
        .eq("user_id", user_id)
        .eq("archived", False)
        .eq("done", False)
        .gte("due_at", start)
        .lte("due_at", end)
        .order("due_at")
        .execute()
    ).data or []


def _cached_lines(user_id: str, d: date) -> dict[str, str]:
    rows = (
        get_supabase()
        .table(_LINES)
        .select("task_id, line")
        .eq("user_id", user_id)
        .eq("for_date", d.isoformat())
        .execute()
    ).data or []
    return {r["task_id"]: r["line"] for r in rows}


def _fmt_task_for_prompt(t: dict[str, Any]) -> str:
    bits = [t.get("title") or "reminder"]
    cat = t.get("category")
    if cat and cat != "other":
        bits.append(f"category={cat}")
    sub = t.get("sub_category")
    if sub:
        bits.append(f"kind={sub}")
    amt = t.get("amount")
    if amt is not None:
        cur = t.get("currency") or "INR"
        bits.append(f"amount={cur} {amt}")
    due = t.get("due_at")
    if due:
        bits.append(f"due={due}")
    return " | ".join(bits)


def _build_prompt(tasks: list[dict[str, Any]]) -> list[dict[str, str]]:
    numbered = "\n".join(
        f"{i + 1}. {_fmt_task_for_prompt(t)}" for i, t in enumerate(tasks)
    )
    system = (
        "You write ONE short, catchy, human sentence for each of the user's "
        "reminders due today. Each line must feel tailor-made for THAT item: "
        "weave in its real name, amount and time naturally. Keep it under ~12 "
        "words, warm and a little witty, never generic ('still worth it?'). For "
        "a subscription, nudge a keep-or-cancel decision. For a bill, nudge "
        "paying on time. For a birthday, be warm. Return STRICT JSON: an array "
        'of objects like {"n": 1, "line": "..."} — one per reminder, in order. '
        "No markdown, no extra text."
    )
    user = f"Reminders due today:\n{numbered}\n\nReturn the JSON array now."
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": user},
    ]


def _call_groq(api_key: str, tasks: list[dict[str, Any]]) -> dict[str, str]:
    """Ask Groq for one line per task. Returns {task_id: line}. Best-effort:
    any error or malformed response yields {} so the caller falls back."""
    resp = httpx.post(
        _GROQ_URL,
        headers={"Authorization": f"Bearer {api_key}"},
        json={
            "model": settings.groq_model,
            "messages": _build_prompt(tasks),
            "temperature": 0.8,
            "max_tokens": 600,
            "response_format": {"type": "json_object"},
        },
        timeout=25.0,
    )
    resp.raise_for_status()
    content = resp.json()["choices"][0]["message"]["content"]
    parsed = json.loads(content)
    # The model may return a bare array or an object wrapping one.
    items = parsed if isinstance(parsed, list) else (
        parsed.get("lines") or parsed.get("reminders") or []
    )
    out: dict[str, str] = {}
    for item in items:
        try:
            idx = int(item["n"]) - 1
            line = str(item["line"]).strip()
        except (KeyError, ValueError, TypeError):
            continue
        if 0 <= idx < len(tasks) and line:
            out[tasks[idx]["id"]] = line
    return out


def _store_lines(user_id: str, d: date, lines: dict[str, str]) -> None:
    if not lines:
        return
    sb = get_supabase()
    rows = [
        {
            "user_id": user_id,
            "task_id": task_id,
            "for_date": d.isoformat(),
            "line": line,
        }
        for task_id, line in lines.items()
    ]
    # Upsert on (task_id, for_date) so a re-run today is idempotent.
    sb.table(_LINES).upsert(rows, on_conflict="task_id,for_date").execute()
    # Opportunistic cleanup: drop lines older than 2 days.
    cutoff = (d - timedelta(days=2)).isoformat()
    sb.table(_LINES).delete().lt("for_date", cutoff).execute()


def get_lines_for_today(user_id: str) -> dict[str, str]:
    """{task_id: catchy_line} for the caller's tasks due today.

    Generates + caches on the first call of the day; reads cache thereafter.
    Returns {} (→ app uses its local fallback) when Groq isn't configured, no
    tasks are due, or Groq errors out.
    """
    d = _today()

    tasks = _tasks_due_today(user_id, d)
    if not tasks:
        return {}

    cached = _cached_lines(user_id, d)
    # Which of today's tasks still need a line (new task added mid-day, etc.).
    missing = [t for t in tasks if t["id"] not in cached]
    if not missing:
        return cached

    api_key = _groq_key()
    if not api_key:
        return cached  # may be partial/empty; app fills the rest locally

    try:
        fresh = _call_groq(api_key, missing)
    except (httpx.HTTPError, KeyError, ValueError, TypeError):
        return cached  # network/model hiccup → app falls back locally

    _store_lines(user_id, d, fresh)
    cached.update(fresh)
    return cached
