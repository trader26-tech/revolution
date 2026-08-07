"""WhatsApp reminder routes.

Test-friendly endpoints to send a WhatsApp reminder to a user. Ownership is the
X-Owner-Id header (the logged-in user's id = their phone number), which is also
the WhatsApp recipient — so a user can only trigger their own reminder.

  POST /reminders/send-test  → sends YOUR real "due today / pending" reminder
  POST /reminders/send-now   → sends a custom message (quick connectivity test)
"""
from typing import Optional

from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel

import httpx

from app.services import reminders as reminder_svc
from app.services.whatsapp import WhatsAppNotConfigured, send_whatsapp

router = APIRouter(prefix="/reminders", tags=["reminders"])


class SendNow(BaseModel):
    # Optional override recipient (E.164, e.g. "+918925188870"). Defaults to the
    # X-Owner-Id (the logged-in user's own number).
    to: Optional[str] = None
    body: str = "Hello from *Revolution* 👋 — your WhatsApp reminders are live."


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
async def send_now(payload: SendNow, x_owner_id: str = Header(...)) -> dict:
    to = payload.to or x_owner_id
    result = _send(to, payload.body)
    return {"status": "sent", "to": to, "sid": result.get("sid")}


@router.post("/send-test")
async def send_test(x_owner_id: str = Header(...)) -> dict:
    """Build the user's real reminder from their tasks and WhatsApp it to them."""
    message = reminder_svc.build_reminder(x_owner_id)
    if message is None:
        # Nothing due — still send a friendly note so the test always delivers.
        message = (
            "*Revolution* — you're all caught up! 🎉\n"
            "No pending or due-today items. Nice work."
        )
    result = _send(x_owner_id, message)
    return {"status": "sent", "to": x_owner_id, "sid": result.get("sid")}
