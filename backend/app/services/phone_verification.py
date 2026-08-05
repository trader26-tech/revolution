"""Phone verification via WhatsApp — free, user-initiated, no SMS cost.

The flow (no DLT, no billing card, works for Indian & Gulf numbers):

  1. `start()` — the user submits their phone number. We generate a short code,
     store its SHA-256 hash with a TTL, and hand back a `wa.me` deep link with a
     pre-filled message ("Verify Revolution: 4821").
  2. The user taps the link; WhatsApp opens and they send that message TO our
     business number. User-initiated messages are free on the Cloud API.
  3. Meta calls our webhook with the sender's number + the text. `ingest_inbound()`
     finds the matching pending attempt (same code) and flips it to 'verified',
     but ONLY if the sender's number equals the number they claimed. That last
     check is what proves ownership.
  4. The app polls `status()` until it reads 'verified'.

Codes are never stored or logged in plaintext (except the dev debug echo).
"""
from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from urllib.parse import quote

from app.core.config import settings
from app.core.supabase import get_supabase

_TABLE = "phone_verifications"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _generate_code() -> str:
    """A numeric code of configured length, no leading-zero ambiguity."""
    upper = 10 ** settings.otp_length
    lower = 10 ** (settings.otp_length - 1)
    return str(secrets.randbelow(upper - lower) + lower)


def _digits_only(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def _build_whatsapp_link(code: str) -> tuple[str, str]:
    """Return (deep_link, message_body) for the pre-filled WhatsApp message."""
    message = f"Verify Revolution: {code}"
    to = _digits_only(settings.whatsapp_business_number)
    url = f"https://wa.me/{to}?text={quote(message)}"
    return url, message


def start(owner_id: str, phone: str) -> dict[str, Any]:
    """Create a pending verification and return the WhatsApp launch payload."""
    code = _generate_code()
    expires_at = _now() + timedelta(seconds=settings.otp_ttl_seconds)

    # Retire any earlier pending attempts for this owner+phone so only the newest
    # code is live — prevents an old code from lingering as valid.
    get_supabase().table(_TABLE).update({"status": "expired"}).eq(
        "owner_id", owner_id
    ).eq("phone", phone).eq("status", "pending").execute()

    row = {
        "owner_id": owner_id,
        "phone": phone,
        "code_hash": _hash_code(code),
        "status": "pending",
        "expires_at": expires_at.isoformat(),
    }
    res = get_supabase().table(_TABLE).insert(row).execute()
    created = res.data[0]

    url, message = _build_whatsapp_link(code)
    payload = {
        "id": created["id"],
        "phone": phone,
        "status": "pending",
        "expires_at": created["expires_at"],
        "whatsapp_url": url,
        "whatsapp_message": message,
        "debug_code": code if settings.otp_debug_return_code else None,
    }
    return payload


def status(owner_id: str, verification_id: str) -> Optional[dict[str, Any]]:
    """Current status for the app to poll. Reports 'expired' past the TTL."""
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("id", verification_id)
        .eq("owner_id", owner_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        return None
    row = res.data[0]
    status_val = row["status"]
    if status_val == "pending" and _is_expired(row):
        status_val = "expired"
    return {
        "id": row["id"],
        "phone": row["phone"],
        "status": status_val,
        "verified": status_val == "verified",
    }


def _is_expired(row: dict[str, Any]) -> bool:
    expires = datetime.fromisoformat(row["expires_at"])
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=timezone.utc)
    return _now() > expires


def ingest_inbound(from_number: str, text: str) -> Optional[dict[str, Any]]:
    """Called by the webhook when a user sends us a WhatsApp message.

    Extracts the code from the text and, if it matches a live pending attempt
    whose claimed phone equals the SENDER's number, marks it verified. Returns
    the verified row, or None if nothing matched (which we silently ignore —
    people send us all kinds of messages).
    """
    code = _extract_code(text)
    if code is None:
        return None

    code_hash = _hash_code(code)
    sender_e164 = _to_e164(from_number)

    # Find live pending attempts for this code. There should be at most one that
    # also matches the sender's number.
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("code_hash", code_hash)
        .eq("status", "pending")
        .execute()
    )
    for row in res.data or []:
        if _is_expired(row):
            continue
        # Ownership proof: the number that sent the code must be the number the
        # user claimed. Compare on digits so '+91…' vs '91…' don't mismatch.
        if _digits_only(row["phone"]) != _digits_only(sender_e164):
            # Right code, wrong sender — count it as a failed attempt.
            _bump_attempts(row)
            continue
        verified = (
            get_supabase()
            .table(_TABLE)
            .update(
                {"status": "verified", "verified_at": _now().isoformat()}
            )
            .eq("id", row["id"])
            .eq("status", "pending")
            .execute()
        )
        if verified.data:
            return verified.data[0]
    return None


def _bump_attempts(row: dict[str, Any]) -> None:
    attempts = int(row.get("attempts", 0)) + 1
    patch: dict[str, Any] = {"attempts": attempts}
    if attempts >= settings.otp_max_attempts:
        patch["status"] = "expired"
    get_supabase().table(_TABLE).update(patch).eq("id", row["id"]).execute()


def _extract_code(text: str) -> Optional[str]:
    """Pull the numeric code out of the inbound message body."""
    if not text:
        return None
    digits = "".join(ch if ch.isdigit() else " " for ch in text).split()
    for token in digits:
        if len(token) == settings.otp_length:
            return token
    return None


def _to_e164(raw: str) -> str:
    """WhatsApp gives the sender's number without a '+'. Add it back."""
    raw = raw.strip()
    return raw if raw.startswith("+") else f"+{_digits_only(raw)}"
