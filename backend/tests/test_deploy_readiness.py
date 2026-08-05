"""Deployment-readiness tests.

These guard the things that make a Railway boot fail: env parsing that raises
at startup, missing health endpoints, and the app crashing when optional
integrations (Supabase / WhatsApp) are unconfigured.
"""
from fastapi.testclient import TestClient

from app.core.config import Settings
from app.main import app

client = TestClient(app)


def test_root_is_liveness_ok():
    res = client.get("/")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert "version" in body


def test_health_ok_without_supabase_config():
    # Health must not depend on Supabase being configured.
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_cors_origins_accepts_star():
    assert Settings(cors_origins="*").cors_origins_list == ["*"]


def test_cors_origins_accepts_empty():
    assert Settings(cors_origins="").cors_origins_list == ["*"]


def test_cors_origins_accepts_comma_list():
    s = Settings(cors_origins="http://a.com, http://b.com")
    assert s.cors_origins_list == ["http://a.com", "http://b.com"]


def test_cors_origins_accepts_json_array():
    s = Settings(cors_origins='["http://a.com","http://b.com"]')
    assert s.cors_origins_list == ["http://a.com", "http://b.com"]


def test_cors_origins_accepts_python_list():
    # Passing a real list (in code/tests) must not raise.
    s = Settings(cors_origins=["http://x.com", "http://y.com"])
    assert s.cors_origins_list == ["http://x.com", "http://y.com"]


def test_cors_origins_malformed_json_falls_back():
    # A broken JSON array shouldn't crash — treat as a single origin.
    s = Settings(cors_origins="[not valid json")
    assert s.cors_origins_list == ["[not valid json"]


def test_app_boots_with_no_env(monkeypatch):
    # Simulate a bare platform environment: clear the integration vars and make
    # sure constructing the app doesn't raise.
    for var in (
        "SUPABASE_URL",
        "SUPABASE_SERVICE_ROLE_KEY",
        "WHATSAPP_BUSINESS_NUMBER",
        "CORS_ORIGINS",
    ):
        monkeypatch.delenv(var, raising=False)
    from app.main import create_app

    fresh = create_app()
    assert fresh.title
