"""Settings loaded from environment / .env."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Revolution API"
    environment: str = "development"

    # Supabase — the backend is the only writer; use the SERVICE ROLE key.
    supabase_url: str = ""
    supabase_service_role_key: str = ""

    # In-app update (Android, sideloaded APK). Bump these via env to roll out a
    # new build — no code change needed.
    #   latest_version      — the newest build number (Task's pubspec "+N")
    #   min_supported_version — anything below this must update (forced)
    #   apk_url             — where the Update button sends the user to download
    #   update_notes        — short "what's new" shown in the prompt
    latest_version: int = 1
    min_supported_version: int = 1
    apk_url: str = ""
    update_notes: str = ""


settings = Settings()
