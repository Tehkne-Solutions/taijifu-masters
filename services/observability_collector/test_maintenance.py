from __future__ import annotations

import json
from pathlib import Path

import maintenance


def test_retention_compacts_to_keep_lines(tmp_path: Path, monkeypatch):
    event_log = tmp_path / "events.ndjson"
    event_log.write_text("".join(json.dumps({"i": i}) + "\n" for i in range(10)), encoding="utf-8")
    monkeypatch.setattr(maintenance, "RETENTION_MAX_BYTES", 1)
    monkeypatch.setattr(maintenance, "RETENTION_MAX_LINES", 3)
    monkeypatch.setattr(maintenance, "RETENTION_KEEP_LINES", 4)
    result = maintenance.enforce_retention(event_log)
    assert result["compacted"] is True
    assert result["lines_before"] == 10
    assert result["lines_after"] == 4
    lines = event_log.read_text(encoding="utf-8").splitlines()
    assert [json.loads(line)["i"] for line in lines] == [6, 7, 8, 9]


def test_alert_delivery_disabled_without_webhook(monkeypatch):
    monkeypatch.setattr(maintenance, "ALERT_WEBHOOK_URL", "")
    result = maintenance.deliver_alerts({"status": "critical", "alerts": [{"code": "x"}]}, now_unix=100)
    assert result == {"delivered": False, "reason": "disabled_or_empty"}


def test_alert_delivery_respects_cooldown(monkeypatch):
    class FakeResponse:
        status = 204
        def __enter__(self):
            return self
        def __exit__(self, exc_type, exc, tb):
            return False

    monkeypatch.setattr(maintenance, "ALERT_WEBHOOK_URL", "https://example.invalid/hook")
    monkeypatch.setattr(maintenance, "ALERT_COOLDOWN_SEC", 300)
    monkeypatch.setattr(maintenance.urllib.request, "urlopen", lambda request, timeout=5: FakeResponse())
    maintenance._last_alert_fingerprint = ""
    maintenance._last_alert_unix = 0
    ops = {"status": "critical", "alerts": [{"code": "asset_hash_mismatch", "level": "critical", "count": 1}], "signals": {}}
    first = maintenance.deliver_alerts(ops, now_unix=1000)
    second = maintenance.deliver_alerts(ops, now_unix=1100)
    assert first["delivered"] is True
    assert second == {"delivered": False, "reason": "cooldown"}
