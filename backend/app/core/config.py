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

    # Supabase — the backend is the only writer. Use the service role key.
    supabase_url: str = ""
    supabase_service_role_key: str = ""

    # --- Phone verification via WhatsApp (free, user-initiated) --------------
    # The number users send their code TO, in E.164 without the '+', e.g.
    # "15551234567". This is your WhatsApp Cloud API test/business number.
    whatsapp_business_number: str = ""

    # Meta Cloud API credentials — only needed to *reply* to the user with a
    # confirmation (optional). Inbound verification works without them.
    whatsapp_phone_number_id: str = ""
    whatsapp_access_token: str = ""

    # Secret you set in the Meta webhook config; Meta echoes it on GET to prove
    # the endpoint is yours.
    whatsapp_verify_token: str = "revolution-verify"

    # OTP behaviour.
    otp_length: int = 4
    otp_ttl_seconds: int = 600  # 10 minutes
    otp_max_attempts: int = 5

    # Dev convenience: when true, the generated code is returned in the API
    # response and logged, so you can test the whole flow without WhatsApp.
    # MUST be false in production.
    otp_debug_return_code: bool = True


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
