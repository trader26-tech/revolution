"""Task routes. Ownership is carried by the X-Owner-Id header (the logged-in
user's id), so each account only touches its own tasks."""
from fastapi import APIRouter, Header, HTTPException

from app.schemas.task import Task, TaskCreate, TaskUpdate
from app.services import tasks as svc

router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=list[Task])
async def list_tasks(x_owner_id: str = Header(...)) -> list[dict]:
    return svc.list_tasks(x_owner_id)


@router.post("", response_model=Task, status_code=201)
async def create_task(payload: TaskCreate, x_owner_id: str = Header(...)) -> dict:
    return svc.create_task(x_owner_id, payload)


@router.patch("/{task_id}", response_model=Task)
async def update_task(
    task_id: str, payload: TaskUpdate, x_owner_id: str = Header(...)
) -> dict:
    row = svc.update_task(x_owner_id, task_id, payload)
    if row is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return row


@router.delete("/{task_id}", status_code=204)
async def delete_task(task_id: str, x_owner_id: str = Header(...)) -> None:
    if not svc.delete_task(x_owner_id, task_id):
        raise HTTPException(status_code=404, detail="Task not found")
