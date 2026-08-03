"""Pydantic schemas for the Revolution subscription domain.

These mirror the frontend `Subscription` type (see
`frontend/src/lib/types.ts`) so the two stay in lockstep.
"""

from __future__ import annotations

from datetime import date
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class Cycle(str, Enum):
    weekly = "weekly"
    monthly = "monthly"
    yearly = "yearly"


class ListName(str, Enum):
    personal = "Personal"
    family = "Family"
    business = "Business"


class Flow(str, Enum):
    """Direction of money — drives the light colour on the planet."""

    income = "income"
    expense = "expense"


class Category(str, Enum):
    streaming = "Streaming"
    music = "Music"
    productivity = "Productivity"
    cloud = "Cloud"
    fitness = "Fitness"
    gaming = "Gaming"
    news = "News"
    ai = "AI"
    utilities = "Utilities"
    other = "Other"
    # income-side
    salary = "Salary"
    freelance = "Freelance"
    dividends = "Dividends"
    rental = "Rental"
    refunds = "Refunds"


class SubscriptionBase(BaseModel):
    """Fields a client may send when creating or updating a subscription."""

    model_config = ConfigDict(use_enum_values=True)

    name: str = Field(..., min_length=1, max_length=120)
    color: str = Field("#8a1cff", description="Tile hex color")
    mark: str = Field("○", max_length=4, description="1–2 char logo glyph")
    brand_slug: Optional[str] = Field(
        None, max_length=64, description="simple-icons slug for the brand logo"
    )
    amount: float = Field(..., ge=0)
    currency: str = Field("USD", min_length=3, max_length=3)
    cycle: Cycle = Cycle.monthly
    category: Category = Category.other
    list: ListName = ListName.personal
    flow: Flow = Flow.expense
    payment_method: str = Field("", max_length=80)
    anchor_date: date = Field(..., description="First / next billing anchor")
    is_trial: bool = False
    trial_ends: Optional[date] = None
    notes: Optional[str] = Field(None, max_length=500)


class SubscriptionCreate(SubscriptionBase):
    """Payload for POST. Client id is optional (server generates one)."""

    id: Optional[str] = None


class SubscriptionUpdate(BaseModel):
    """Partial update — every field optional."""

    model_config = ConfigDict(use_enum_values=True)

    name: Optional[str] = Field(None, min_length=1, max_length=120)
    color: Optional[str] = None
    mark: Optional[str] = Field(None, max_length=4)
    brand_slug: Optional[str] = Field(None, max_length=64)
    amount: Optional[float] = Field(None, ge=0)
    currency: Optional[str] = Field(None, min_length=3, max_length=3)
    cycle: Optional[Cycle] = None
    category: Optional[Category] = None
    list: Optional[ListName] = None
    flow: Optional[Flow] = None
    payment_method: Optional[str] = Field(None, max_length=80)
    anchor_date: Optional[date] = None
    is_trial: Optional[bool] = None
    trial_ends: Optional[date] = None
    notes: Optional[str] = Field(None, max_length=500)


class Subscription(SubscriptionBase):
    """Full record as returned by the API."""

    id: str
