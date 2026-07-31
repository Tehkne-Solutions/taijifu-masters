#!/usr/bin/env python3
"""Aggregate local Taijifu Masters First Playable telemetry reports.

This tool intentionally uses only Python's standard library. It reads telemetry
JSON files produced by the First Playable, validates their public schema and
writes one machine-readable JSON summary plus one human-readable Markdown
report. No data is uploaded or modified in place.

Signature: Tehkné Solutions
"""
from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

TELEMETRY_SCHEMA = "tehkne/taijifu-match-telemetry/v3"
SUMMARY_SCHEMA = "tehkne/taijifu-first-playable-summary/v1"
SIGNATURE = "Tehkné Solutions"
JSON_OUTPUT_NAME = "first-playable-playtest-summary.json"
MARKDOWN_OUTPUT_NAME = "first-playable-playtest-summary.md"
DIFFICULTY_ORDER = ("apprentice", "disciple", "master", "unknown")
FEEDBACK_IDS = ("too_easy", "balanced", "too_hard", "missing")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Consolida relatórios locais do First Playable sem enviar dados externos."
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        type=Path,
        help="Arquivos JSON ou diretórios pesquisados recursivamente.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("playtest-summary"),
        help="Diretório de saída (padrão: playtest-summary).",
    )
    parser.add_argument(
        "--fail-on-invalid",
        action="store_true",
        help="Retorna erro quando qualquer arquivo candidato for inválido.",
    )
    return parser.parse_args(argv)


def discover_json_files(inputs: Iterable[Path]) -> tuple[list[Path], list[str]]:
    files: set[Path] = set()
    warnings: list[str] = []
    for raw_path in inputs:
        path = raw_path.expanduser()
        if not path.exists():
            warnings.append(f"Entrada inexistente: {path}")
            continue
        if path.is_file():
            if path.suffix.lower() == ".json":
                files.add(path.resolve())
            else:
                warnings.append(f"Arquivo ignorado por não ser JSON: {path}")
            continue
        for candidate in path.rglob("*.json"):
            if candidate.is_file():
                files.add(candidate.resolve())
    return sorted(files), warnings


def load_session(path: Path) -> tuple[dict[str, Any] | None, str | None]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        return None, f"{path}: JSON ilegível ({error})"
    if not isinstance(payload, dict):
        return None, f"{path}: raiz JSON deve ser um objeto"
    if payload.get("schema") != TELEMETRY_SCHEMA:
        return None, f"{path}: schema incompatível ({payload.get('schema', 'ausente')})"
    if not isinstance(payload.get("rounds"), list):
        return None, f"{path}: campo rounds deve ser uma lista"
    if not str(payload.get("session_id", "")).strip():
        return None, f"{path}: session_id ausente"
    return payload, None


def safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def safe_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "yes", "sim"}
    return bool(value)


def normalized_difficulty(metadata: dict[str, Any]) -> str:
    difficulty = str(metadata.get("difficulty_id", "unknown")).strip().lower()
    return difficulty if difficulty in DIFFICULTY_ORDER else "unknown"


def normalized_feedback(metadata: dict[str, Any]) -> str:
    feedback = str(metadata.get("balance_feedback", "missing")).strip().lower()
    return feedback if feedback in FEEDBACK_IDS else "missing"


def event_count(round_data: dict[str, Any], event_id: str) -> int:
    events = round_data.get("events", [])
    if not isinstance(events, list):
        return 0
    return sum(
        1
        for event in events
        if isinstance(event, dict) and str(event.get("event_id", "")) == event_id
    )


def new_bucket() -> dict[str, Any]:
    return {
        "rounds": 0,
        "completed_rounds": 0,
        "abandoned_rounds": 0,
        "player_wins": 0,
        "player_losses": 0,
        "draws_or_unknown": 0,
        "durations_seconds": [],
        "feedback": Counter({feedback_id: 0 for feedback_id in FEEDBACK_IDS}),
        "pauses": 0,
        "resumes": 0,
        "rematches": 0,
        "result_reasons": Counter(),
    }


def aggregate_sessions(
    sessions: list[tuple[Path, dict[str, Any]]],
    candidate_count: int,
    warnings: list[str],
) -> dict[str, Any]:
    buckets: dict[str, dict[str, Any]] = defaultdict(new_bucket)
    versions: Counter[str] = Counter()
    platforms: Counter[str] = Counter()
    locales: Counter[str] = Counter()
    session_ids: set[str] = set()
    duplicate_session_ids: list[str] = []
    total_rounds = 0

    for path, session in sessions:
        session_id = str(session.get("session_id", ""))
        if session_id in session_ids:
            duplicate_session_ids.append(session_id)
            warnings.append(f"{path}: session_id duplicado ({session_id})")
        session_ids.add(session_id)

        session_metadata = session.get("metadata", {})
        if not isinstance(session_metadata, dict):
            session_metadata = {}
        versions[str(session_metadata.get("build_version", "unknown"))] += 1
        platforms[str(session_metadata.get("platform", "unknown"))] += 1
        locales[str(session_metadata.get("locale", "unknown"))] += 1

        for round_data in session.get("rounds", []):
            if not isinstance(round_data, dict):
                warnings.append(f"{path}: rodada ignorada por não ser objeto")
                continue
            metadata = round_data.get("metadata", {})
            if not isinstance(metadata, dict):
                metadata = {}
            difficulty = normalized_difficulty(metadata)
            bucket = buckets[difficulty]
            bucket["rounds"] += 1
            total_rounds += 1

            duration_seconds = safe_float(round_data.get("duration_msec")) / 1000.0
            if duration_seconds <= 0.0:
                duration_seconds = safe_float(metadata.get("elapsed_seconds"))
            if duration_seconds >= 0.0:
                bucket["durations_seconds"].append(duration_seconds)

            result_reason = str(metadata.get("result_reason", "unknown")).strip().lower()
            result_reason = result_reason or "unknown"
            bucket["result_reasons"][result_reason] += 1
            abandoned = result_reason == "abandoned"
            if abandoned:
                bucket["abandoned_rounds"] += 1
            else:
                bucket["completed_rounds"] += 1

            winner_profile = str(round_data.get("winner_profile_id", ""))
            if winner_profile == "p1" or safe_bool(metadata.get("player_won", False)):
                bucket["player_wins"] += 1
            elif winner_profile == "p2":
                bucket["player_losses"] += 1
            else:
                bucket["draws_or_unknown"] += 1

            feedback = normalized_feedback(metadata)
            bucket["feedback"][feedback] += 1
            bucket["pauses"] += event_count(round_data, "pause")
            bucket["resumes"] += event_count(round_data, "resume")
            if safe_bool(metadata.get("rematch_requested", False)):
                bucket["rematches"] += 1

    difficulty_summary = {
        difficulty: finalize_bucket(buckets[difficulty])
        for difficulty in DIFFICULTY_ORDER
        if buckets[difficulty]["rounds"] > 0
    }
    totals = combine_buckets(buckets.values())
    quality_signals = build_quality_signals(totals, difficulty_summary)
    recommendations = build_recommendations(quality_signals)

    return {
        "schema": SUMMARY_SCHEMA,
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "signature": SIGNATURE,
        "source_schema": TELEMETRY_SCHEMA,
        "privacy": "offline_local_processing",
        "inputs": {
            "candidate_json_files": candidate_count,
            "valid_sessions": len(sessions),
            "invalid_or_ignored_files": max(0, candidate_count - len(sessions)),
            "unique_session_ids": len(session_ids),
            "duplicate_session_ids": sorted(set(duplicate_session_ids)),
        },
        "coverage": {
            "build_versions": dict(sorted(versions.items())),
            "platforms": dict(sorted(platforms.items())),
            "locales": dict(sorted(locales.items())),
        },
        "totals": totals,
        "by_difficulty": difficulty_summary,
        "quality_signals": quality_signals,
        "recommendations": recommendations,
        "warnings": warnings,
    }


def finalize_bucket(bucket: dict[str, Any]) -> dict[str, Any]:
    rounds = int(bucket["rounds"])
    completed = int(bucket["completed_rounds"])
    rated = rounds - int(bucket["feedback"]["missing"])
    durations = [safe_float(value) for value in bucket["durations_seconds"]]
    completed_decisions = int(bucket["player_wins"]) + int(bucket["player_losses"])
    return {
        "rounds": rounds,
        "completed_rounds": completed,
        "abandoned_rounds": int(bucket["abandoned_rounds"]),
        "abandonment_rate": ratio(bucket["abandoned_rounds"], rounds),
        "player_wins": int(bucket["player_wins"]),
        "player_losses": int(bucket["player_losses"]),
        "draws_or_unknown": int(bucket["draws_or_unknown"]),
        "player_win_rate": ratio(bucket["player_wins"], completed_decisions),
        "average_duration_seconds": round(statistics.fmean(durations), 3) if durations else 0.0,
        "median_duration_seconds": round(statistics.median(durations), 3) if durations else 0.0,
        "feedback": {key: int(bucket["feedback"][key]) for key in FEEDBACK_IDS},
        "feedback_coverage": ratio(rated, rounds),
        "pauses": int(bucket["pauses"]),
        "resumes": int(bucket["resumes"]),
        "rematches": int(bucket["rematches"]),
        "rematch_rate": ratio(bucket["rematches"], completed),
        "result_reasons": dict(sorted(bucket["result_reasons"].items())),
    }


def combine_buckets(buckets: Iterable[dict[str, Any]]) -> dict[str, Any]:
    combined = new_bucket()
    for bucket in buckets:
        combined["rounds"] += bucket["rounds"]
        combined["completed_rounds"] += bucket["completed_rounds"]
        combined["abandoned_rounds"] += bucket["abandoned_rounds"]
        combined["player_wins"] += bucket["player_wins"]
        combined["player_losses"] += bucket["player_losses"]
        combined["draws_or_unknown"] += bucket["draws_or_unknown"]
        combined["durations_seconds"].extend(bucket["durations_seconds"])
        combined["feedback"].update(bucket["feedback"])
        combined["pauses"] += bucket["pauses"]
        combined["resumes"] += bucket["resumes"]
        combined["rematches"] += bucket["rematches"]
        combined["result_reasons"].update(bucket["result_reasons"])
    return finalize_bucket(combined)


def ratio(numerator: Any, denominator: Any) -> float:
    denominator_value = safe_float(denominator)
    if denominator_value <= 0.0:
        return 0.0
    return round(safe_float(numerator) / denominator_value, 4)


def build_quality_signals(
    totals: dict[str, Any], by_difficulty: dict[str, dict[str, Any]]
) -> list[dict[str, str]]:
    signals: list[dict[str, str]] = []

    def add(signal_id: str, severity: str, message: str) -> None:
        signals.append({"id": signal_id, "severity": severity, "message": message})

    rounds = int(totals.get("rounds", 0))
    if rounds < 12:
        add(
            "sample_size_low",
            "info",
            f"A amostra possui {rounds} partidas; busque pelo menos 12 antes de alterar balanceamento.",
        )
    if safe_float(totals.get("feedback_coverage")) < 0.7:
        add(
            "feedback_coverage_low",
            "warning",
            "Menos de 70% das partidas possuem avaliação de equilíbrio.",
        )
    if safe_float(totals.get("abandonment_rate")) > 0.15:
        add(
            "abandonment_high",
            "critical",
            "Mais de 15% das partidas foram abandonadas; investigar clareza, duração e soft locks.",
        )

    apprentice = by_difficulty.get("apprentice")
    if apprentice:
        rated = sum(apprentice["feedback"].get(key, 0) for key in FEEDBACK_IDS[:-1])
        too_hard_rate = ratio(apprentice["feedback"].get("too_hard", 0), rated)
        if rated >= 3 and too_hard_rate >= 0.3:
            add(
                "apprentice_too_hard",
                "critical",
                "Ao menos 30% dos jogadores avaliados consideraram Aprendiz difícil demais.",
            )
        if apprentice.get("player_win_rate", 0.0) < 0.5 and apprentice.get("completed_rounds", 0) >= 4:
            add(
                "apprentice_win_rate_low",
                "warning",
                "A taxa de vitória do jogador no Aprendiz está abaixo de 50%.",
            )

    master = by_difficulty.get("master")
    if master:
        rated = sum(master["feedback"].get(key, 0) for key in FEEDBACK_IDS[:-1])
        too_easy_rate = ratio(master["feedback"].get("too_easy", 0), rated)
        if rated >= 3 and too_easy_rate >= 0.3:
            add(
                "master_too_easy",
                "warning",
                "Ao menos 30% dos jogadores avaliados consideraram Mestre fácil demais.",
            )
        if master.get("player_win_rate", 0.0) > 0.8 and master.get("completed_rounds", 0) >= 5:
            add(
                "master_win_rate_high",
                "warning",
                "A taxa de vitória do jogador no Mestre está acima de 80%.",
            )

    if not any(signal["severity"] in {"warning", "critical"} for signal in signals):
        add(
            "no_blocking_signal",
            "info",
            "Nenhum sinal quantitativo bloqueador foi detectado na amostra atual.",
        )
    return signals


def build_recommendations(signals: list[dict[str, str]]) -> list[str]:
    signal_ids = {signal["id"] for signal in signals}
    recommendations: list[str] = []
    if "sample_size_low" in signal_ids:
        recommendations.append("Coletar mais partidas antes de ajustar números de combate.")
    if "feedback_coverage_low" in signal_ids:
        recommendations.append("Orientar testadores a responder a pergunta de equilíbrio após cada luta.")
    if "abandonment_high" in signal_ids:
        recommendations.append("Revisar sessões abandonadas e reproduzir possíveis soft locks ou problemas de compreensão.")
    if {"apprentice_too_hard", "apprentice_win_rate_low"} & signal_ids:
        recommendations.append("Reduzir pressão ofensiva ou ampliar janelas de reação no Aprendiz em experimento controlado.")
    if {"master_too_easy", "master_win_rate_high"} & signal_ids:
        recommendations.append("Aumentar adaptação e punição da IA Mestre sem elevar dano bruto indiscriminadamente.")
    if not recommendations:
        recommendations.append("Manter o balanceamento atual e priorizar leitura visual, sensação de impacto e variedade.")
    return recommendations


def percent(value: Any) -> str:
    return f"{safe_float(value) * 100:.1f}%"


def render_markdown(summary: dict[str, Any]) -> str:
    totals = summary["totals"]
    lines = [
        "# Taijifu Masters — consolidação do playtest First Playable",
        "",
        f"Gerado em: `{summary['generated_at_utc']}`  ",
        f"Processamento: **offline/local**  ",
        f"Assinatura: **{SIGNATURE}**",
        "",
        "## Visão geral",
        "",
        f"- Sessões válidas: **{summary['inputs']['valid_sessions']}**",
        f"- Partidas: **{totals['rounds']}**",
        f"- Partidas concluídas: **{totals['completed_rounds']}**",
        f"- Abandonos: **{totals['abandoned_rounds']}** ({percent(totals['abandonment_rate'])})",
        f"- Vitória do jogador: **{percent(totals['player_win_rate'])}**",
        f"- Duração média: **{totals['average_duration_seconds']:.1f}s**",
        f"- Cobertura de feedback: **{percent(totals['feedback_coverage'])}**",
        f"- Revanche após resultado: **{percent(totals['rematch_rate'])}**",
        "",
        "## Por dificuldade",
        "",
        "| Dificuldade | Partidas | Vitória P1 | Média | Abandono | Fácil demais | Equilibrado | Difícil demais | Revanche |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    labels = {
        "apprentice": "Aprendiz",
        "disciple": "Discípulo",
        "master": "Mestre",
        "unknown": "Desconhecida",
    }
    for difficulty in DIFFICULTY_ORDER:
        data = summary["by_difficulty"].get(difficulty)
        if not data:
            continue
        feedback = data["feedback"]
        lines.append(
            "| {label} | {rounds} | {win_rate} | {duration:.1f}s | {abandonment} | {too_easy} | {balanced} | {too_hard} | {rematch} |".format(
                label=labels[difficulty],
                rounds=data["rounds"],
                win_rate=percent(data["player_win_rate"]),
                duration=data["average_duration_seconds"],
                abandonment=percent(data["abandonment_rate"]),
                too_easy=feedback["too_easy"],
                balanced=feedback["balanced"],
                too_hard=feedback["too_hard"],
                rematch=percent(data["rematch_rate"]),
            )
        )

    lines.extend(["", "## Sinais de qualidade", ""])
    severity_labels = {"info": "INFO", "warning": "ATENÇÃO", "critical": "CRÍTICO"}
    for signal in summary["quality_signals"]:
        lines.append(f"- **{severity_labels.get(signal['severity'], signal['severity'].upper())}:** {signal['message']}")

    lines.extend(["", "## Recomendações", ""])
    for index, recommendation in enumerate(summary["recommendations"], start=1):
        lines.append(f"{index}. {recommendation}")

    if summary["warnings"]:
        lines.extend(["", "## Avisos de importação", ""])
        lines.extend(f"- {warning}" for warning in summary["warnings"])

    lines.extend(["", "---", "", SIGNATURE, ""])
    return "\n".join(lines)


def write_outputs(summary: dict[str, Any], output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    json_path = output_dir / JSON_OUTPUT_NAME
    markdown_path = output_dir / MARKDOWN_OUTPUT_NAME
    json_path.write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    markdown_path.write_text(render_markdown(summary), encoding="utf-8")
    return json_path, markdown_path


def run(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    candidates, discovery_warnings = discover_json_files(args.inputs)
    sessions: list[tuple[Path, dict[str, Any]]] = []
    warnings = list(discovery_warnings)
    for path in candidates:
        session, warning = load_session(path)
        if warning:
            warnings.append(warning)
            continue
        assert session is not None
        sessions.append((path, session))

    if not sessions:
        print("Nenhuma sessão válida do First Playable foi encontrada.", file=sys.stderr)
        for warning in warnings:
            print(f"- {warning}", file=sys.stderr)
        return 2

    summary = aggregate_sessions(sessions, len(candidates), warnings)
    json_path, markdown_path = write_outputs(summary, args.output_dir)
    print(
        json.dumps(
            {
                "valid_sessions": summary["inputs"]["valid_sessions"],
                "rounds": summary["totals"]["rounds"],
                "json": str(json_path),
                "markdown": str(markdown_path),
            },
            ensure_ascii=False,
        )
    )
    if args.fail_on_invalid and warnings:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
