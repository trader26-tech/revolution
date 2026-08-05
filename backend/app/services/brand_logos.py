"""Custom brand logos — manually-curated overrides for apps the auto-resolver
can't find. Read from Supabase; the app matches the user's text against these."""
from typing import Any, Optional

from app.core.supabase import get_supabase

_TABLE = "brand_logos"


def list_logos() -> list[dict[str, Any]]:
    res = get_supabase().table(_TABLE).select("*").order("name").execute()
    return res.data or []


def _find_by_name(name: str) -> Optional[dict[str, Any]]:
    res = (
        get_supabase()
        .table(_TABLE)
        .select("id")
        .ilike("name", name)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


def upsert_logo(
    name: str,
    logo_url: str,
    *,
    category: str = "Other",
    keywords: str = "",
    source: str = "user",
) -> dict[str, Any]:
    """Add a logo the user picked, if we don't already have that name — so the
    curated set grows automatically from real usage. Idempotent by name."""
    existing = _find_by_name(name.strip())
    if existing is not None:
        return existing
    row = {
        "name": name.strip(),
        "category": category,
        "keywords": keywords or name.strip().lower(),
        "logo_url": logo_url,
        "source": source,
    }
    res = get_supabase().table(_TABLE).insert(row).execute()
    return res.data[0]
