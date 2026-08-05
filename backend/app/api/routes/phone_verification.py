"""Phone verification routes (onboarding).

Two audiences:
  * The app  → POST /phone/verify/start  and  GET /phone/verify/{id}
  * Meta     → GET/POST /phone/whatsapp/webhook  (the inbound-message callback)

Ownership is carried by X-Owner-Id, matching the rest of the API.
"""
from fastapi import APIRouter, Header, HTTPException, Query, Request, Response

from app.core.config import settings
from app.schemas.phone_verification import (
    StartVerificationRequest,
    StartVerificationResponse,
    VerificationStatus,
)
from app.services import phone_verification as svc

router = APIRouter()


@router.post(
    "/phone/verify/start",
    response_model=StartVerificationResponse,
    status_code=201,
    tags=["phone-verification"],
)
async def start_verification(
    payload: StartVerificationRequest, x_owner_id: str = Header(...)
) -> dict:
    return svc.start(x_owner_id, payload.phone)


@router.get(
    "/phone/verify/{verification_id}",
    response_model=VerificationStatus,
    tags=["phone-verification"],
)
async def verification_status(
    verification_id: str, x_owner_id: str = Header(...)
) -> dict:
    row = svc.status(x_owner_id, verification_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    return row


# --- WhatsApp Cloud API webhook -------------------------------------------
# Meta first GETs this URL with a challenge to prove we own it, then POSTs every
# inbound message here. Configure the URL + verify token in the Meta dashboard.


@router.get("/phone/whatsapp/webhook", tags=["phone-verification"])
async def whatsapp_webhook_verify(
    hub_mode: str = Query("", alias="hub.mode"),
    hub_challenge: str = Query("", alias="hub.challenge"),
    hub_verify_token: str = Query("", alias="hub.verify_token"),
) -> Response:
    if hub_mode == "subscribe" and hub_verify_token == settings.whatsapp_verify_token:
        return Response(content=hub_challenge, media_type="text/plain")
    raise HTTPException(status_code=403, detail="Verification token mismatch")


@router.post("/phone/whatsapp/webhook", tags=["phone-verification"])
async def whatsapp_webhook_inbound(request: Request) -> dict:
    """Handle inbound WhatsApp messages and mark matching attempts verified.

    We always return 200 so Meta doesn't retry; unmatched messages are ignored.
    """
    body = await request.json()
    for sender, text in _iter_text_messages(body):
        svc.ingest_inbound(sender, text)
    return {"status": "ok"}


def _iter_text_messages(body: dict):
    """Yield (from_number, text) for each text message in a webhook payload.

    Cloud API shape: entry[].changes[].value.messages[] with {from, text.body}.
    """
    for entry in body.get("entry", []) or []:
        for change in entry.get("changes", []) or []:
            value = change.get("value", {}) or {}
            for msg in value.get("messages", []) or []:
                if msg.get("type") != "text":
                    continue
                sender = msg.get("from")
                text = (msg.get("text") or {}).get("body", "")
                if sender:
                    yield sender, text
