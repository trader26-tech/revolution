"""WhatsApp reminder routes.

Test-friendly endpoints to send a WhatsApp reminder to a user. Identity is the
X-User-Id header (the account uuid); the recipient phone is looked up from the
user's account row — so a user can only trigger their own reminder, and an
anonymous (unclaimed) account has no number to send to.

  POST /reminders/send-test  → sends YOUR real "due today / pending" reminder
  POST /reminders/send-now   → sends a custom message (quick connectivity test)
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import httpx

from app.api.deps import current_user_id
from app.services import reminders as reminder_svc
from app.services import users as users_svc
from app.services.whatsapp import WhatsAppNotConfigured, send_whatsapp

router = APIRouter(prefix="/reminders", tags=["reminders"])


class SendNow(BaseModel):
    # Optional override recipient (E.164, e.g. "+918925188870"). Defaults to
    # the caller's own verified number.
    to: Optional[str] = None
    body: str = "Hello from *Revolution* 👋 — your WhatsApp reminders are live."


def _own_phone(user_id: str) -> str:
    """The caller's verified phone, or 400 if the account isn't claimed yet."""
    user = users_svc.get_user(user_id)
    phone = (user or {}).get("phone")
    if not phone:
        raise HTTPException(
            status_code=400,
            detail="No phone on this account yet — log in with your number first.",
        )
    return phone


def _send(to: str, body: str) -> dict:
    try:
        return send_whatsapp(to, body)
    except WhatsAppNotConfigured as e:
        raise HTTPException(status_code=503, detail=str(e))
    except httpx.HTTPStatusError as e:
        # Surface Twilio's error (e.g. recipient hasn't joined the sandbox).
        detail = e.response.text
        raise HTTPException(status_code=502, detail=f"Twilio error: {detail}")


@router.post("/send-now")
async def send_now(
    payload: SendNow, user_id: str = Depends(current_user_id)
) -> dict:
    to = payload.to or _own_phone(user_id)
    result = _send(to, payload.body)
    return {"status": "sent", "to": to, "sid": result.get("sid")}


@router.post("/send-test")
async def send_test(user_id: str = Depends(current_user_id)) -> dict:
    """Build the user's real reminder from their tasks and WhatsApp it to them."""
    to = _own_phone(user_id)
    message = reminder_svc.build_reminder(user_id)
    if message is None:
        # Nothing due — still send a friendly note so the test always delivers.
        message = (
            "*Revolution* — you're all caught up! 🎉\n"
            "No pending or due-today items. Nice work."
        )
    result = _send(to, message)
    return {"status": "sent", "to": to, "sid": result.get("sid")}
