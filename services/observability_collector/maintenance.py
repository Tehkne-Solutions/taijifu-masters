from __future__ import annotations

import json
import os
import time
import urllib.request
from pathlib import Path
from typing import Any

RETENTION_MAX_BYTES = int(os.getenv("TAIJIFU_OBSERVABILITY_RETENTION_MAX_BYTES", str(64 * 1024 * 1024)))
RETENTION_MAX_LINES = int(os.getenv("TAIJIFU_OBSERVABILITY_RETENTION_MAX_LINES", "250000"))
RETENTION_KEEP_LINES = int(os.getenv("TAIJIFU_OBSERVABILITY_RETENTION_KEEP_LINES", "100000"))
ALERT_WEBHOOK_URL = os.getenv("TAIJIFU_ALERT_WEBHOOK_URL", "").strip()
ALERT_WEBHOOK_TOKEN = os.getenv("TAIJIFU_ALERT_WEBHOOK_TOKEN", "").strip()
ALERT_COOLDOWN_SEC = int(os.getenv("TAIJIFU_ALERT_COOLDOWN_SEC", "300"))

_last_alert_fingerprint = ""
_last_alert_unix = 0


def enforce_retention(event_log: Path) -> dict[str, Any]:
    if not event_log.exists():
        return {"compacted": False, "lines_before": 0, "lines_after": 0}
    size = event_log.stat().st_size
    with event_log.open("r", encoding="utf-8") as handle:
        lines = handle.readlines()
    line_count = len(lines)
    if size <= RETENTION_MAX_BYTES and line_count <= RETENTION_MAX_LINES:
        return {"compacted": False, "lines_before": line_count, "lines_after": line_count}
    keep = max(1, min(RETENTION_KEEP_LINES, line_count))
    retained = lines[-keep:]
    temp = event_log.with_suffix(".ndjson.tmp")
    with temp.open("w", encoding="utf-8") as handle:
        handle.writelines(retained)
    temp.replace(event_log)
    return {"compacted": True, "lines_before": line_count, "lines_after": len(retained)}


def _fingerprint(ops: dict[str, Any]) -> str:
    alerts = [
        {"code": item.get("code"), "level": item.get("level"), "count": item.get("count")}
        for item in ops.get("alerts", [])
    ]
    return json.dumps({"status": ops.get("status"), "alerts": alerts}, sort_keys=True, separators=(",", ":"))


def deliver_alerts(ops: dict[str, Any], now_unix: int | None = None) -> dict[str, Any]:
    global _last_alert_fingerprint, _last_alert_unix
    if not ALERT_WEBHOOK_URL or not ops.get("alerts"):
        return {"delivered": False, "reason": "disabled_or_empty"}
    now = int(time.time()) if now_unix is None else now_unix
    fingerprint = _fingerprint(ops)
    if fingerprint == _last_alert_fingerprint and now - _last_alert_unix < ALERT_COOLDOWN_SEC:
        return {"delivered": False, "reason": "cooldown"}
    payload = json.dumps({
        "schema": "tehkne/taijifu-observability-alert/v1",
        "status": ops.get("status"),
        "alerts": ops.get("alerts", []),
        "signals": ops.get("signals", {}),
        "generated_unix_ms": ops.get("generated_unix_ms"),
        "signature": "Tehkné Solutions",
    }, ensure_ascii=False).encode("utf-8")
    headers = {"Content-Type": "application/json", "User-Agent": "taijifu-observability/1"}
    if ALERT_WEBHOOK_TOKEN:
        headers["Authorization"] = f"Bearer {ALERT_WEBHOOK_TOKEN}"
    request = urllib.request.Request(ALERT_WEBHOOK_URL, data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            status = int(getattr(response, "status", 200))
        if 200 <= status < 300:
            _last_alert_fingerprint = fingerprint
            _last_alert_unix = now
            return {"delivered": True, "status": status}
        return {"delivered": False, "reason": f"http_{status}"}
    except Exception as exc:
        return {"delivered": False, "reason": exc.__class__.__name__}
