"""Standalone document routes — a first-class file library.

Identity is the X-User-Id header. A document is its own record (name + folder +
file), independent of any task; the app's Documents tab lists these and merges
in task-attached policies for a single view.
"""
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile

from app.api.deps import current_user_id
from app.services import documents as svc

router = APIRouter(prefix="/documents", tags=["documents"])

_ALLOWED_DOC_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/heic",
    "image/webp",
}
_MAX_DOC_BYTES = 10 * 1024 * 1024  # 10 MB — matches the bucket limit.


@router.get("")
async def list_documents(user_id: str = Depends(current_user_id)) -> list[dict]:
    return svc.list_documents(user_id)


@router.post("", status_code=201)
async def create_document(
    file: UploadFile = File(...),
    name: str = Form(...),
    folder: str = Form("other"),
    user_id: str = Depends(current_user_id),
) -> dict:
    """Add a standalone document: a user-given name, a folder (task category),
    and the file itself. Stored privately; viewed later via the signed URL."""
    if file.content_type not in _ALLOWED_DOC_TYPES:
        raise HTTPException(status_code=415, detail="Unsupported file type")
    data = await file.read()
    if len(data) > _MAX_DOC_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 10 MB)")
    return svc.create_document(
        user_id,
        name=name,
        folder=folder,
        data=data,
        content_type=file.content_type,
        size=len(data),
    )


@router.get("/{doc_id}")
async def document_url(
    doc_id: str, user_id: str = Depends(current_user_id)
) -> dict:
    """A short-lived signed URL to view/share the document."""
    url = svc.signed_url(user_id, doc_id)
    if url is None:
        raise HTTPException(status_code=404, detail="Document not found")
    return {"url": url}


@router.delete("/{doc_id}", status_code=204)
async def delete_document(
    doc_id: str, user_id: str = Depends(current_user_id)
) -> None:
    if not svc.delete_document(user_id, doc_id):
        raise HTTPException(status_code=404, detail="Document not found")
