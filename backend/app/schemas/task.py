"""Pydantic schemas for tasks — the items a user tracks (with an optional
brand icon, due date, and repeat)."""
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class TaskBase(BaseModel):
    title: str = Field(..., examples=["Netflix"])
    done: bool = False
    reminder_on: bool = True
    due_at: Optional[datetime] = None
    # 'none' | 'daily' | 'weekly' | 'monthly' | 'yearly'
    repeat: str = "none"
    icon_name: Optional[str] = None
    icon_domain: Optional[str] = None


class TaskCreate(TaskBase):
    """Create payload. owner_id comes from the X-Owner-Id header, not the body."""


class TaskUpdate(BaseModel):
    """All fields optional — patch semantics."""

    title: Optional[str] = None
    done: Optional[bool] = None
    reminder_on: Optional[bool] = None
    due_at: Optional[datetime] = None
    clear_due_at: bool = False
    repeat: Optional[str] = None
    icon_name: Optional[str] = None
    icon_domain: Optional[str] = None


class Task(TaskBase):
    id: UUID
    owner_id: str
    created_at: datetime
    updated_at: datetime
