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

    # --- WhatsApp reminders (Twilio) ---------------------------------------
    # Twilio credentials + the WhatsApp sender number. For the sandbox, the
    # "from" number is Twilio's shared sandbox number (e.g. +14155238886) and
    # recipients must have joined the sandbox. Swap these for a production
    # WhatsApp sender later — no code change needed.
    #   twilio_account_sid   — starts with "AC..."
    #   twilio_auth_token     — the secret token (KEEP IN .env, never commit)
    #   twilio_whatsapp_from  — the sender, e.g. "whatsapp:+14155238886"
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_whatsapp_from: str = ""


settings = Settings()
