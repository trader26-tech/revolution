"""Unit tests for the phone-verification helpers.

These cover the pure logic — code generation/extraction, phone normalisation,
and the WhatsApp deep link — without touching Supabase or the network.
"""
from urllib.parse import parse_qs, urlparse

import pytest

from app.core.config import settings
from app.schemas.phone_verification import StartVerificationRequest, _to_e164
from app.services import phone_verification as svc


def test_generate_code_has_configured_length():
    for _ in range(50):
        code = svc._generate_code()
        assert len(code) == settings.otp_length
        assert code.isdigit()
        assert not code.startswith("0")  # no leading-zero ambiguity


def test_hash_is_stable_and_not_plaintext():
    h1 = svc._hash_code("1234")
    h2 = svc._hash_code("1234")
    assert h1 == h2
    assert "1234" not in h1
    assert len(h1) == 64  # sha-256 hex


def test_extract_code_pulls_the_right_length_token():
    n = settings.otp_length
    good = "".join("7" for _ in range(n))
    assert svc._extract_code(f"Verify Revolution: {good}") == good
    # Ignores numbers of the wrong length.
    assert svc._extract_code("call me at 999") is None
    assert svc._extract_code("") is None


def test_whatsapp_link_targets_business_number_with_prefilled_text(monkeypatch):
    monkeypatch.setattr(settings, "whatsapp_business_number", "+1 (555) 123-4567")
    url, message = svc._build_whatsapp_link("4821")
    parsed = urlparse(url)
    assert parsed.netloc == "wa.me"
    # Digits only, no '+' or punctuation, in the path.
    assert parsed.path == "/15551234567"
    assert message == "Verify Revolution: 4821"
    assert parse_qs(parsed.query)["text"] == [message]


def test_inbound_number_gets_plus_prefix():
    # WhatsApp delivers the sender without a '+'.
    assert svc._to_e164("919876543210") == "+919876543210"
    assert svc._to_e164("+919876543210") == "+919876543210"


def test_schema_normalises_indian_number_to_e164():
    req = StartVerificationRequest(phone="98765 43210", region="IN")
    assert req.phone == "+919876543210"


def test_schema_rejects_garbage():
    with pytest.raises(ValueError):
        StartVerificationRequest(phone="not-a-number", region="IN")


def test_to_e164_respects_explicit_country_code():
    # Kuwait number typed with its code.
    assert _to_e164("+965 5000 0000", "KW").startswith("+965")
