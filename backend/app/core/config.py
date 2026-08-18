"""Settings loaded from environment / .env."""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Revolution API"
    environment: str = "development"

    # Supabase — the backend is the only writer; use the SERVICE ROLE key.
    supabase_url: str = ""
    supabase_service_role_key: str = ""

    # In-app update control. Bump these via env to roll out a new build — no code
    # change needed. This is the SINGLE place you decide whether a version is
    # mandatory: set `min_supported_version` to the build number everyone must be
    # on, and any installed build below it is FORCED to update.
    #
    #   latest_version        — the newest build number (pubspec "+N")
    #   min_supported_version — anything BELOW this is forced (mandatory update).
    #                           Leave it low for an optional roll-out; raise it to
    #                           a build number to make that build the required
    #                           standard for ALL apps. THIS is your mandatory knob.
    #   apk_url               — download URL for the SIDELOADED (landing-page)
    #                           build only. The Play Store build ignores this and
    #                           updates through Google Play In-App Updates instead
    #                           (Play forbids an app installing its own APK).
    #   update_notes          — short "what's new" shown in the prompt / gate.
    #
    # Example — make build 12 the required standard for everyone:
    #   LATEST_VERSION=12  MIN_SUPPORTED_VERSION=12
    # Optional roll-out of build 12 (users may defer):
    #   LATEST_VERSION=12  MIN_SUPPORTED_VERSION=7
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

    # --- Groq (AI daily one-liners for the Home feed) ----------------------
    # One app-wide key, kept in the backend env only — never in the DB or sent
    # to the client. Unset → no AI lines, the app uses its local fallback.
    #   groq_api_key  — from console.groq.com (starts "gsk_")
    #   groq_model    — override the default model if desired
    groq_api_key: str = ""
    groq_model: str = "llama-3.1-8b-instant"


settings = Settings()
