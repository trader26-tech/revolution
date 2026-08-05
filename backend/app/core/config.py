"""Settings loaded from environment / .env."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Revolution API"
    environment: str = "development"

    # Supabase — the backend is the only writer; use the SERVICE ROLE key.
    supabase_url: str = ""
    supabase_service_role_key: str = ""


settings = Settings()
