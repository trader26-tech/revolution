"""Pydantic schemas for phone-number login."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class PhoneLoginRequest(BaseModel):
    """Log in (or sign up) with just a phone number.

    No password / OTP yet — the phone number is taken at face value. The
    number should be E.164 ('+' + country code + number), e.g. '+919876543210'.
    """

    phone: str = Field(..., examples=["+919876543210"])

    @field_validator("phone")
    @classmethod
    def _normalise(cls, v: str) -> str:
        # Strip spaces the UI may include; keep a leading '+'.
        cleaned = v.strip().replace(" ", "")
        if not cleaned:
            raise ValueError("phone is required")
        # Very light sanity check — real validation lands with OTP later.
        digits = cleaned[1:] if cleaned.startswith("+") else cleaned
        if not digits.isdigit() or len(digits) < 6:
            raise ValueError("that doesn't look like a valid phone number")
        return cleaned


class User(BaseModel):
    id: UUID
    phone: str
    display_name: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class LoginResponse(BaseModel):
    """Returned on login. `user_id` is what the client sends as X-Owner-Id."""

    user_id: UUID
    phone: str
    is_new: bool = Field(
        ..., description="True if this login just created the account."
    )
    display_name: Optional[str] = None
