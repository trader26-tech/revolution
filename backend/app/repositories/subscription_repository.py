"""Data access for subscriptions.

``SupabaseSubscriptionRepository`` persists to a Supabase ``subscriptions``
table (see ``backend/sql/subscriptions.sql``) — the app's sole source of
truth; there is no local store.

The service layer depends only on the ``SubscriptionRepository`` Protocol, so
swapping the backing store never touches business logic.
"""

from __future__ import annotations

import uuid
from datetime import date
from typing import Optional, Protocol

from ..schemas.subscription import Subscription, SubscriptionCreate, SubscriptionUpdate

TABLE = "subscriptions"


def _new_id() -> str:
    return uuid.uuid4().hex[:12]


def _serialize(record: dict) -> dict:
    """Coerce date objects to ISO strings for JSON/Supabase storage."""
    out = dict(record)
    for key in ("anchor_date", "trial_ends"):
        value = out.get(key)
        if isinstance(value, date):
            out[key] = value.isoformat()
    return out


class SubscriptionRepository(Protocol):
    def list(self) -> list[dict]: ...
    def get(self, sub_id: str) -> Optional[dict]: ...
    def create(self, data: SubscriptionCreate) -> dict: ...
    def update(self, sub_id: str, patch: SubscriptionUpdate) -> Optional[dict]: ...
    def delete(self, sub_id: str) -> bool: ...


class SupabaseSubscriptionRepository:
    """Persists subscriptions to a Supabase table."""

    def __init__(self, client) -> None:
        self._client = client

    def list(self) -> list[dict]:
        res = self._client.table(TABLE).select("*").order("anchor_date").execute()
        return res.data or []

    def get(self, sub_id: str) -> Optional[dict]:
        res = self._client.table(TABLE).select("*").eq("id", sub_id).limit(1).execute()
        rows = res.data or []
        return rows[0] if rows else None

    def create(self, data: SubscriptionCreate) -> dict:
        sub_id = data.id or _new_id()
        record = _serialize({**data.model_dump(exclude={"id"}), "id": sub_id})
        res = self._client.table(TABLE).insert(record).execute()
        return (res.data or [record])[0]

    def update(self, sub_id: str, patch: SubscriptionUpdate) -> Optional[dict]:
        changes = _serialize(patch.model_dump(exclude_unset=True))
        if not changes:
            return self.get(sub_id)
        res = self._client.table(TABLE).update(changes).eq("id", sub_id).execute()
        rows = res.data or []
        return rows[0] if rows else None

    def delete(self, sub_id: str) -> bool:
        res = self._client.table(TABLE).delete().eq("id", sub_id).execute()
        return bool(res.data)


def to_model(record: dict) -> Subscription:
    """Map a raw store record to the API schema."""
    return Subscription.model_validate(record)
