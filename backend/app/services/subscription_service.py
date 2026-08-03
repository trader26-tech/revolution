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

    def summary(self) -> dict:
        """Aggregate totals, computed server-side so clients never have to
        crunch the full data set. Amounts are monthly-normalised: weekly
        × 52/12, yearly ÷ 12."""
        income_monthly = 0.0
        expense_monthly = 0.0
        count = 0
        per_list: dict[str, int] = {}

        for record in self._repo.list():
            count += 1
            amount = float(record.get("amount") or 0)
            cycle = record.get("cycle") or "monthly"
            if cycle == "weekly":
                monthly = amount * 52 / 12
            elif cycle == "yearly":
                monthly = amount / 12
            else:
                monthly = amount

            if record.get("flow") == "income":
                income_monthly += monthly
            else:
                expense_monthly += monthly

            list_name = record.get("list") or "Personal"
            per_list[list_name] = per_list.get(list_name, 0) + 1

        return {
            "count": count,
            "income_monthly": round(income_monthly, 2),
            "expense_monthly": round(expense_monthly, 2),
            "net_monthly": round(income_monthly - expense_monthly, 2),
            "expense_yearly": round(expense_monthly * 12, 2),
            "per_list": per_list,
        }

@lru_cache
def get_subscription_service() -> SubscriptionService:
    """Provider used as a FastAPI dependency.

    Supabase is the only store — ``get_supabase()`` raises
    ``SupabaseNotConfigured`` if credentials are missing, so there is no
    local fallback.
    """
    repo: SubscriptionRepository = SupabaseSubscriptionRepository(get_supabase())
    return SubscriptionService(repo)
