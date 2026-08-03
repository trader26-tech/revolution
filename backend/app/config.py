from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment / .env file."""

    supabase_url: str = ""
    supabase_key: str = ""
    # Exact origins allowed by CORS. Vite dev (5173) + preview (4173) by
    # default; add your deployed frontend URL via the CORS_ORIGINS env var.
    cors_origins: str = "http://localhost:5173,http://localhost:4173"
    # Any origin matching this regex is also allowed. Defaults to every
    # Railway public domain, so the deployed frontend is never blocked by a
    # small URL mismatch. Set CORS_ORIGIN_REGEX to tighten it.
    cors_origin_regex: str = r"https://.*\.up\.railway\.app"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
