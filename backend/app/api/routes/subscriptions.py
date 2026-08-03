"""Subscription CRUD endpoints."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status

from ...schemas.subscription import (
    Subscription,
    SubscriptionCreate,
    SubscriptionUpdate,
)
from ...services.subscription_service import (
    SubscriptionNotFound,
    SubscriptionService,
    get_subscription_service,
)

router = APIRouter(prefix="/api/subscriptions", tags=["subscriptions"])


@router.get("", response_model=list[Subscription])
def list_subscriptions(
    service: SubscriptionService = Depends(get_subscription_service),
) -> list[Subscription]:
    return service.list()


@router.post("", response_model=Subscription, status_code=status.HTTP_201_CREATED)
def create_subscription(
    payload: SubscriptionCreate,
    service: SubscriptionService = Depends(get_subscription_service),
) -> Subscription:
    return service.create(payload)


@router.get("/{sub_id}", response_model=Subscription)
def get_subscription(
    sub_id: str,
    service: SubscriptionService = Depends(get_subscription_service),
) -> Subscription:
    try:
        return service.get(sub_id)
    except SubscriptionNotFound as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc


@router.patch("/{sub_id}", response_model=Subscription)
def update_subscription(
    sub_id: str,
    payload: SubscriptionUpdate,
    service: SubscriptionService = Depends(get_subscription_service),
) -> Subscription:
    try:
        return service.update(sub_id, payload)
    except SubscriptionNotFound as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc


@router.delete("/{sub_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_subscription(
    sub_id: str,
    service: SubscriptionService = Depends(get_subscription_service),
) -> Response:
    try:
        service.delete(sub_id)
    except SubscriptionNotFound as exc:
        raise HTTPException(status.HTTP_404_NOT_FOUND, str(exc)) from exc
    return Response(status_code=status.HTTP_204_NO_CONTENT)
