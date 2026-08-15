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
    "medicine",
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
        "FIRST decide the INTENT — what the user wants to DO:\n"
        '  "query"    — the user is ASKING a question about their existing '
        'reminders, NOT creating one ("what do I have this week?", "what\'s due '
        'today?", "how much am I spending on subscriptions?", "when is my rent '
        "due?\", \"show my medicines\"). If it's a question, it's a query.\n"
        '  "add"      — create a NEW reminder (a statement of a thing to '
        'remember, e.g. "Netflix 649 monthly", "dentist tomorrow 4pm").\n'
        '  "complete" — mark an existing reminder done ("mark netflix done", '
        '"I paid the rent", "finished my meds").\n'
        '  "delete"   — remove an existing reminder ("delete gym", "cancel '
        'netflix", "cancel my spotify", "remove electricity", "drop the gym '
        "reminder\"). Treat \"cancel <thing>\" / \"stop <thing>\" as delete.\n"
        '  "update"   — change an existing reminder ("change netflix to 799", '
        '"move dentist to Friday", "rename gym to yoga").\n'
        "A QUESTION is never an add. If unsure whether it's a question, prefer "
        "query.\n"
        "For complete/delete/update, ALSO return a \"target\" — a few key words "
        "naming the EXISTING reminder the user means (usually its name, e.g. "
        '"netflix", "electricity bill"). Do NOT invent an id. For "add", target '
        "is null.\n"
        'For a QUERY, return a "range" describing the time window asked about: '
        'one of "today", "tomorrow", "week" (this/next 7 days), "month", '
        '"overdue", "all" (default "all"); and a "target" with key words if the '
        'question is about a specific reminder/category (e.g. "subscriptions", '
        '"rent"), else null.\n'
        "For update, put the NEW values in the normal fields below (e.g. the new "
        "amount in \"amount\", the new date in \"date\").\n"
        "\n"
        "Return STRICT JSON with these fields (omit a field or use null when the "
        "user didn't specify it — do NOT guess):\n"
        '  "intent":    one of add | complete | delete | update\n'
        '  "target":    key words naming the existing reminder (for '
        "complete/delete/update), else null\n"
        '  "title":     short name of the thing (string; for add it\'s required, '
        "for update it's the new name if renaming, else null)\n"
        '  "category":  one of ' + ", ".join(_CATEGORIES) + " (best fit; "
        '"other" if unclear)\n'
        '  "amount":    number only, no currency symbol (e.g. 649) or null\n'
        '  "currency":  ISO code if a currency is clear (INR/USD/…), else null\n'
        '  "date":      "YYYY-MM-DD" when a due date is given/implied, else null\n'
        '  "time":      "HH:MM" 24h ONLY if a clock time is stated, else null\n'
        '  "repeat":    one of ' + ", ".join(_REPEATS) + ' (default "none")\n'
        '  "note":      any extra detail worth keeping, else null\n'
        '  "dose_times": for a MEDICINE, the clock times of day it is taken as '
        '"HH:MM" 24h (e.g. "twice a day" → ["09:00","21:00"], "morning and '
        'night" → ["08:00","20:00"], "after lunch" → ["14:00"]); else [].\n'
        '  "course_days": for a MEDICINE taken for a fixed number of days (e.g. '
        '"for 5 days" → 5); else null.\n'
        '  "repeat_days": specific weekdays as ints (1=Mon … 7=Sun) when named '
        '(e.g. "every Mon/Wed/Fri" → [1,3,5], "on weekends" → [6,7]); else [] '
        "(meaning every day / not day-specific).\n"
        "\n"
        "Category hints: streaming/apps/memberships → subscription; a person's "
        "birthday/anniversary → birthday; electricity/rent/phone/emi → bills; "
        "SIP/mutual fund/stocks → investment; LIC/endowment/premium → policies; "
        "car/health/term cover → insurance; a PILL/tablet/syrup/medicine/dose "
        "to take → medicine; anything else → other.\n"
        "For medicine, set repeat=daily and fill dose_times + course_days when "
        "stated; the medicine's name is the title.\n"
        "Repeat hints: 'every month'/'monthly' → monthly; 'yearly'/'every "
        "year' → yearly; 'every week' → weekly; 'every day' → daily; a one-off "
        "→ none.\n"
        "Also return a short human \"summary\" (≤10 words) describing what you "
        "understood — for add: \"Netflix subscription, ₹649 every month\"; for "
        "delete: \"Delete Netflix\"; for complete: \"Mark rent as paid\"; for "
        "update: \"Change Netflix to ₹799\".\n"
        "\n"
        "Return a single JSON object with intent, target, and the fields above. "
        "Nothing else."
    )


def _nullish(v: Any) -> bool:
    """The model sometimes emits the STRING 'null'/'none'/'NULL' instead of a
    real null — treat those as absent."""
    return v is None or (
        isinstance(v, str) and v.strip().lower() in {"", "null", "none", "n/a"}
    )


_INTENTS = {"query", "add", "complete", "delete", "update"}
_RANGES = {"today", "tomorrow", "week", "month", "overdue", "all"}


def _clean(parsed: dict[str, Any], today: Optional[date] = None) -> dict[str, Any]:
    """Coerce the model's JSON into safe, app-valid fields."""
    intent = str(parsed.get("intent") or "add").strip().lower()
    if intent not in _INTENTS:
        intent = "add"

    target = parsed.get("target")
    target = None if _nullish(target) else str(target).strip()

    range_ = str(parsed.get("range") or "all").strip().lower()
    if range_ not in _RANGES:
        range_ = "all"

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

    # Medicine specifics (only meaningful for the medicine category).
    dose_times: list[str] = []
    raw_doses = parsed.get("dose_times")
    if isinstance(raw_doses, list):
        for t in raw_doses:
            s = str(t).strip()
            # Keep only well-formed HH:MM.
            if len(s) == 5 and s[2] == ":" and s[:2].isdigit() and s[3:].isdigit():
                dose_times.append(s)

    course_days = parsed.get("course_days")
    if _nullish(course_days):
        course_days = None
    else:
        try:
            course_days = int(course_days)
            if course_days <= 0:
                course_days = None
        except (TypeError, ValueError):
            course_days = None

    # Specific weekdays (1=Mon..7=Sun). Deduped, sorted, in range.
    repeat_days: list[int] = []
    raw_days = parsed.get("repeat_days")
    if isinstance(raw_days, list):
        seen = set()
        for x in raw_days:
            try:
                n = int(x)
            except (TypeError, ValueError):
                continue
            if 1 <= n <= 7 and n not in seen:
                seen.add(n)
                repeat_days.append(n)
        repeat_days.sort()

    return {
        "intent": intent,
        "target": target,
        "range": range_,
        "title": title,
        "category": category,
        "amount": amount,
        "currency": currency,
        "due_at": due_at,
        "repeat": repeat,
        "note": note,
        "dose_times": dose_times,
        "course_days": course_days,
        "repeat_days": repeat_days,
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
    # For an ADD with no title, fall back to the raw text. For other intents a
    # missing title is fine (the target names the existing reminder).
    if draft["intent"] == "add" and not draft["title"]:
        draft["title"] = text
    return {"ok": True, "draft": draft, "llm": True}
