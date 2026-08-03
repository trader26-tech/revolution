from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from .config import get_settings


class SupabaseNotConfigured(RuntimeError):
    """Raised when Supabase credentials are missing.

    Supabase is the sole source of truth for this app — there is no local
    fallback store — so the API must not run without credentials.
    """

    def __init__(self) -> None:
        super().__init__(
            "Supabase is not configured. Set SUPABASE_URL and SUPABASE_KEY "
            "in backend/.env (from Supabase → Project Settings → API). "
            "This app has no local store; Supabase is required."
        )


@lru_cache
def get_supabase() -> Client:
    """Return a cached Supabase client.

    Raises ``SupabaseNotConfigured`` if credentials are absent — the app is
    Supabase-only and has no in-memory fallback.
    """
    settings = get_settings()
    if not settings.supabase_url or not settings.supabase_key:
        raise SupabaseNotConfigured()
    return create_client(settings.supabase_url, settings.supabase_key)
