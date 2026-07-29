#!/usr/bin/env python3
"""Valida contratos JSON TGAP antes da execução dos gates técnicos."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

SCHEMA_FILES = {
    "manifest": "manifest.schema.json",
    "expected_assets": "expected-assets.schema.json",
    "runtime_manifest": "runtime-manifest.schema.json",
    "pipeline_report": "pipeline-report.schema.json",
}


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def format_error(error: Any) -> str:
    location = "/".join(str(part) for part in error.absolute_path) or "$"
    return f"{location}: {error.message}"


def validate_document(document: Path, schema: Path) -> list[str]:
    try:
        data = load_json(document)
    except Exception as exc:  # noqa: BLE001
        return [f"JSON inválido: {exc}"]
    validator = Draft202012Validator(load_json(schema))
    return [format_error(error) for error in sorted(validator.iter_errors(data), key=lambda item: list(item.absolute_path))]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("pack_root", type=Path)
    parser.add_argument("--include-pipeline-report", action="store_true")
    args = parser.parse_args()

    root = args.pack_root.resolve()
    repo = Path(__file__).resolve().parents[1]
    schemas = repo / "schemas" / "tgap"
    validation = root / "validation"
    validation.mkdir(parents=True, exist_ok=True)

    manifest_path = root / "manifest.json"
    expected_path = root / "expected-assets.json"
    checks: list[tuple[str, Path, str]] = [
        ("manifest", manifest_path, "manifest"),
        ("expected_assets", expected_path, "expected_assets"),
    ]

    runtime_path: Path | None = None
    try:
        manifest = load_json(manifest_path)
        runtime_config = manifest.get("runtime", {}) if isinstance(manifest, dict) else {}
        configured = runtime_config.get("manifest") if isinstance(runtime_config, dict) else None
        if configured:
            runtime_path = root / str(configured)
    except Exception:
        runtime_path = None
    if runtime_path is not None:
        checks.append(("runtime_manifest", runtime_path, "runtime_manifest"))
    if args.include_pipeline_report:
        checks.append(("pipeline_report", validation / "pipeline-report.json", "pipeline_report"))

    results: list[dict[str, Any]] = []
    all_errors: list[str] = []
    for name, document, schema_key in checks:
        errors = [f"arquivo ausente: {document}"] if not document.is_file() else validate_document(document, schemas / SCHEMA_FILES[schema_key])
        results.append({"name": name, "path": str(document), "passed": not errors, "errors": errors})
        all_errors.extend(f"{name}: {error}" for error in errors)

    passed = not all_errors
    report = {
        "tgap_version": "1.0",
        "gate": "contract",
        "contract_gate_passed": passed,
        "promotion_blocked": not passed,
        "documents_checked": len(results),
        "errors": all_errors,
        "results": results,
    }
    (validation / "contract-gate-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"contract_gate_passed": passed, "documents_checked": len(results), "errors": len(all_errors)}, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
