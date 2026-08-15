"""Natural-language → structured reminder, via Groq.

The Home command box lets the user type a reminder in plain English ("Netflix
649 every month", "call mom on her birthday next Tuesday") and turns it into the
structured fields the app's add flow needs. The app then shows a confirmation
card and, on approval, creates the task.

Pure parse — this does NOT create anything. It returns a best-effort structured
draft the client confirms first. Constrained to the app's real category/repeat
vocabularies so the result always maps cleanly onto a Task.
"""
from __future__ import annotations

import json
from datetime import date, datetime
from typing import Any, Optional

import httpx

from app.core.config import settings

_GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

# Must match the app's TaskCategory names.
_CATEGORIES = [
    "subscription",
    "birthday",
    "insurance",
    "investment",
    "bills",
    "policies",
    "other",
]
# Must match the app's RepeatCadence names.
_REPEATS = ["none", "daily", "weekly", "monthly", "yearly"]


def _groq_key() -> Optional[str]:
    key = (settings.groq_api_key or "").strip()
    return key or None


def _system_prompt(today: date) -> str:
    return (
        "You convert ONE natural-language reminder into structured JSON. Extract "
        "only what the user actually said — never invent details.\n"
        f"Today's date is {today.isoformat()} ({today.strftime('%A')}), year "
        f"{today.year}. Resolve relative dates ('tomorrow', 'next Friday', 'in "
        "3 days', 'on the 15th') against it. A reminder is ALWAYS in the future: "
        f"never output a date before {today.isoformat()}, and use the year "
        f"{today.year} (or later) — never a past year.\n"
        "\n"
        "Return STRICT JSON with these fields (omit a field or use null when the "
        "user didn't specify it — do NOT guess):\n"
        '  "title":     short name of the thing (string, required)\n'
        '  "category":  one of ' + ", ".join(_CATEGORIES) + " (best fit; "
        '"other" if unclear)\n'
        '  "amount":    number only, no currency symbol (e.g. 649) or null\n'
        '  "currency":  ISO code if a currency is clear (INR/USD/…), else null\n'
        '  "date":      "YYYY-MM-DD" when a due date is given/implied, else null\n'
        '  "time":      "HH:MM" 24h ONLY if a clock time is stated, else null\n'
        '  "repeat":    one of ' + ", ".join(_REPEATS) + ' (default "none")\n'
        '  "note":      any extra detail worth keeping, else null\n'
        "\n"
        "Category hints: streaming/apps/memberships → subscription; a person's "
        "birthday/anniversary → birthday; electricity/rent/phone/emi → bills; "
        "SIP/mutual fund/stocks → investment; LIC/endowment/premium → policies; "
        "car/health/term cover → insurance; anything else → other.\n"
        "Repeat hints: 'every month'/'monthly' → monthly; 'yearly'/'every "
        "year' → yearly; 'every week' → weekly; 'every day' → daily; a one-off "
        "→ none.\n"
        "Also return a short human \"summary\" (≤10 words) describing what you "
        "understood, e.g. \"Netflix subscription, ₹649 every month\".\n"
        "\n"
        'Output EXACTLY: {"title":...,"category":...,"amount":...,"currency":'
        '...,"date":...,"time":...,"repeat":...,"note":...,"summary":...} and '
        "nothing else."
    )


def _nullish(v: Any) -> bool:
    """The model sometimes emits the STRING 'null'/'none'/'NULL' instead of a
    real null — treat those as absent."""
    return v is None or (
        isinstance(v, str) and v.strip().lower() in {"", "null", "none", "n/a"}
    )


def _clean(parsed: dict[str, Any], today: Optional[date] = None) -> dict[str, Any]:
    """Coerce the model's JSON into safe, app-valid fields."""
    title = str(parsed.get("title") or "").strip()

    category = str(parsed.get("category") or "other").strip().lower()
    if category not in _CATEGORIES:
        category = "other"

    repeat = str(parsed.get("repeat") or "none").strip().lower()
    if repeat not in _REPEATS:
        repeat = "none"

    amount = parsed.get("amount")
    if _nullish(amount):
        amount = None
    else:
        try:
            amount = float(amount)
        except (TypeError, ValueError):
            amount = None

    currency = parsed.get("currency")
    currency = None if _nullish(currency) else str(currency).strip().upper()

    # Combine date + optional time into an ISO datetime the app can use as dueAt.
    due_at = None
    d = parsed.get("date")
    if not _nullish(d):
        t = parsed.get("time")
        t = "00:00" if _nullish(t) else str(t).strip()
        try:
            dt = datetime.fromisoformat(
                f"{d}T{t}:00" if len(t) == 5 else f"{d}T{t}")
        except (TypeError, ValueError):
            try:
                dt = datetime.fromisoformat(f"{d}T00:00:00")
            except (TypeError, ValueError):
                dt = None
        if dt is not None:
            # Guard against year hallucinations: the model occasionally emits a
            # PAST year for a "next Friday"-style date. If the day is clearly in
            # the past, roll it forward to this year (or next, if that's still
            # past) — a reminder is always for the future.
            ref = today or datetime.utcnow().date()
            if dt.date() < ref:
                try:
                    bumped = dt.replace(year=ref.year)
                    if bumped.date() < ref:
                        bumped = dt.replace(year=ref.year + 1)
                    dt = bumped
                except ValueError:
                    pass  # e.g. Feb 29 — leave as-is
            due_at = dt.isoformat()

    note = parsed.get("note")
    note = None if _nullish(note) else str(note).strip()
    summary = str(parsed.get("summary") or "").strip()

    return {
        "title": title,
        "category": category,
        "amount": amount,
        "currency": currency,
        "due_at": due_at,
        "repeat": repeat,
        "note": note,
        "summary": summary,
    }


def parse_command(text: str, *, today: Optional[date] = None) -> dict[str, Any]:
    """Parse [text] into a structured reminder draft. Returns {"ok": bool, ...}.

    ok=False with a reason when Groq isn't configured or the text is empty/
    unparseable — the client then falls back to just using the raw text as a
    title.
    """
    text = (text or "").strip()
    if not text:
        return {"ok": False, "reason": "empty"}

    api_key = _groq_key()
    if not api_key:
        # No LLM available — hand back a minimal draft so the box still works.
        return {
            "ok": True,
            "draft": _clean({"title": text, "summary": text}),
            "llm": False,
        }

    today = today or datetime.utcnow().date()
    try:
        resp = httpx.post(
            _GROQ_URL,
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "model": settings.groq_model,
                "messages": [
                    {"role": "system", "content": _system_prompt(today)},
                    {"role": "user", "content": text},
                ],
                "temperature": 0.2,
                "max_tokens": 300,
                "response_format": {"type": "json_object"},
            },
            timeout=20.0,
        )
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        parsed = json.loads(content)
    except (httpx.HTTPError, KeyError, ValueError, TypeError):
        # Degrade gracefully — the raw text becomes the title.
        return {
            "ok": True,
            "draft": _clean({"title": text, "summary": text}),
            "llm": False,
        }

    draft = _clean(parsed, today=today)
    if not draft["title"]:
        draft["title"] = text
    return {"ok": True, "draft": draft, "llm": True}
