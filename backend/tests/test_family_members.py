"""Tests for family member schemas and route wiring.

The service talks to Supabase, so these cover the schema validation and that the
routes are mounted — the parts we can check without a live database.
"""
from fastapi.testclient import TestClient

from app.main import app
from app.schemas.family_member import (
    COMMON_RELATIONS,
    FamilyMemberCreate,
    FamilyMemberUpdate,
)

client = TestClient(app)


def test_member_create_defaults_to_self_relation():
    m = FamilyMemberCreate(name="Priya")
    assert m.relation == "Self"
    assert m.is_self is False
    assert m.metadata == {}


def test_member_create_accepts_relation_and_self_flag():
    m = FamilyMemberCreate(name="Ravi", relation="Father", is_self=True)
    assert m.relation == "Father"
    assert m.is_self is True


def test_member_name_is_required_and_nonempty():
    import pytest
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        FamilyMemberCreate(name="")


def test_member_update_is_all_optional():
    patch = FamilyMemberUpdate()
    # Nothing set → empty patch (service treats this as a no-op).
    assert patch.model_dump(exclude_unset=True) == {}


def test_common_relations_include_the_expected_set():
    for r in ["Self", "Spouse", "Son", "Daughter", "Father", "Mother"]:
        assert r in COMMON_RELATIONS


def test_family_routes_are_mounted():
    paths = {getattr(r, "path", "") for r in app.routes}
    assert "/family/members" in paths
    assert "/family/members/{member_id}" in paths


def test_list_members_requires_owner_header():
    # Missing X-Owner-Id → 422 from FastAPI's required-header validation.
    res = client.get("/family/members")
    assert res.status_code == 422
