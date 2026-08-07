from fastapi.testclient import TestClient

from services.observability_collector import app as collector

client = TestClient(collector.app)


def _event(name: str, severity: str = "info", event_id: str = "evt"):
    return {
        "schema": collector.EVENT_SCHEMA,
        "version": 1,
        "event_id": event_id,
        "session_id": "session-1",
        "name": name,
        "severity": severity,
        "unix_ms": 1,
        "monotonic_ms": 1,
        "attributes": {},
        "build": {"build_sha": "abc", "deploy_id": "dep", "environment": "ci"},
    }


def _reset():
    collector._recent.clear()
    collector._ingested_events = 0
    collector._rejected_batches = 0


def test_ops_healthy_without_alerts():
    _reset()
    response = client.get("/v1/ops")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
    assert response.json()["alerts"] == []


def test_ops_degraded_on_frame_stalls():
    _reset()
    collector._recent.extend(
        _event("performance.frame_stall", event_id=f"stall-{index}")
        for index in range(collector.ALERT_FRAME_STALL_THRESHOLD)
    )
    payload = client.get("/v1/ops").json()
    assert payload["status"] == "degraded"
    assert any(item["code"] == "frame_stall_rate" for item in payload["alerts"])


def test_ops_critical_on_hash_mismatch():
    _reset()
    collector._recent.append(_event("asset.hash_mismatch", "error", "hash-1"))
    payload = client.get("/v1/ops").json()
    assert payload["status"] == "critical"
    assert any(item["code"] == "asset_hash_mismatch" for item in payload["alerts"])


def test_dashboard_renders_signature_and_status():
    _reset()
    response = client.get("/dashboard")
    assert response.status_code == 200
    assert "Taijifu Masters — Operations" in response.text
    assert "Tehkné Solutions" in response.text
    assert "HEALTHY" in response.text
