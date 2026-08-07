from __future__ import annotations

import html
import json
import os
import threading
import time
from collections import Counter, deque
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from maintenance import deliver_alerts, enforce_retention

APP_SCHEMA = "tehkne/taijifu-observability-collector/v1"
BATCH_SCHEMA = "tehkne/taijifu-observability-batch/v1"
EVENT_SCHEMA = "tehkne/taijifu-observability/v1"
DATA_DIR = Path(os.getenv("TAIJIFU_OBSERVABILITY_DATA_DIR", "./data/observability"))
EVENT_LOG = DATA_DIR / "events.ndjson"
MAX_BATCH_EVENTS = int(os.getenv("TAIJIFU_OBSERVABILITY_MAX_BATCH", "256"))
RECENT_WINDOW = int(os.getenv("TAIJIFU_OBSERVABILITY_RECENT_WINDOW", "2000"))
PROJECT_KEY = os.getenv("TAIJIFU_OBSERVABILITY_PROJECT_KEY", "").strip()
ALERT_ERROR_THRESHOLD = int(os.getenv("TAIJIFU_ALERT_ERROR_THRESHOLD", "5"))
ALERT_FRAME_STALL_THRESHOLD = int(os.getenv("TAIJIFU_ALERT_FRAME_STALL_THRESHOLD", "8"))
ALERT_ASSET_FALLBACK_THRESHOLD = int(os.getenv("TAIJIFU_ALERT_ASSET_FALLBACK_THRESHOLD", "3"))
ALERT_HASH_MISMATCH_THRESHOLD = int(os.getenv("TAIJIFU_ALERT_HASH_MISMATCH_THRESHOLD", "1"))

app = FastAPI(title="Taijifu Observability Collector", version="1.2.0")
_lock = threading.Lock()
_recent: deque[dict[str, Any]] = deque(maxlen=RECENT_WINDOW)
_started_unix = int(time.time())
_ingested_events = 0
_rejected_batches = 0
_last_retention: dict[str, Any] = {"compacted": False, "lines_before": 0, "lines_after": 0}
_last_alert_delivery: dict[str, Any] = {"delivered": False, "reason": "not_attempted"}


class EventBatch(BaseModel):
    schema: str
    sent_unix_ms: int
    events: list[dict[str, Any]] = Field(default_factory=list)


def _authorized(request: Request) -> bool:
    if not PROJECT_KEY:
        return True
    return request.headers.get("X-Tehkne-Project-Key", "") == PROJECT_KEY


def _validate_event(event: dict[str, Any]) -> None:
    if event.get("schema") != EVENT_SCHEMA:
        raise HTTPException(status_code=422, detail="invalid_event_schema")
    if not str(event.get("event_id", "")).strip():
        raise HTTPException(status_code=422, detail="missing_event_id")
    if not str(event.get("session_id", "")).strip():
        raise HTTPException(status_code=422, detail="missing_session_id")
    if not str(event.get("name", "")).strip():
        raise HTTPException(status_code=422, detail="missing_event_name")


def _append_events(events: list[dict[str, Any]]) -> None:
    global _ingested_events, _last_retention
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with _lock:
        with EVENT_LOG.open("a", encoding="utf-8") as handle:
            for event in events:
                handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")
                _recent.append(event)
        _ingested_events += len(events)
        _last_retention = enforce_retention(EVENT_LOG)


def _summary_payload() -> dict[str, Any]:
    names = Counter(str(event.get("name", "unknown")) for event in _recent)
    severities = Counter(str(event.get("severity", "unknown")) for event in _recent)
    builds = Counter(str((event.get("build") or {}).get("build_sha", "unknown")) for event in _recent)
    deploys = Counter(str((event.get("build") or {}).get("deploy_id", "unknown")) for event in _recent)
    environments = Counter(str((event.get("build") or {}).get("environment", "unknown")) for event in _recent)
    return {
        "schema": APP_SCHEMA,
        "window_events": len(_recent),
        "event_names": dict(names.most_common(50)),
        "severities": dict(severities),
        "builds": dict(builds.most_common(20)),
        "deploys": dict(deploys.most_common(20)),
        "environments": dict(environments.most_common(20)),
        "ingested_events": _ingested_events,
        "rejected_batches": _rejected_batches,
    }


def _ops_payload() -> dict[str, Any]:
    summary_data = _summary_payload()
    names = summary_data["event_names"]
    severities = summary_data["severities"]
    errors = int(severities.get("error", 0))
    frame_stalls = int(names.get("performance.frame_stall", 0))
    fallbacks = int(names.get("asset.fallback_used", 0))
    hash_mismatches = int(names.get("asset.hash_mismatch", 0))
    assembler_failures = int(names.get("asset.assembler_failure", 0))
    alerts: list[dict[str, Any]] = []

    def add_alert(code: str, level: str, count: int, threshold: int) -> None:
        if count >= threshold:
            alerts.append({"code": code, "level": level, "count": count, "threshold": threshold})

    add_alert("error_rate", "critical", errors, ALERT_ERROR_THRESHOLD)
    add_alert("frame_stall_rate", "degraded", frame_stalls, ALERT_FRAME_STALL_THRESHOLD)
    add_alert("asset_fallback_rate", "degraded", fallbacks, ALERT_ASSET_FALLBACK_THRESHOLD)
    add_alert("asset_hash_mismatch", "critical", hash_mismatches, ALERT_HASH_MISMATCH_THRESHOLD)
    add_alert("asset_assembler_failure", "critical", assembler_failures, 1)

    status = "healthy"
    if any(alert["level"] == "critical" for alert in alerts):
        status = "critical"
    elif alerts:
        status = "degraded"

    return {
        "schema": APP_SCHEMA,
        "status": status,
        "alerts": alerts,
        "signals": {
            "errors": errors,
            "frame_stalls": frame_stalls,
            "asset_fallbacks": fallbacks,
            "asset_hash_mismatches": hash_mismatches,
            "asset_assembler_failures": assembler_failures,
        },
        "summary": summary_data,
        "retention": _last_retention,
        "alert_delivery": _last_alert_delivery,
        "generated_unix_ms": int(time.time() * 1000),
    }


@app.get("/health")
def health() -> dict[str, Any]:
    ops = _ops_payload()
    return {
        "schema": APP_SCHEMA,
        "status": "ok",
        "operational_status": ops["status"],
        "started_unix": _started_unix,
        "uptime_sec": max(0, int(time.time()) - _started_unix),
        "ingested_events": _ingested_events,
        "rejected_batches": _rejected_batches,
        "recent_window": len(_recent),
        "storage_path": str(EVENT_LOG),
        "active_alerts": len(ops["alerts"]),
        "retention": _last_retention,
    }


@app.post("/v1/events")
async def ingest(batch: EventBatch, request: Request) -> dict[str, Any]:
    global _rejected_batches, _last_alert_delivery
    if not _authorized(request):
        _rejected_batches += 1
        raise HTTPException(status_code=401, detail="unauthorized")
    if batch.schema != BATCH_SCHEMA:
        _rejected_batches += 1
        raise HTTPException(status_code=422, detail="invalid_batch_schema")
    if not batch.events or len(batch.events) > MAX_BATCH_EVENTS:
        _rejected_batches += 1
        raise HTTPException(status_code=422, detail="invalid_batch_size")
    for event in batch.events:
        _validate_event(event)
    _append_events(batch.events)
    ops = _ops_payload()
    _last_alert_delivery = deliver_alerts(ops)
    return {
        "ok": True,
        "accepted": len(batch.events),
        "collector_unix_ms": int(time.time() * 1000),
        "operational_status": ops["status"],
        "alert_delivery": _last_alert_delivery,
    }


@app.get("/v1/summary")
def summary() -> dict[str, Any]:
    return _summary_payload()


@app.get("/v1/ops")
def operations() -> dict[str, Any]:
    return _ops_payload()


@app.get("/dashboard", response_class=HTMLResponse)
def dashboard() -> str:
    ops = _ops_payload()
    alerts = ops["alerts"]
    rows = "".join(
        f"<tr><td>{html.escape(str(item['level']))}</td><td>{html.escape(str(item['code']))}</td><td>{item['count']}</td><td>{item['threshold']}</td></tr>"
        for item in alerts
    ) or "<tr><td colspan='4'>No active alerts</td></tr>"
    signals = "".join(
        f"<li><strong>{html.escape(str(key))}</strong>: {value}</li>"
        for key, value in ops["signals"].items()
    )
    status_label = html.escape(str(ops["status"]).upper())
    return f"""<!doctype html>
<html lang='en'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>Taijifu Operations</title><style>
body{{font-family:system-ui,sans-serif;margin:32px;max-width:1100px;background:#111;color:#eee}}
.card{{background:#1b1b1b;border:1px solid #333;border-radius:12px;padding:20px;margin:16px 0}}
table{{width:100%;border-collapse:collapse}}th,td{{padding:10px;border-bottom:1px solid #333;text-align:left}}
.status{{font-size:28px;font-weight:700;text-transform:uppercase}}
</style></head><body>
<h1>Taijifu Masters — Operations</h1><div class='card'><div class='status'>{status_label}</div>
<p>Events in window: {ops['summary']['window_events']}</p></div>
<div class='card'><h2>Signals</h2><ul>{signals}</ul></div>
<div class='card'><h2>Alerts</h2><table><thead><tr><th>Level</th><th>Code</th><th>Count</th><th>Threshold</th></tr></thead><tbody>{rows}</tbody></table></div>
<footer>Tehkné Solutions</footer></body></html>"""
