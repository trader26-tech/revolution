"""Renewal reminder routes.

Ownership is carried by the `X-Owner-Id` header for now (a device/user id).
Swap for real auth later without touching the service layer.
"""
from fastapi import APIRouter, Header, HTTPException

from app.schemas.reminder import Reminder, ReminderCreate, ReminderUpdate
from app.services import reminders as svc

router = APIRouter(prefix="/reminders")


@router.get("", response_model=list[Reminder])
async def list_reminders(x_owner_id: str = Header(...)) -> list[dict]:
    return svc.list_reminders(x_owner_id)


@router.post("", response_model=Reminder, status_code=201)
async def create_reminder(
    payload: ReminderCreate, x_owner_id: str = Header(...)
) -> dict:
    return svc.create_reminder(x_owner_id, payload)


@router.patch("/{reminder_id}", response_model=Reminder)
async def update_reminder(
    reminder_id: str, payload: ReminderUpdate, x_owner_id: str = Header(...)
) -> dict:
    row = svc.update_reminder(x_owner_id, reminder_id, payload)
    if row is None:
        raise HTTPException(status_code=404, detail="Reminder not found")
    return row


@router.delete("/{reminder_id}", status_code=204)
async def delete_reminder(reminder_id: str, x_owner_id: str = Header(...)) -> None:
    if not svc.delete_reminder(x_owner_id, reminder_id):
        raise HTTPException(status_code=404, detail="Reminder not found")
