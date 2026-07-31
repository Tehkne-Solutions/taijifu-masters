#!/usr/bin/env python3
"""Operate the Taijifu Masters First Playable external pilot.

This standard-library-only CLI creates anonymous pilot plans, validates incoming
telemetry batches without modifying source files, and converts quantitative plus
qualitative evidence into a prioritized P0-P3 backlog.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SIGNATURE = "Tehkné Solutions"
BUILD_VERSION = "0.2.1-playtest"
TELEMETRY_SCHEMA = "tehkne/taijifu-match-telemetry/v3"
SUMMARY_SCHEMA = "tehkne/taijifu-first-playable-summary/v1"
PLAN_SCHEMA = "tehkne/taijifu-first-playable-pilot-plan/v1"
INTAKE_SCHEMA = "tehkne/taijifu-first-playable-pilot-intake/v1"
OBSERVATIONS_SCHEMA = "tehkne/taijifu-first-playable-observations/v1"
BACKLOG_SCHEMA = "tehkne/taijifu-first-playable-backlog/v1"
DECISIONS_SCHEMA = "tehkne/taijifu-first-playable-decisions/v1"

DIFFICULTIES = ("apprentice", "disciple", "master")
DIFFICULTY_LABELS = {
    "apprentice": "Aprendiz",
    "disciple": "Discípulo",
    "master": "Mestre",
}
PLATFORMS = ("windows", "web")
PARTICIPANT_PATTERN = re.compile(r"(?<![A-Z0-9])TJFP-\d{3}(?!\d)", re.IGNORECASE)
EMAIL_PATTERN = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
IPV4_PATTERN = re.compile(
    r"\b(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)\b"
)
PHONE_PATTERN = re.compile(r"(?<!\d)(?:\+?55\s*)?(?:\(?\d{2}\)?[\s.-]*)?\d{4,5}[\s.-]?\d{4}(?!\d)")
FORBIDDEN_KEY_FRAGMENTS = {
    "name", "nome", "email", "e_mail", "phone", "telefone", "celular",
    "address", "endereco", "cpf", "cnpj", "ip_address", "password", "senha",
    "token", "credential", "secret",
}
SAFE_VALUE_KEYS = {
    "session_id", "build_id", "git_sha", "sha256", "event_id", "value_id",
    "participant_id", "pilot_id", "schema", "source_schema", "signature",
}
ALLOWED_METADATA_KEYS = {
    "build_version", "platform", "locale", "privacy", "signature",
    "experience", "difficulty_id", "difficulty_label", "time_limit_seconds",
    "player_character", "cpu_character", "arena", "match_generation",
    "result_reason", "player_won", "elapsed_seconds", "balance_feedback",
    "balance_feedback_unix", "rematch_requested", "rematch_requested_unix",
    "abandoned", "final_state", "pause_count",
}
BLOCKING_CATEGORIES = {"crash", "soft_lock", "data_loss", "cannot_start", "telemetry_loss"}
PRIORITY_ORDER = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
SEVERITY_TO_PRIORITY = {
    "blocker": "P0", "critical": "P0", "major": "P1", "high": "P1",
    "minor": "P2", "medium": "P2", "polish": "P3", "low": "P3",
}
RESOLVED_DECISION_STATUSES = {"fixed", "not_reproducible"}
DECIDED_STATUSES = {"accepted", "in_progress", "fixed", "deferred", "not_reproducible", "wont_fix"}
QUALITY_SIGNAL_PRIORITY = {
    "abandonment_high": "P1",
    "apprentice_too_hard": "P1",
    "apprentice_win_rate_low": "P2",
    "master_too_easy": "P2",
    "master_win_rate_high": "P2",
    "feedback_coverage_low": "P2",
    "sample_size_low": "P2",
    "no_blocking_signal": "P3",
}


def now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{path}: a raiz JSON deve ser um objeto")
    return payload


def participant_id(index: int) -> str:
    return f"TJFP-{index:03d}"


def participant_ids_from_plan(plan: dict[str, Any]) -> set[str]:
    result: set[str] = set()
    for item in plan.get("participants", []):
        if isinstance(item, dict):
            value = str(item.get("participant_id", "")).upper()
            if PARTICIPANT_PATTERN.fullmatch(value):
                result.add(value)
    return result


def difficulty_sequences() -> tuple[tuple[str, ...], ...]:
    return (
        ("apprentice", "disciple", "master"),
        ("disciple", "master", "apprentice"),
        ("master", "apprentice", "disciple"),
        ("apprentice", "master", "disciple"),
        ("master", "disciple", "apprentice"),
        ("disciple", "apprentice", "master"),
    )


def build_plan(
    pilot_id: str,
    participants: int,
    windows_share: float = 2 / 3,
    matches_per_difficulty: int = 2,
) -> dict[str, Any]:
    if not 6 <= participants <= 50:
        raise ValueError("participants deve estar entre 6 e 50")
    if not 0.0 <= windows_share <= 1.0:
        raise ValueError("windows_share deve estar entre 0 e 1")
    if not 1 <= matches_per_difficulty <= 10:
        raise ValueError("matches_per_difficulty deve estar entre 1 e 10")
    pilot_id = pilot_id.strip()
    if not pilot_id:
        raise ValueError("pilot_id não pode ser vazio")

    windows_target = min(participants, max(0, round(participants * windows_share)))
    counters = Counter({"windows": windows_target, "web": participants - windows_target})
    platform_schedule: list[str] = []
    for index in range(participants):
        ideal_windows = round((index + 1) * windows_target / participants)
        if platform_schedule.count("windows") < ideal_windows and counters["windows"] > 0:
            selected = "windows"
        elif counters["web"] > 0:
            selected = "web"
        else:
            selected = "windows"
        platform_schedule.append(selected)
        counters[selected] -= 1

    sequences = difficulty_sequences()
    roster: list[dict[str, Any]] = []
    for index in range(participants):
        sequence = sequences[index % len(sequences)]
        code = participant_id(index + 1)
        roster.append({
            "participant_id": code,
            "platform": platform_schedule[index],
            "difficulty_sequence": list(sequence),
            "matches_per_difficulty": matches_per_difficulty,
            "expected_matches": matches_per_difficulty * len(DIFFICULTIES),
            "required_checks": [
                "first_attempt_without_coaching",
                "movement_jump_attack_defense_dodge_push_grab",
                "pause_and_resume",
                "submit_balance_feedback_each_match",
                "copy_or_export_local_json",
            ],
            "report_filename_prefix": f"{code}__",
        })

    starts = Counter(item["difficulty_sequence"][0] for item in roster)
    platform_counts = Counter(item["platform"] for item in roster)
    return {
        "schema": PLAN_SCHEMA,
        "generated_at_utc": now_utc(),
        "signature": SIGNATURE,
        "pilot_id": pilot_id,
        "build_version": BUILD_VERSION,
        "privacy": "anonymous_codes_only",
        "participant_count": participants,
        "matches_per_difficulty": matches_per_difficulty,
        "expected_total_matches": participants * matches_per_difficulty * len(DIFFICULTIES),
        "platform_targets": dict(sorted(platform_counts.items())),
        "starting_difficulty_distribution": dict(sorted(starts.items())),
        "participants": roster,
        "completion_gate": {
            "minimum_valid_participants": 6,
            "minimum_completed_rounds": 24,
            "minimum_rounds_per_difficulty": 6,
            "minimum_feedback_coverage": 0.70,
            "open_p0_allowed": 0,
            "all_p1_require_decision": True,
        },
    }


def render_plan_markdown(plan: dict[str, Any]) -> str:
    lines = [
        "# Taijifu Masters — Plano do piloto externo", "",
        f"- Piloto: `{plan['pilot_id']}`", f"- Build: `{plan['build_version']}`",
        f"- Participantes anônimos: **{plan['participant_count']}**",
        f"- Partidas previstas: **{plan['expected_total_matches']}**",
        "- Privacidade: códigos anônimos; não registrar nome, e-mail, telefone ou IP.", "",
        "## Distribuição", "", "| Código | Plataforma | Ordem das dificuldades | Partidas |",
        "|---|---|---|---:|",
    ]
    for item in plan["participants"]:
        sequence = " → ".join(DIFFICULTY_LABELS[value] for value in item["difficulty_sequence"])
        lines.append(f"| {item['participant_id']} | {item['platform'].title()} | {sequence} | {item['expected_matches']} |")
    lines += [
        "", "## Entrega de cada participante", "",
        "1. Executar o kit `0.2.1-playtest` na plataforma atribuída.",
        "2. Seguir a ordem das dificuldades da tabela.",
        "3. Responder à avaliação de equilíbrio após cada partida.",
        "4. Copiar/exportar o JSON local.",
        "5. Renomear o arquivo com o prefixo do código, por exemplo `TJFP-001__taijifu_...json`.",
        "6. Registrar bugs sem inserir dados pessoais.", "", "## Gate da rodada", "",
        "- mínimo de 6 participantes válidos;", "- mínimo de 24 partidas concluídas;",
        "- mínimo de 6 partidas por dificuldade;", "- cobertura de feedback de 70% ou mais;",
        "- nenhum P0 aberto;", "- decisão documentada para todos os P1.", "",
        "Assinatura: Tehkné Solutions", "",
    ]
    return "\n".join(lines)


def write_plan_outputs(plan: dict[str, Any], output_dir: Path) -> dict[str, str]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / "pilot-plan.json"
    csv_path = output_dir / "pilot-roster.csv"
    markdown_path = output_dir / "pilot-plan.md"
    observations_path = output_dir / "pilot-observations.json"
    decisions_path = output_dir / "pilot-decisions.json"
    write_json(json_path, plan)
    with csv_path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["participant_id", "platform", "difficulty_1", "difficulty_2", "difficulty_3", "matches_per_difficulty", "expected_matches", "report_filename_prefix"])
        for item in plan["participants"]:
            writer.writerow([item["participant_id"], item["platform"], *item["difficulty_sequence"], item["matches_per_difficulty"], item["expected_matches"], item["report_filename_prefix"]])
    markdown_path.write_text(render_plan_markdown(plan), encoding="utf-8")
    write_json(observations_path, {"schema": OBSERVATIONS_SCHEMA, "pilot_id": plan["pilot_id"], "build_version": plan["build_version"], "signature": SIGNATURE, "observations": []})
    write_json(decisions_path, {"schema": DECISIONS_SCHEMA, "pilot_id": plan["pilot_id"], "build_version": plan["build_version"], "signature": SIGNATURE, "decisions": []})
    return {"json": str(json_path), "csv": str(csv_path), "markdown": str(markdown_path), "observations": str(observations_path), "decisions": str(decisions_path)}


def discover_json_files(inputs: Iterable[Path]) -> list[Path]:
    files: set[Path] = set()
    for raw in inputs:
        path = raw.expanduser()
        if not path.exists():
            continue
        if path.is_file() and path.suffix.lower() == ".json":
            files.add(path.resolve())
        elif path.is_dir():
            for candidate in path.rglob("*.json"):
                if candidate.is_file():
                    files.add(candidate.resolve())
    return sorted(files)


def find_participant_in_filename(path: Path) -> str | None:
    match = PARTICIPANT_PATTERN.search(path.name)
    return match.group(0).upper() if match else None


def detect_pii(payload: Any, location: str = "$") -> list[str]:
    findings: list[str] = []
    if isinstance(payload, dict):
        for raw_key, value in payload.items():
            key = str(raw_key)
            normalized = key.lower().replace("-", "_").replace(" ", "_")
            if normalized not in ALLOWED_METADATA_KEYS and any(fragment == normalized or fragment in normalized for fragment in FORBIDDEN_KEY_FRAGMENTS):
                findings.append(f"{location}.{key}: chave potencialmente sensível")
            if normalized not in SAFE_VALUE_KEYS:
                findings.extend(detect_pii(value, f"{location}.{key}"))
    elif isinstance(payload, list):
        for index, value in enumerate(payload):
            findings.extend(detect_pii(value, f"{location}[{index}]"))
    elif isinstance(payload, str):
        if EMAIL_PATTERN.search(payload): findings.append(f"{location}: possível e-mail")
        if IPV4_PATTERN.search(payload): findings.append(f"{location}: possível endereço IP")
        if PHONE_PATTERN.search(payload): findings.append(f"{location}: possível telefone")
    return sorted(set(findings))


def validate_telemetry_session(payload: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if payload.get("schema") != TELEMETRY_SCHEMA: errors.append(f"schema incompatível: {payload.get('schema', 'ausente')}")
    if not str(payload.get("session_id", "")).strip(): errors.append("session_id ausente")
    if not isinstance(payload.get("rounds"), list): errors.append("rounds deve ser uma lista")
    metadata = payload.get("metadata", {})
    if not isinstance(metadata, dict):
        errors.append("metadata deve ser um objeto")
    else:
        build_version = str(metadata.get("build_version", ""))
        if build_version and build_version != BUILD_VERSION: errors.append(f"build_version inesperada: {build_version}")
        privacy = str(metadata.get("privacy", ""))
        if privacy and privacy != "local_only": errors.append(f"privacy inesperada: {privacy}")
    return errors


def build_intake_manifest(inputs: Iterable[Path], plan: dict[str, Any]) -> dict[str, Any]:
    expected_ids = participant_ids_from_plan(plan)
    files = discover_json_files(inputs)
    accepted: list[dict[str, Any]] = []
    rejected: list[dict[str, Any]] = []
    warnings: list[str] = []
    seen_sessions: dict[str, str] = {}
    seen_hashes: dict[str, str] = {}
    participant_sessions: Counter[str] = Counter()
    for path in files:
        entry: dict[str, Any] = {"source_path": str(path), "source_name": path.name, "participant_id": find_participant_in_filename(path), "size_bytes": path.stat().st_size, "sha256": sha256(path), "errors": [], "warnings": []}
        participant = entry["participant_id"]
        if participant is None: entry["errors"].append("código TJFP-### ausente no nome do arquivo")
        elif participant not in expected_ids: entry["errors"].append(f"participante não pertence ao plano: {participant}")
        try:
            payload = read_json(path)
        except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
            entry["errors"].append(f"JSON ilegível: {error}")
            rejected.append(entry)
            continue
        entry["errors"].extend(validate_telemetry_session(payload))
        pii = detect_pii(payload)
        if pii:
            entry["errors"].append("possível PII detectada")
            entry["pii_findings"] = pii
        session_id = str(payload.get("session_id", "")).strip()
        entry["session_id"] = session_id
        entry["round_count"] = len(payload.get("rounds", [])) if isinstance(payload.get("rounds"), list) else 0
        entry["build_version"] = str(payload.get("metadata", {}).get("build_version", "")) if isinstance(payload.get("metadata"), dict) else ""
        digest = entry["sha256"]
        if digest in seen_hashes: entry["errors"].append(f"arquivo duplicado de {seen_hashes[digest]}")
        else: seen_hashes[digest] = path.name
        if session_id:
            if session_id in seen_sessions: entry["errors"].append(f"session_id duplicado de {seen_sessions[session_id]}")
            else: seen_sessions[session_id] = path.name
        if entry["errors"]: rejected.append(entry)
        else:
            accepted.append(entry)
            participant_sessions[participant] += 1
    missing_participants = sorted(expected_ids - set(participant_sessions))
    if missing_participants: warnings.append("Participantes sem sessão aceita: " + ", ".join(missing_participants))
    return {
        "schema": INTAKE_SCHEMA, "generated_at_utc": now_utc(), "signature": SIGNATURE,
        "pilot_id": plan.get("pilot_id", "unknown"), "build_version": plan.get("build_version", BUILD_VERSION),
        "privacy": "source_files_unchanged_manifest_only",
        "inputs": {"candidate_files": len(files), "accepted_files": len(accepted), "rejected_files": len(rejected), "expected_participants": len(expected_ids), "participants_with_accepted_sessions": len(participant_sessions)},
        "participant_session_counts": dict(sorted(participant_sessions.items())), "missing_participants": missing_participants,
        "accepted": accepted, "rejected": rejected, "warnings": warnings,
    }


def render_intake_markdown(manifest: dict[str, Any]) -> str:
    inputs = manifest["inputs"]
    lines = ["# Taijifu Masters — Intake do piloto", "", f"- Piloto: `{manifest['pilot_id']}`", f"- Arquivos candidatos: **{inputs['candidate_files']}**", f"- Aceitos: **{inputs['accepted_files']}**", f"- Rejeitados: **{inputs['rejected_files']}**", f"- Participantes recebidos: **{inputs['participants_with_accepted_sessions']} / {inputs['expected_participants']}**", ""]
    if manifest["rejected"]:
        lines += ["## Rejeições", "", "| Arquivo | Participante | Motivos |", "|---|---|---|"]
        for entry in manifest["rejected"]: lines.append(f"| {entry['source_name']} | {entry.get('participant_id') or 'ausente'} | {'; '.join(entry['errors'])} |")
        lines.append("")
    if manifest["missing_participants"]: lines += ["## Participantes pendentes", "", ", ".join(manifest["missing_participants"]), ""]
    lines += ["Assinatura: Tehkné Solutions", ""]
    return "\n".join(lines)


def normalized_text(value: Any) -> str:
    return " ".join(str(value or "").strip().lower().split())


def validate_observation(item: dict[str, Any], expected_ids: set[str]) -> list[str]:
    errors: list[str] = []
    participant = str(item.get("participant_id", "")).upper()
    if participant not in expected_ids: errors.append("participant_id inválido ou fora do plano")
    if not normalized_text(item.get("title")): errors.append("title ausente")
    if not normalized_text(item.get("category")): errors.append("category ausente")
    if not normalized_text(item.get("description")): errors.append("description ausente")
    severity = normalized_text(item.get("severity", "minor"))
    if severity not in SEVERITY_TO_PRIORITY: errors.append(f"severity inválida: {severity}")
    platform = normalized_text(item.get("platform"))
    if platform and platform not in PLATFORMS: errors.append(f"platform inválida: {platform}")
    difficulty = normalized_text(item.get("difficulty"))
    if difficulty and difficulty not in DIFFICULTIES: errors.append(f"difficulty inválida: {difficulty}")
    if detect_pii(item): errors.append("possível PII detectada")
    return errors


def observation_priority(item: dict[str, Any]) -> str:
    category = normalized_text(item.get("category")).replace(" ", "_")
    if category in BLOCKING_CATEGORIES: return "P0"
    return SEVERITY_TO_PRIORITY.get(normalized_text(item.get("severity", "minor")), "P2")


def quality_signal_item(signal: dict[str, Any]) -> dict[str, Any]:
    signal_id = str(signal.get("id", "unknown"))
    severity = normalized_text(signal.get("severity", "info"))
    priority = QUALITY_SIGNAL_PRIORITY.get(signal_id, "P1" if severity == "critical" else "P2" if severity == "warning" else "P3")
    return {"id": f"signal:{signal_id}", "priority": priority, "source": "quantitative_signal", "category": "balance_or_quality", "title": signal_id.replace("_", " ").title(), "description": str(signal.get("message", "")), "occurrences": 1, "participants": [], "platforms": [], "difficulties": [], "decision_required": priority in {"P0", "P1"}}


def observation_key(item: dict[str, Any]) -> tuple[str, str]:
    return normalized_text(item.get("category")).replace(" ", "_"), normalized_text(item.get("title"))


def load_decision_map(payload: dict[str, Any]) -> tuple[dict[str, dict[str, Any]], list[str]]:
    if payload.get("schema") != DECISIONS_SCHEMA: raise ValueError("Arquivo de decisões possui schema incompatível")
    result: dict[str, dict[str, Any]] = {}
    warnings: list[str] = []
    decisions = payload.get("decisions", [])
    if not isinstance(decisions, list): raise ValueError("decisions deve ser uma lista")
    for index, raw in enumerate(decisions):
        if not isinstance(raw, dict): warnings.append(f"decisão {index}: deve ser objeto"); continue
        item_id = str(raw.get("backlog_item_id", "")).strip()
        status = normalized_text(raw.get("status"))
        rationale = str(raw.get("rationale", "")).strip()
        if not item_id: warnings.append(f"decisão {index}: backlog_item_id ausente"); continue
        if status not in DECIDED_STATUSES: warnings.append(f"decisão {index}: status inválido ({status or 'ausente'})"); continue
        if not rationale: warnings.append(f"decisão {index}: rationale ausente"); continue
        if item_id in result: warnings.append(f"decisão duplicada para {item_id}; última entrada prevalece")
        result[item_id] = {"status": status, "rationale": rationale, "target_version": str(raw.get("target_version", "")).strip(), "owner_role": str(raw.get("owner_role", "")).strip()}
    return result, warnings


def build_backlog(summary: dict[str, Any], observations_payload: dict[str, Any], plan: dict[str, Any], intake: dict[str, Any], decisions_payload: dict[str, Any]) -> dict[str, Any]:
    if summary.get("schema") != SUMMARY_SCHEMA: raise ValueError("Resumo quantitativo possui schema incompatível")
    if observations_payload.get("schema") != OBSERVATIONS_SCHEMA: raise ValueError("Arquivo de observações possui schema incompatível")
    if intake.get("schema") != INTAKE_SCHEMA: raise ValueError("Manifesto de intake possui schema incompatível")
    decision_map, decision_warnings = load_decision_map(decisions_payload)
    expected_ids = participant_ids_from_plan(plan)
    valid_observations: list[dict[str, Any]] = []
    rejected_observations: list[dict[str, Any]] = []
    for index, raw in enumerate(observations_payload.get("observations", [])):
        if not isinstance(raw, dict): rejected_observations.append({"index": index, "errors": ["observação deve ser objeto"]}); continue
        errors = validate_observation(raw, expected_ids)
        if errors: rejected_observations.append({"index": index, "errors": errors, "observation": raw})
        else: valid_observations.append(raw)
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for item in valid_observations: grouped[observation_key(item)].append(item)
    backlog_items: list[dict[str, Any]] = []
    for (category, title), items in grouped.items():
        priorities = [observation_priority(item) for item in items]
        priority = min(priorities, key=lambda value: PRIORITY_ORDER[value])
        participants = sorted({str(item.get("participant_id", "")).upper() for item in items})
        platforms = sorted({normalized_text(item.get("platform")) for item in items if item.get("platform")})
        difficulties = sorted({normalized_text(item.get("difficulty")) for item in items if item.get("difficulty")})
        descriptions = [str(item.get("description", "")).strip() for item in items]
        reproduction = [str(item.get("reproduction", "")).strip() for item in items if str(item.get("reproduction", "")).strip()]
        backlog_items.append({"id": f"observation:{category}:{hashlib.sha256(title.encode('utf-8')).hexdigest()[:10]}", "priority": priority, "source": "qualitative_observation", "category": category, "title": str(items[0].get("title", "")).strip(), "description": descriptions[0], "additional_descriptions": sorted(set(descriptions[1:])), "reproduction": reproduction[0] if reproduction else "", "occurrences": len(items), "participants": participants, "platforms": platforms, "difficulties": difficulties, "decision_required": priority in {"P0", "P1"}})
    for signal in summary.get("quality_signals", []):
        if isinstance(signal, dict): backlog_items.append(quality_signal_item(signal))
    known_item_ids = {item["id"] for item in backlog_items}
    unknown_decision_ids = sorted(set(decision_map) - known_item_ids)
    for item in backlog_items:
        decision = decision_map.get(item["id"])
        item["decision"] = decision
        item["decision_status"] = decision["status"] if decision else "open"
        item["resolved"] = bool(decision and decision["status"] in RESOLVED_DECISION_STATUSES)
    backlog_items.sort(key=lambda item: (PRIORITY_ORDER[item["priority"]], -int(item.get("occurrences", 1)), normalized_text(item.get("title"))))
    counts = Counter(item["priority"] for item in backlog_items)
    gates = plan.get("completion_gate", {})
    totals = summary.get("totals", {})
    by_difficulty = summary.get("by_difficulty", {})
    intake_counts = intake.get("participant_session_counts", {})
    if not isinstance(intake_counts, dict): intake_counts = {}
    valid_participants = sum(1 for participant, count in intake_counts.items() if str(participant).upper() in expected_ids and int(count) > 0)
    minimum_rounds_each = min((int(by_difficulty.get(difficulty, {}).get("rounds", 0)) for difficulty in DIFFICULTIES), default=0)
    open_p0 = sum(1 for item in backlog_items if item["priority"] == "P0" and not item["resolved"])
    p1_without_decision = sum(1 for item in backlog_items if item["priority"] == "P1" and item["decision_status"] == "open")
    gate_checks = {
        "minimum_valid_participants": {"required": int(gates.get("minimum_valid_participants", 6)), "actual": valid_participants, "passed": valid_participants >= int(gates.get("minimum_valid_participants", 6))},
        "minimum_completed_rounds": {"required": int(gates.get("minimum_completed_rounds", 24)), "actual": int(totals.get("completed_rounds", 0)), "passed": int(totals.get("completed_rounds", 0)) >= int(gates.get("minimum_completed_rounds", 24))},
        "minimum_rounds_per_difficulty": {"required": int(gates.get("minimum_rounds_per_difficulty", 6)), "actual": minimum_rounds_each, "passed": minimum_rounds_each >= int(gates.get("minimum_rounds_per_difficulty", 6))},
        "minimum_feedback_coverage": {"required": float(gates.get("minimum_feedback_coverage", 0.70)), "actual": float(totals.get("feedback_coverage", 0.0)), "passed": float(totals.get("feedback_coverage", 0.0)) >= float(gates.get("minimum_feedback_coverage", 0.70))},
        "open_p0_allowed": {"required": int(gates.get("open_p0_allowed", 0)), "actual": open_p0, "passed": open_p0 <= int(gates.get("open_p0_allowed", 0))},
        "p1_without_decision": {"required": 0, "actual": p1_without_decision, "passed": p1_without_decision == 0},
    }
    return {
        "schema": BACKLOG_SCHEMA, "generated_at_utc": now_utc(), "signature": SIGNATURE,
        "pilot_id": plan.get("pilot_id", "unknown"), "build_version": plan.get("build_version", BUILD_VERSION),
        "privacy": "anonymous_evidence_only", "summary_source_schema": summary.get("schema"),
        "counts": {priority: counts.get(priority, 0) for priority in PRIORITY_ORDER},
        "valid_observations": len(valid_observations), "rejected_observations": rejected_observations,
        "decision_warnings": decision_warnings, "unknown_decision_ids": unknown_decision_ids,
        "items": backlog_items,
        "completion_gate": {"passed": all(check["passed"] for check in gate_checks.values()), "checks": gate_checks, "note": "P1 exige decisão registrada antes de encerrar a rodada."},
    }


def render_backlog_markdown(backlog: dict[str, Any]) -> str:
    lines = ["# Taijifu Masters — Backlog do piloto", "", f"- Piloto: `{backlog['pilot_id']}`", f"- Build: `{backlog['build_version']}`", f"- Gate quantitativo: **{'APROVADO' if backlog['completion_gate']['passed'] else 'PENDENTE'}**", "", "## Gate de conclusão", "", "| Critério | Atual | Necessário | Estado |", "|---|---:|---:|---|"]
    for name, check in backlog["completion_gate"]["checks"].items(): lines.append(f"| {name.replace('_', ' ')} | {check['actual']} | {check['required']} | {'OK' if check['passed'] else 'PENDENTE'} |")
    for priority in ("P0", "P1", "P2", "P3"):
        items = [item for item in backlog["items"] if item["priority"] == priority]
        lines += ["", f"## {priority} — {len(items)} item(ns)", ""]
        if not items: lines.append("Nenhum item."); continue
        for item in items:
            evidence = []
            if item.get("occurrences", 1) > 1: evidence.append(f"{item['occurrences']} ocorrências")
            if item.get("participants"): evidence.append("participantes " + ", ".join(item["participants"]))
            if item.get("platforms"): evidence.append("plataformas " + ", ".join(item["platforms"]))
            if item.get("difficulties"): evidence.append("dificuldades " + ", ".join(item["difficulties"]))
            lines += [f"### {item['title']}", "", f"- Categoria: `{item['category']}`", f"- Fonte: `{item['source']}`", f"- Decisão obrigatória: **{'sim' if item['decision_required'] else 'não'}**", f"- Status da decisão: `{item['decision_status']}`", f"- Evidência: {('; '.join(evidence) if evidence else 'sinal consolidado')}", "", item["description"] or "Sem descrição.", ""]
            if item.get("reproduction"): lines += ["**Reprodução:**", "", item["reproduction"], ""]
    if backlog["rejected_observations"]: lines += ["## Observações rejeitadas", "", f"{len(backlog['rejected_observations'])} observação(ões) precisa(m) ser corrigida(s) antes da consolidação final.", ""]
    lines += ["Assinatura: Tehkné Solutions", ""]
    return "\n".join(lines)


def load_plan(path: Path) -> dict[str, Any]:
    plan = read_json(path)
    if plan.get("schema") != PLAN_SCHEMA: raise ValueError(f"{path}: schema de plano incompatível")
    return plan


def command_plan(args: argparse.Namespace) -> int:
    plan = build_plan(args.pilot_id, args.participants, args.windows_share, args.matches_per_difficulty)
    outputs = write_plan_outputs(plan, args.output_dir)
    print(json.dumps({"pilot_id": plan["pilot_id"], "outputs": outputs}, indent=2, ensure_ascii=False))
    return 0


def command_intake(args: argparse.Namespace) -> int:
    plan = load_plan(args.plan)
    manifest = build_intake_manifest(args.inputs, plan)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "pilot-intake-manifest.json"
    markdown_path = args.output_dir / "pilot-intake-report.md"
    write_json(json_path, manifest)
    markdown_path.write_text(render_intake_markdown(manifest), encoding="utf-8")
    print(json.dumps({"accepted": manifest["inputs"]["accepted_files"], "rejected": manifest["inputs"]["rejected_files"], "manifest": str(json_path)}, indent=2, ensure_ascii=False))
    return 1 if args.strict and manifest["inputs"]["rejected_files"] > 0 else 0


def command_triage(args: argparse.Namespace) -> int:
    plan = load_plan(args.plan)
    backlog = build_backlog(read_json(args.summary), read_json(args.observations), plan, read_json(args.intake), read_json(args.decisions))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "pilot-backlog.json"
    markdown_path = args.output_dir / "pilot-backlog.md"
    write_json(json_path, backlog)
    markdown_path.write_text(render_backlog_markdown(backlog), encoding="utf-8")
    print(json.dumps({"counts": backlog["counts"], "gate_passed": backlog["completion_gate"]["passed"], "backlog": str(json_path)}, indent=2, ensure_ascii=False))
    if args.fail_on_p0 and backlog["counts"]["P0"] > 0: return 2
    if args.strict and backlog["rejected_observations"]: return 1
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Planeja, recebe e prioriza o piloto externo do First Playable.")
    subparsers = parser.add_subparsers(dest="command", required=True)
    plan_parser = subparsers.add_parser("plan", help="Gera plano anônimo e balanceado.")
    plan_parser.add_argument("--pilot-id", required=True)
    plan_parser.add_argument("--participants", type=int, default=9)
    plan_parser.add_argument("--windows-share", type=float, default=2 / 3)
    plan_parser.add_argument("--matches-per-difficulty", type=int, default=2)
    plan_parser.add_argument("--output-dir", type=Path, default=Path("pilot-control"))
    plan_parser.set_defaults(handler=command_plan)
    intake_parser = subparsers.add_parser("intake", help="Valida lote de telemetria recebido.")
    intake_parser.add_argument("inputs", nargs="+", type=Path)
    intake_parser.add_argument("--plan", type=Path, required=True)
    intake_parser.add_argument("--output-dir", type=Path, default=Path("pilot-control/intake"))
    intake_parser.add_argument("--strict", action="store_true")
    intake_parser.set_defaults(handler=command_intake)
    triage_parser = subparsers.add_parser("triage", help="Gera backlog P0-P3.")
    triage_parser.add_argument("--plan", type=Path, required=True)
    triage_parser.add_argument("--summary", type=Path, required=True)
    triage_parser.add_argument("--observations", type=Path, required=True)
    triage_parser.add_argument("--intake", type=Path, required=True)
    triage_parser.add_argument("--decisions", type=Path, required=True)
    triage_parser.add_argument("--output-dir", type=Path, default=Path("pilot-control/triage"))
    triage_parser.add_argument("--strict", action="store_true")
    triage_parser.add_argument("--fail-on-p0", action="store_true")
    triage_parser.set_defaults(handler=command_triage)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try: return int(args.handler(args))
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        print(f"ERRO: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
