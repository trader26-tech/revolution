"""Custom brand logos — manually-curated overrides for apps the auto-resolver
can't find. Read from Supabase; the app matches the user's text against these."""
from typing import Any

from app.core.supabase import get_supabase

_TABLE = "brand_logos"


def list_logos() -> list[dict[str, Any]]:
    res = get_supabase().table(_TABLE).select("*").order("name").execute()
    return res.data or []
