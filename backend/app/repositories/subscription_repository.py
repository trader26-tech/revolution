"""Data access for subscriptions.

``SupabaseSubscriptionRepository`` persists to a Supabase ``subscriptions``
table — the app's sole source of truth; there is no local store.

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


#: Columns added after the initial release. If the deployed Supabase table
#: predates them, PostgREST rejects the whole write with PGRST204. We retry
#: once without them so the app keeps working until the migration is applied
#: (see the `flow` column note in backend/README.md).
OPTIONAL_COLUMNS = ("flow",)


def _missing_column(exc: Exception) -> Optional[str]:
    """Return the optional column PostgREST complained about, if any."""
    message = str(exc)
    if "PGRST204" not in message and "schema cache" not in message:
        return None
    for column in OPTIONAL_COLUMNS:
        if f"'{column}'" in message:
            return column
    return None


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
        try:
            res = self._client.table(TABLE).insert(record).execute()
        except Exception as exc:  # noqa: BLE001 - re-raised unless it's a known gap
            column = _missing_column(exc)
            if column is None:
                raise
            retry = {k: v for k, v in record.items() if k != column}
            res = self._client.table(TABLE).insert(retry).execute()
            return {**(res.data or [retry])[0], column: record.get(column)}
        return (res.data or [record])[0]

    def update(self, sub_id: str, patch: SubscriptionUpdate) -> Optional[dict]:
        changes = _serialize(patch.model_dump(exclude_unset=True))
        if not changes:
            return self.get(sub_id)
        try:
            res = self._client.table(TABLE).update(changes).eq("id", sub_id).execute()
        except Exception as exc:  # noqa: BLE001 - re-raised unless it's a known gap
            column = _missing_column(exc)
            if column is None:
                raise
            retry = {k: v for k, v in changes.items() if k != column}
            if not retry:
                return self.get(sub_id)
            res = self._client.table(TABLE).update(retry).eq("id", sub_id).execute()
        rows = res.data or []
        return rows[0] if rows else None

    def delete(self, sub_id: str) -> bool:
        res = self._client.table(TABLE).delete().eq("id", sub_id).execute()
        return bool(res.data)


def to_model(record: dict) -> Subscription:
    """Map a raw store record to the API schema."""
    return Subscription.model_validate(record)
