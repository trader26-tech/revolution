"""Data access for subscriptions.

Two interchangeable implementations behind one Protocol:

* ``SupabaseSubscriptionRepository`` — persists to a Supabase ``subscriptions``
  table (see ``backend/sql/subscriptions.sql``).
* ``InMemorySubscriptionRepository`` — a process-local fallback used when
  Supabase is not configured, so the API (and the frontend against it) still
  works end-to-end in local dev, tests, and demos.

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


class InMemorySubscriptionRepository:
    """Ephemeral store. Data lives for the lifetime of the process."""

    def __init__(self) -> None:
        self._items: dict[str, dict] = {}

    def list(self) -> list[dict]:
        return list(self._items.values())

    def get(self, sub_id: str) -> Optional[dict]:
        return self._items.get(sub_id)

    def create(self, data: SubscriptionCreate) -> dict:
        sub_id = data.id or _new_id()
        record = _serialize({**data.model_dump(exclude={"id"}), "id": sub_id})
        self._items[sub_id] = record
        return record

    def update(self, sub_id: str, patch: SubscriptionUpdate) -> Optional[dict]:
        existing = self._items.get(sub_id)
        if existing is None:
            return None
        changes = _serialize(patch.model_dump(exclude_unset=True))
        existing.update(changes)
        self._items[sub_id] = existing
        return existing

    def delete(self, sub_id: str) -> bool:
        return self._items.pop(sub_id, None) is not None


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
