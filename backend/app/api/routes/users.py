"""User routes.

POST /users/anonymous — mint a new anonymous account. The DATABASE generates
                        the uuid; the app stores the returned user_id and sends
                        it as X-User-Id from then on. Called once per install
                        (and again after sign-out).
POST /users/ensure    — self-heal: re-materialise the row for an id the server
                        handed out earlier. Best-effort; task writes also
                        self-heal, so a failed call costs nothing.
GET  /users/me        — the caller's account row.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import current_user_id
from app.services import users as svc

router = APIRouter(prefix="/users", tags=["users"])


@router.post("/anonymous", status_code=201)
async def create_anonymous() -> dict:
    row = svc.create_anonymous()
    return {"user_id": row["id"], "user": row}


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
