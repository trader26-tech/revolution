"""Pydantic schemas for tasks — the items a user tracks (with an optional
brand icon, due date, repeat, and cost)."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class TaskBase(BaseModel):
    title: str = Field(..., examples=["Netflix"])
    notes: Optional[str] = None
    # 'subscription' | 'bill' | 'document' | 'family' | 'insurance'
    # | 'investment' | 'other'
    category: str = "other"
    done: bool = False
    reminder_on: bool = True
    due_at: Optional[datetime] = None
    # 'none' | 'daily' | 'weekly' | 'monthly' | 'yearly'
    repeat: str = "none"
    icon_name: Optional[str] = None
    icon_domain: Optional[str] = None
    # The recurring/one-time cost. Null means "no amount set" (e.g. a free plan
    # or a plain reminder). currency is an ISO code (INR / USD / KWD).
    amount: Optional[float] = None
    currency: str = "INR"
    # Where it came from, e.g. the onboarding chip key ('subs_netflix').
    source: Optional[str] = None

    # Path of an attached document (insurance PDF/photo) in the private bucket;
    # set via the upload endpoint, viewed via a signed URL. None = no document.
    document_path: Optional[str] = None


class TaskCreate(TaskBase):
    """Create payload. user_id comes from the X-User-Id header, not the body."""


class TaskUpdate(BaseModel):
    """All fields optional — patch semantics."""

    title: Optional[str] = None
    notes: Optional[str] = None
    category: Optional[str] = None
    done: Optional[bool] = None
    reminder_on: Optional[bool] = None
    due_at: Optional[datetime] = None
    clear_due_at: bool = False
    repeat: Optional[str] = None
    icon_name: Optional[str] = None
    icon_domain: Optional[str] = None
    amount: Optional[float] = None
    currency: Optional[str] = None
    archived: Optional[bool] = None


class Task(TaskBase):
    id: UUID
    user_id: UUID
    archived: bool = False
    created_at: datetime
    updated_at: datetime
