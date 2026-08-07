"""WhatsApp sending — a thin wrapper over Twilio's REST API.

Uses httpx (already a dependency via supabase) so no extra package is needed.
Credentials come from settings/.env and never touch the codebase.

Provider-agnostic on purpose: only `send_whatsapp()` knows it's Twilio, so
swapping to Meta Cloud API / another BSP later is a one-function change.
"""
from __future__ import annotations

import httpx

from app.core.config import settings

_TWILIO_API = "https://api.twilio.com/2010-04-01"


class WhatsAppNotConfigured(RuntimeError):
    """Raised when Twilio credentials are missing."""


def _ensure_configured() -> None:
    missing = [
        name
        for name, val in (
            ("TWILIO_ACCOUNT_SID", settings.twilio_account_sid),
            ("TWILIO_AUTH_TOKEN", settings.twilio_auth_token),
            ("TWILIO_WHATSAPP_FROM", settings.twilio_whatsapp_from),
        )
        if not val
    ]
    if missing:
        raise WhatsAppNotConfigured(
            "WhatsApp is not configured. Set "
            + ", ".join(missing)
            + " in the environment (.env)."
        )


def _to_whatsapp(number: str) -> str:
    """Normalise a phone number to Twilio's `whatsapp:+E164` form.

    Accepts "918925188870", "+918925188870" or an already-prefixed
    "whatsapp:+91...". Returns "whatsapp:+918925188870".
    """
    n = number.strip()
    if n.startswith("whatsapp:"):
        return n
    if not n.startswith("+"):
        n = "+" + n
    return f"whatsapp:{n}"


def send_whatsapp(to: str, body: str) -> dict:
    """Send a WhatsApp text message. Returns Twilio's response JSON.

    Raises WhatsAppNotConfigured if credentials are missing, or
    httpx.HTTPStatusError if Twilio rejects the request (e.g. the recipient
    hasn't joined the sandbox).
    """
    _ensure_configured()

    url = f"{_TWILIO_API}/Accounts/{settings.twilio_account_sid}/Messages.json"
    data = {
        "To": _to_whatsapp(to),
        "From": _to_whatsapp(settings.twilio_whatsapp_from),
        "Body": body,
    }
    resp = httpx.post(
        url,
        data=data,
        auth=(settings.twilio_account_sid, settings.twilio_auth_token),
        timeout=20.0,
    )
    resp.raise_for_status()
    return resp.json()
