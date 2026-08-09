"""Ideas board routes — anonymous community suggestions with up/down voting.

Identity is the X-User-Id header (the app-generated account uuid): it scopes a
user's own vote and the "mine" flag, while the idea text itself is anonymous.
"""
from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import current_user_id
from app.schemas.suggestion import Suggestion, SuggestionCreate, VoteIn, VoteResult
from app.services import suggestions as svc

router = APIRouter(prefix="/suggestions", tags=["suggestions"])


@router.get("", response_model=list[Suggestion])
async def list_suggestions(user_id: str = Depends(current_user_id)) -> list[dict]:
    return svc.list_suggestions(user_id)


@router.post("", response_model=Suggestion, status_code=201)
async def create_suggestion(
    payload: SuggestionCreate, user_id: str = Depends(current_user_id)
) -> dict:
    return svc.create_suggestion(user_id, payload.text)


@router.post("/{suggestion_id}/vote", response_model=VoteResult)
async def vote(
    suggestion_id: str,
    payload: VoteIn,
    user_id: str = Depends(current_user_id),
) -> dict:
    result = svc.vote(user_id, suggestion_id, payload.value)
    if result is None:
        raise HTTPException(status_code=404, detail="Suggestion not found")
    return result


@router.delete("/{suggestion_id}", status_code=204)
async def delete_suggestion(
    suggestion_id: str, user_id: str = Depends(current_user_id)
) -> None:
    """Delete a suggestion — only its own author may (author_id must match)."""
    if not svc.delete_suggestion(user_id, suggestion_id):
        # Not found OR not the author — same 404 either way (don't leak existence).
        raise HTTPException(status_code=404, detail="Suggestion not found")
