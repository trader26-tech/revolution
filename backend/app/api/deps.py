"""Shared route dependencies."""
from typing import Optional

from fastapi import Header, HTTPException


def current_user_id(
    x_user_id: Optional[str] = Header(None),
    x_owner_id: Optional[str] = Header(None),
) -> str:
    """The caller's user uuid (app-generated at install, claimed on login).

    Reads `X-User-Id`; also accepts the legacy `X-Owner-Id` name so older app
    builds keep working during the transition.
    """
    user_id = x_user_id or x_owner_id
    if not user_id:
        raise HTTPException(status_code=422, detail="Missing X-User-Id header")
    return user_id
