"""Supabase client — a single lazily-created client using the service role key.

The backend is the only writer, so this key stays server-side and bypasses RLS.
"""
from functools import lru_cache

from supabase import Client, create_client

from app.core.config import settings


@lru_cache
def get_supabase() -> Client:
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise RuntimeError(
            "Supabase is not configured. Set SUPABASE_URL and "
            "SUPABASE_SERVICE_ROLE_KEY in the environment."
        )
    return create_client(settings.supabase_url, settings.supabase_service_role_key)
