#!/usr/bin/env python3
"""Valida o registro global TGAP, dependências, versões e ordem de integração."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

VERSION_RE = re.compile(r"^(?P<op>>=|<=|>|<|=|~|\^)?(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)$")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def version_tuple(value: str) -> tuple[int, int, int]:
    base = value.split("-", 1)[0]
    return tuple(int(part) for part in base.split("."))  # type: ignore[return-value]


def satisfies(actual: str, constraint: str) -> bool:
    match = VERSION_RE.fullmatch(constraint)
    if not match:
        return False
    wanted = (int(match["major"]), int(match["minor"]), int(match["patch"]))
    current = version_tuple(actual)
    op = match["op"] or "="
    if op == "=": return current == wanted
    if op == ">=": return current >= wanted
    if op == "<=": return current <= wanted
    if op == ">": return current > wanted
    if op == "<": return current < wanted
    if op == "~": return current >= wanted and current[:2] == wanted[:2]
    if op == "^": return current >= wanted and current[0] == wanted[0]
    return False


def detect_cycle(graph: dict[str, list[str]]) -> list[str] | None:
    visiting: set[str] = set()
    visited: set[str] = set()
    trail: list[str] = []

    def walk(node: str) -> list[str] | None:
        if node in visiting:
            start = trail.index(node)
            return trail[start:] + [node]
        if node in visited:
            return None
        visiting.add(node)
        trail.append(node)
        for dependency in graph.get(node, []):
            cycle = walk(dependency)
            if cycle:
                return cycle
        trail.pop()
        visiting.remove(node)
        visited.add(node)
        return None

    for node in graph:
        cycle = walk(node)
        if cycle:
            return cycle
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--registry", type=Path, default=Path("tgap-registry.json"))
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    registry_path = args.registry if args.registry.is_absolute() else repo / args.registry
    schema_path = repo / "schemas/tgap/registry.schema.json"
    report_path = repo / "artifacts/tgap/registry-gate-report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)

    errors: list[str] = []
    try:
        registry = load_json(registry_path)
        schema = load_json(schema_path)
    except Exception as exc:
        registry = {}
        schema = {}
        errors.append(f"registry_load_error: {exc}")

    if not errors:
        validator = Draft202012Validator(schema)
        for error in sorted(validator.iter_errors(registry), key=lambda item: list(item.absolute_path)):
            location = "/".join(str(part) for part in error.absolute_path) or "$"
            errors.append(f"schema:{location}: {error.message}")

    packs = registry.get("packs", []) if isinstance(registry, dict) else []
    by_id: dict[str, dict[str, Any]] = {}
    orders: dict[int, str] = {}
    graph: dict[str, list[str]] = {}

    for entry in packs:
        pack_id = entry.get("pack_id")
        if pack_id in by_id:
            errors.append(f"duplicate_pack_id:{pack_id}")
            continue
        by_id[pack_id] = entry
        order = entry.get("integration_order")
        if order in orders:
            errors.append(f"duplicate_integration_order:{order}:{orders[order]}:{pack_id}")
        else:
            orders[order] = pack_id
        graph[pack_id] = [item["pack_id"] for item in entry.get("dependencies", []) if not item.get("optional", False)]

    for pack_id, entry in by_id.items():
        root = repo / entry["root"]
        manifest_path = root / "manifest.json"
        if not manifest_path.is_file():
            errors.append(f"manifest_missing:{pack_id}:{manifest_path}")
            continue
        try:
            manifest = load_json(manifest_path)
        except Exception as exc:
            errors.append(f"manifest_invalid:{pack_id}:{exc}")
            continue
        for field in ("pack_id", "version", "asset_class"):
            if manifest.get(field) != entry.get(field):
                errors.append(f"manifest_mismatch:{pack_id}:{field}:{manifest.get(field)}!={entry.get(field)}")
        if manifest.get("runtime_target") and manifest.get("runtime_target") != entry["compatibility"]["runtime"]:
            errors.append(f"runtime_mismatch:{pack_id}")
        if entry["compatibility"].get("project") and manifest.get("project_id") != entry["compatibility"]["project"]:
            errors.append(f"project_mismatch:{pack_id}")

        for dependency in entry.get("dependencies", []):
            dep_id = dependency["pack_id"]
            target = by_id.get(dep_id)
            if not target:
                if not dependency.get("optional", False):
                    errors.append(f"dependency_missing:{pack_id}:{dep_id}")
                continue
            if not satisfies(target["version"], dependency["version"]):
                errors.append(f"dependency_version_unsatisfied:{pack_id}:{dep_id}:{dependency['version']}:{target['version']}")
            if target["integration_order"] >= entry["integration_order"]:
                errors.append(f"dependency_order_invalid:{pack_id}:{dep_id}")

    cycle = detect_cycle(graph)
    if cycle:
        errors.append("dependency_cycle:" + "->".join(cycle))

    ordered = [pack_id for _, pack_id in sorted((entry["integration_order"], pack_id) for pack_id, entry in by_id.items() if entry.get("enabled", True))]
    report = {
        "tgap_version": "1.0",
        "gate": "registry",
        "registry": str(registry_path),
        "packs_registered": len(by_id),
        "integration_plan": ordered,
        "registry_gate_passed": not errors,
        "promotion_blocked": bool(errors),
        "errors": errors,
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"registry_gate_passed": not errors, "packs_registered": len(by_id), "errors": len(errors)}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
