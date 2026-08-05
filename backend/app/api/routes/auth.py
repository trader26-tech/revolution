"""Phone-number login routes.

The whole model for now: POST a phone number, get back a user id. That id is
what the client sends as `X-Owner-Id` on every other request, so each account's
data stays its own. No password / OTP yet — that's a later step.
"""
from fastapi import APIRouter, HTTPException

from app.schemas.auth import LoginResponse, PhoneLoginRequest, User
from app.services import users as svc

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/phone", response_model=LoginResponse)
async def login_with_phone(payload: PhoneLoginRequest) -> LoginResponse:
    """Log in or sign up with a phone number.

    - If the number already has an account, returns it (`is_new=false`).
    - Otherwise creates one (`is_new=true`).
    """
    user, is_new = svc.login_or_create(payload.phone)
    return LoginResponse(
        user_id=user["id"],
        phone=user["phone"],
        is_new=is_new,
        display_name=user.get("display_name"),
    )


@router.get("/me/{user_id}", response_model=User)
async def get_me(user_id: str) -> User:
    """Fetch an account by id — used by the app to confirm a stored session."""
    user = svc.get_by_id(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return User(**user)
