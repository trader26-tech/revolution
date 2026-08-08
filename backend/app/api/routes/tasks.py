"""Task routes. Identity is the X-User-Id header (the app-generated account
uuid), so each account only touches its own tasks."""
from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import current_user_id
from app.schemas.task import Task, TaskCreate, TaskUpdate
from app.services import tasks as svc

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=list[Task])
async def list_tasks(user_id: str = Depends(current_user_id)) -> list[dict]:
    return svc.list_tasks(user_id)


@router.post("", response_model=Task, status_code=201)
async def create_task(
    payload: TaskCreate, user_id: str = Depends(current_user_id)
) -> dict:
    return svc.create_task(user_id, payload)


@router.patch("/{task_id}", response_model=Task)
async def update_task(
    task_id: str, payload: TaskUpdate, user_id: str = Depends(current_user_id)
) -> dict:
    row = svc.update_task(user_id, task_id, payload)
    if row is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return row


@router.delete("/{task_id}", status_code=204)
async def delete_task(
    task_id: str, user_id: str = Depends(current_user_id)
) -> None:
    if not svc.delete_task(user_id, task_id):
        raise HTTPException(status_code=404, detail="Task not found")
