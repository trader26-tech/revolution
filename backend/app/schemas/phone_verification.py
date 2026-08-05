"""Pydantic schemas for phone verification (onboarding)."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

try:
    import phonenumbers
except ImportError:  # pragma: no cover - dependency is declared in requirements
    phonenumbers = None


def _to_e164(raw: str, default_region: str = "IN") -> str:
    """Normalise a user-typed number to E.164 ('+919876543210').

    Falls back to a light cleanup if the phonenumbers lib is unavailable, so the
    module still imports in minimal environments.
    """
    raw = raw.strip()
    if phonenumbers is None:
        cleaned = "".join(ch for ch in raw if ch.isdigit() or ch == "+")
        if not cleaned.startswith("+"):
            raise ValueError("Enter the number with its country code, e.g. +91…")
        return cleaned
    try:
        parsed = phonenumbers.parse(raw, None if raw.startswith("+") else default_region)
    except phonenumbers.NumberParseException as exc:  # type: ignore[union-attr]
        raise ValueError("That doesn't look like a valid phone number.") from exc
    if not phonenumbers.is_valid_number(parsed):
        raise ValueError("That phone number isn't valid.")
    return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)


class StartVerificationRequest(BaseModel):
    """The user submits the phone number they want to verify."""

    phone: str = Field(..., examples=["+91 98765 43210"])
    # Used to interpret numbers typed without a country code.
    region: str = Field("IN", examples=["IN", "KW"])

    @field_validator("phone")
    @classmethod
    def _validate_phone(cls, v: str, info) -> str:
        region = (info.data.get("region") or "IN").upper()
        return _to_e164(v, region)


class StartVerificationResponse(BaseModel):
    """Everything the app needs to launch the WhatsApp verify step."""

    id: UUID
    phone: str
    status: str
    expires_at: datetime

    # Deep link that opens WhatsApp with the code pre-filled to our number.
    whatsapp_url: str
    # The exact message body (so the app can show/copy it if the deep link fails).
    whatsapp_message: str

    # Only populated when OTP_DEBUG_RETURN_CODE is on (dev/testing).
    debug_code: Optional[str] = None


class VerificationStatus(BaseModel):
    """Polled by the app to know when the inbound WhatsApp message landed."""

    id: UUID
    phone: str
    status: str  # 'pending' | 'verified' | 'expired'
    verified: bool
