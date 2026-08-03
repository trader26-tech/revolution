from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from .config import get_settings


@lru_cache
def get_supabase() -> Client | None:
    """Return a cached Supabase client, or None if not configured.

    Kept optional so the API still boots (and /health works) before the
    real Supabase credentials are filled into .env.
    """
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_key:
        return None
    return create_client(settings.supabase_url, settings.supabase_key)
