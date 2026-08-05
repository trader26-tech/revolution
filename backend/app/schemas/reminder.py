"""Pydantic schemas for renewal reminders."""
from datetime import date, datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ReminderBase(BaseModel):
    category: str = Field(..., examples=["identity_government"])
    item_key: str = Field(..., examples=["driving_license"])
    title: str = Field(..., examples=["Driving Licence Renewal"])

    # The family member this reminder belongs to (insurance, passport, EMI…).
    # Nullable so existing/household-level reminders stay valid.
    member_id: Optional[UUID] = None

    document_number: Optional[str] = None

    issue_date: Optional[date] = None
    expiry_date: date
    remind_on: date
    remind_days_before: int = 60

    metadata: dict[str, Any] = Field(default_factory=dict)


class ReminderCreate(ReminderBase):
    """Payload to create a reminder. owner_id comes from a header, not the body."""


class ReminderUpdate(BaseModel):
    """All fields optional — patch semantics."""

    title: Optional[str] = None
    member_id: Optional[UUID] = None
    document_number: Optional[str] = None
    issue_date: Optional[date] = None
    expiry_date: Optional[date] = None
    remind_on: Optional[date] = None
    remind_days_before: Optional[int] = None
    metadata: Optional[dict[str, Any]] = None
    is_active: Optional[bool] = None


class Reminder(ReminderBase):
    id: UUID
    owner_id: str
    is_active: bool
    created_at: datetime
    updated_at: datetime
