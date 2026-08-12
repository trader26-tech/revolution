"""Standalone documents — a first-class file library, independent of tasks.

Unlike a task's attached policy (see tasks.attach_document), a document here is
its own record: a user-given name, a folder (one of the app's task categories),
and a file in the private `user-docs` bucket. The Documents tab lists these AND
merges in every task that has an attached document, so it's the one place to see
everything.

Table `documents`:
  id uuid pk, user_id text, name text, folder text, path text,
  content_type text, size bigint, created_at timestamptz default now()
"""
from typing import Any, Optional

from app.core.supabase import get_supabase

_TABLE = "documents"
_BUCKET = "user-docs"

_EXT = {
    "application/pdf": "pdf",
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/heic": "heic",
    "image/webp": "webp",
}


def list_documents(user_id: str) -> list[dict[str, Any]]:
    """Every standalone document the user has, newest first."""
    res = (
        get_supabase()
        .table(_TABLE)
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


def create_document(
    user_id: str,
    *,
    name: str,
    folder: str,
    data: bytes,
    content_type: str,
    size: int,
) -> dict[str, Any]:
    """Upload the file to the private bucket and record the row. The object is
    keyed by user + a fresh row id so uploads never collide."""
    sb = get_supabase()
    ext = _EXT.get(content_type, "bin")

    # Insert first to get the row id, then store the object under it.
    row = (
        sb.table(_TABLE)
        .insert(
            {
                "user_id": user_id,
                "name": name.strip() or "Document",
                "folder": folder,
                "content_type": content_type,
                "size": size,
                "path": "",  # filled in below
            }
        )
        .execute()
    ).data[0]

    path = f"{user_id}/{row['id']}.{ext}"
    sb.storage.from_(_BUCKET).upload(
        path, data, {"content-type": content_type, "upsert": "true"}
    )
    updated = (
        sb.table(_TABLE)
        .update({"path": path})
        .eq("id", row["id"])
        .eq("user_id", user_id)
        .execute()
    ).data[0]
    return updated


def signed_url(
    user_id: str, doc_id: str, expires_in: int = 3600
) -> Optional[str]:
    """A short-lived signed URL to VIEW the document, or None if not theirs."""
    row = (
        get_supabase()
        .table(_TABLE)
        .select("path")
        .eq("id", doc_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data
    if not row or not row[0].get("path"):
        return None
    res = get_supabase().storage.from_(_BUCKET).create_signed_url(
        row[0]["path"], expires_in
    )
    return res.get("signedURL") or res.get("signedUrl")


def delete_document(user_id: str, doc_id: str) -> bool:
    """Remove the row and its stored object. True if a row was deleted."""
    sb = get_supabase()
    row = (
        sb.table(_TABLE)
        .select("path")
        .eq("id", doc_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    ).data
    if not row:
        return False
    path = row[0].get("path")
    if path:
        try:
            sb.storage.from_(_BUCKET).remove([path])
        except Exception:
            pass  # object may already be gone; still drop the row
    deleted = (
        sb.table(_TABLE)
        .delete()
        .eq("id", doc_id)
        .eq("user_id", user_id)
        .execute()
    ).data
    return bool(deleted)
