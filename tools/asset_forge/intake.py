#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import zipfile
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def dump_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def safe_rel(name: str) -> Path:
    p = Path(name.replace("\\", "/"))
    if p.is_absolute() or ".." in p.parts:
        raise ValueError(f"unsafe_path:{name}")
    return p


def collect_source(source: Path, staging: Path, max_files: int, max_bytes: int) -> list[Path]:
    staging.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    total = 0
    if source.is_dir():
        candidates = [p for p in source.rglob("*") if p.is_file()]
        for src in candidates:
            rel = safe_rel(src.relative_to(source).as_posix())
            size = src.stat().st_size
            total += size
            if len(written) + 1 > max_files or total > max_bytes:
                raise ValueError("intake_limits_exceeded")
            dst = staging / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            written.append(dst)
    elif source.is_file() and source.suffix.lower() == ".zip":
        with zipfile.ZipFile(source) as zf:
            infos = [i for i in zf.infolist() if not i.is_dir()]
            if len(infos) > max_files or sum(i.file_size for i in infos) > max_bytes:
                raise ValueError("intake_limits_exceeded")
            for info in infos:
                rel = safe_rel(info.filename)
                dst = staging / rel
                dst.parent.mkdir(parents=True, exist_ok=True)
                with zf.open(info) as src, dst.open("wb") as out:
                    shutil.copyfileobj(src, out)
                written.append(dst)
    else:
        raise ValueError("source_must_be_directory_or_zip")
    return written


def run(repo: Path, config_path: Path, source: Path, clean: bool = False) -> dict[str, Any]:
    cfg = load_json(config_path)
    staging = repo / cfg["staging_root"]
    destination = repo / cfg["intake_root"]
    if clean and staging.exists():
        shutil.rmtree(staging)
    files = collect_source(source, staging, int(cfg.get("max_files", 64)), int(cfg.get("max_bytes", 100_000_000)))

    expected = cfg["expected"]
    found_by_name: dict[str, list[Path]] = {}
    for p in files:
        found_by_name.setdefault(p.name, []).append(p)

    accepted: list[dict[str, Any]] = []
    missing: list[str] = []
    ambiguous: list[str] = []
    rejected: list[str] = []
    destination.mkdir(parents=True, exist_ok=True)

    allowed_ext = {e.lower() for e in cfg.get("allowed_extensions", [".png"])}
    for name in expected:
        matches = found_by_name.get(name, [])
        if not matches:
            missing.append(name)
            continue
        if len(matches) > 1:
            ambiguous.append(name)
            continue
        src = matches[0]
        if src.suffix.lower() not in allowed_ext:
            rejected.append(src.relative_to(staging).as_posix())
            continue
        dst = destination / name
        shutil.copy2(src, dst)
        accepted.append({"name": name, "path": dst.relative_to(repo).as_posix(), "bytes": dst.stat().st_size, "sha256": sha256(dst)})

    extras = sorted(
        p.relative_to(staging).as_posix()
        for p in files
        if p.name not in set(expected)
    )
    ready_for_processing = not missing and not ambiguous and not rejected
    report = {
        "schema": "taijifu/asset-forge-intake-report/v1",
        "pack_id": cfg["pack_id"],
        "source": str(source),
        "accepted": accepted,
        "missing": missing,
        "ambiguous": ambiguous,
        "rejected": rejected,
        "extras": extras,
        "ready_for_processing": ready_for_processing,
    }
    dump_json(repo / cfg["report"], report)

    review_root = repo / cfg["review_root"]
    review_root.mkdir(parents=True, exist_ok=True)
    dump_json(review_root / "intake-report.json", report)
    checklist = [
        f"# Revisão humana — {cfg['pack_id']}",
        "",
        f"- [ ] Identidade visual consistente",
        f"- [ ] Fundo removível/adequado",
        f"- [ ] Personagem não cortado",
        f"- [ ] Turnaround coerente",
        f"- [ ] Retratos coerentes",
        f"- [ ] Ícones legíveis",
        f"- [ ] Aprovar processamento: {'SIM' if ready_for_processing else 'NÃO'}",
        "",
        "## Arquivos aceitos",
    ]
    checklist += [f"- [ ] `{item['name']}` — `{item['sha256']}`" for item in accepted]
    (review_root / "CHECKLIST.md").write_text("\n".join(checklist) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("source", type=Path)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    try:
        report = run(args.repo.resolve(), args.config.resolve(), args.source.resolve(), args.clean)
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["ready_for_processing"] or not args.strict else 6


if __name__ == "__main__":
    raise SystemExit(main())
