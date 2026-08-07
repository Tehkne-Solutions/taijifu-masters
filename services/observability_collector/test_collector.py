from fastapi.testclient import TestClient

from app import APP_SCHEMA, BATCH_SCHEMA, EVENT_SCHEMA, app

client = TestClient(app)


def _event(name: str = "runtime.started") -> dict:
    return {
        "schema": EVENT_SCHEMA,
        "version": 1,
        "event_id": "evt-1",
        "session_id": "session-1",
        "name": name,
        "severity": "info",
        "unix_ms": 1,
        "monotonic_ms": 1,
        "attributes": {},
        "build": {
            "build_sha": "abc123",
            "deploy_id": "deploy-42",
            "environment": "test",
            "release": "c57.2",
        },
    }


def test_health_contract():
    response = client.get("/health")
    assert response.status_code == 200
    payload = response.json()
    assert payload["schema"] == APP_SCHEMA
    assert payload["status"] == "ok"


def test_ingest_and_summary_correlate_build_and_deploy():
    response = client.post(
        "/v1/events",
        json={"schema": BATCH_SCHEMA, "sent_unix_ms": 1, "events": [_event()]},
    )
    assert response.status_code == 200
    assert response.json()["accepted"] == 1

    summary = client.get("/v1/summary").json()
    assert summary["builds"]["abc123"] >= 1
    assert summary["deploys"]["deploy-42"] >= 1
    assert summary["event_names"]["runtime.started"] >= 1


def test_rejects_wrong_batch_schema():
    response = client.post(
        "/v1/events",
        json={"schema": "invalid", "sent_unix_ms": 1, "events": [_event()]},
    )
    assert response.status_code == 422


def test_rejects_wrong_event_schema():
    invalid = _event()
    invalid["schema"] = "invalid"
    response = client.post(
        "/v1/events",
        json={"schema": BATCH_SCHEMA, "sent_unix_ms": 1, "events": [invalid]},
    )
    assert response.status_code == 422
