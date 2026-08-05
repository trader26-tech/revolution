"""Application settings, loaded from environment / .env."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Revolution API"
    version: str = "0.1.0"
    environment: str = "development"

    # Comma-separated list in the env, e.g. CORS_ORIGINS="http://localhost:5173"
    cors_origins: list[str] = ["*"]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
