from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / "scripts" / "observability" / "observability_runtime.gd"
MATCH = ROOT / "scripts" / "telemetry" / "match_telemetry.gd"
EXPORTER = ROOT / "scripts" / "telemetry" / "playtest_report_exporter.gd"


def test_observability_runtime_contract():
    text = RUNTIME.read_text(encoding="utf-8")
    required = [
        'tehkne/taijifu-observability/v1',
        'user://observability/pending.ndjson',
        'func record_event(',
        'func record_error(',
        'func record_metric(',
        'func record_timing(',
        'func record_match_snapshot(',
        'func health_snapshot(',
        'func flush(',
        'MAX_QUEUE := 2048',
        'MAX_ATTEMPTS := 6',
        'HTTPRequest.new()',
    ]
    for token in required:
        assert token in text, token


def test_sensitive_attribute_guard_exists():
    text = RUNTIME.read_text(encoding="utf-8")
    for key in ["email", "password", "token", "authorization", "secret"]:
        assert f'"{key}"' in text


def test_existing_match_telemetry_is_preserved():
    text = MATCH.read_text(encoding="utf-8")
    assert 'tehkne/taijifu-match-telemetry/v4' in text
    assert 'func session_snapshot()' in text
    assert 'func record_combat_metric(' in text


def test_playtest_exporter_keeps_local_fallback():
    text = EXPORTER.read_text(encoding="utf-8")
    assert 'automatic_upload": false' in text
    assert 'browser_download' in text
    assert 'native_reveal' in text
