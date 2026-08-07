from __future__ import annotations

import json
import os
import threading
import time
from collections import Counter, deque
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field

APP_SCHEMA = "tehkne/taijifu-observability-collector/v1"
BATCH_SCHEMA = "tehkne/taijifu-observability-batch/v1"
EVENT_SCHEMA = "tehkne/taijifu-observability/v1"
DATA_DIR = Path(os.getenv("TAIJIFU_OBSERVABILITY_DATA_DIR", "./data/observability"))
EVENT_LOG = DATA_DIR / "events.ndjson"
MAX_BATCH_EVENTS = int(os.getenv("TAIJIFU_OBSERVABILITY_MAX_BATCH", "256"))
RECENT_WINDOW = int(os.getenv("TAIJIFU_OBSERVABILITY_RECENT_WINDOW", "2000"))
PROJECT_KEY = os.getenv("TAIJIFU_OBSERVABILITY_PROJECT_KEY", "").strip()

app = FastAPI(title="Taijifu Observability Collector", version="1.0.0")
_lock = threading.Lock()
_recent: deque[dict[str, Any]] = deque(maxlen=RECENT_WINDOW)
_started_unix = int(time.time())
_ingested_events = 0
_rejected_batches = 0


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
    global _ingested_events
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with _lock:
        with EVENT_LOG.open("a", encoding="utf-8") as handle:
            for event in events:
                handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")
                _recent.append(event)
        _ingested_events += len(events)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "schema": APP_SCHEMA,
        "status": "ok",
        "started_unix": _started_unix,
        "uptime_sec": max(0, int(time.time()) - _started_unix),
        "ingested_events": _ingested_events,
        "rejected_batches": _rejected_batches,
        "recent_window": len(_recent),
        "storage_path": str(EVENT_LOG),
    }


@app.post("/v1/events")
async def ingest(batch: EventBatch, request: Request) -> dict[str, Any]:
    global _rejected_batches
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
    return {
        "ok": True,
        "accepted": len(batch.events),
        "collector_unix_ms": int(time.time() * 1000),
    }


@app.get("/v1/summary")
def summary() -> dict[str, Any]:
    names = Counter(str(event.get("name", "unknown")) for event in _recent)
    severities = Counter(str(event.get("severity", "unknown")) for event in _recent)
    builds = Counter(
        str((event.get("build") or {}).get("build_sha", "unknown"))
        for event in _recent
    )
    deploys = Counter(
        str((event.get("build") or {}).get("deploy_id", "unknown"))
        for event in _recent
    )
    return {
        "schema": APP_SCHEMA,
        "window_events": len(_recent),
        "event_names": dict(names.most_common(50)),
        "severities": dict(severities),
        "builds": dict(builds.most_common(20)),
        "deploys": dict(deploys.most_common(20)),
        "ingested_events": _ingested_events,
        "rejected_batches": _rejected_batches,
    }
