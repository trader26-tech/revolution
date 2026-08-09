"""Pydantic schemas for the Ideas board — anonymous community suggestions the
whole user base can up/down-vote."""
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class SuggestionCreate(BaseModel):
    text: str = Field(..., min_length=1, max_length=280)


class VoteIn(BaseModel):
    # -1 (down), 0 (clear), +1 (up).
    value: int = Field(..., ge=-1, le=1)


class Suggestion(BaseModel):
    id: str
    text: str
    score: int = 0
    status: str = "open"  # 'open' | 'planned' | 'done'
    # The CURRENT caller's own vote on this idea: -1, 0, +1.
    my_vote: int = 0
    # Whether the current (anonymous) account posted it. Never reveals who else.
    mine: bool = False
    created_at: Optional[datetime] = None


class VoteResult(BaseModel):
    score: int
    my_vote: int
