"""Business logic for subscriptions.

Sits between the API routes and the repository. Routes never touch a
repository directly — they call the service, which owns validation beyond
schema level, id handling, and error semantics.
"""

from __future__ import annotations

from functools import lru_cache

from ..schemas.subscription import Subscription, SubscriptionCreate, SubscriptionUpdate
from ..supabase_client import get_supabase
from ..repositories.subscription_repository import (
    InMemorySubscriptionRepository,
    SubscriptionRepository,
    SupabaseSubscriptionRepository,
    to_model,
)


class SubscriptionNotFound(Exception):
    """Raised when an id does not resolve to a stored subscription."""

    def __init__(self, sub_id: str) -> None:
        self.sub_id = sub_id
        super().__init__(f"Subscription {sub_id!r} not found")


class SubscriptionService:
    def __init__(self, repo: SubscriptionRepository) -> None:
        self._repo = repo

    def list(self) -> list[Subscription]:
        return [to_model(r) for r in self._repo.list()]

    def get(self, sub_id: str) -> Subscription:
        record = self._repo.get(sub_id)
        if record is None:
            raise SubscriptionNotFound(sub_id)
        return to_model(record)

    def create(self, data: SubscriptionCreate) -> Subscription:
        return to_model(self._repo.create(data))

    def update(self, sub_id: str, patch: SubscriptionUpdate) -> Subscription:
        record = self._repo.update(sub_id, patch)
        if record is None:
            raise SubscriptionNotFound(sub_id)
        return to_model(record)

    def delete(self, sub_id: str) -> None:
        if not self._repo.delete(sub_id):
            raise SubscriptionNotFound(sub_id)

    @property
    def is_persistent(self) -> bool:
        return isinstance(self._repo, SupabaseSubscriptionRepository)


@lru_cache
def get_subscription_service() -> SubscriptionService:
    """Provider used as a FastAPI dependency.

    Chooses the Supabase-backed repository when credentials are present,
    otherwise falls back to the in-memory store so the app always boots.
    """
    client = get_supabase()
    if client is not None:
        repo: SubscriptionRepository = SupabaseSubscriptionRepository(client)
    else:
        repo = InMemorySubscriptionRepository()
    return SubscriptionService(repo)
