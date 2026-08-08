"""User routes.

POST /users/ensure — materialise the anonymous row for an app-generated uuid.
                     The app fires this once at startup (best-effort; task
                     writes also self-heal, so a failed call costs nothing).
GET  /users/me     — the caller's account row.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import current_user_id
from app.services import users as svc

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/ensure")
async def ensure(user_id: str = Depends(current_user_id)) -> dict:
    svc.ensure_user(user_id)
    return {"user_id": user_id, "status": "ok"}


@router.get("/me")
async def me(user_id: str = Depends(current_user_id)) -> dict:
    row = svc.get_user(user_id)
    if row is None:
        raise HTTPException(status_code=404, detail="User not found")
    return row
