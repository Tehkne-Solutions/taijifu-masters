from __future__ import annotations

import hashlib
import importlib.util
import json
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "tools/asset_forge/import_first_playable_lot01.py"
spec = importlib.util.spec_from_file_location("lot01_importer", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(module)


def _build_archive(tmp_path: Path, approved: bool = True) -> Path:
    root = tmp_path / "source" / "PACK_01_LIAN_WU_FIRST_PLAYABLE_LOT_01_v1.0.0"
    runtime = {"animations": {}}
    files: list[Path] = []
    for name in module.REQUIRED:
        folder = root / "animations" / name
        folder.mkdir(parents=True, exist_ok=True)
        frame = folder / f"char_lian_wu__{name}__f001.png"
        frame.write_bytes(b"png-placeholder")
        files.append(frame)
        runtime["animations"][name] = {"path": f"animations/{name}", "fps": 10, "loop": name in {"idle", "run", "airborne", "fall", "guard"}}
    manifest = root / "manifest.json"
    manifest.write_text(json.dumps({"lot_id": "pack_01_lian_wu_first_playable_lot_01"}), encoding="utf-8")
    runtime_file = root / "runtime-map.json"
    runtime_file.write_text(json.dumps(runtime), encoding="utf-8")
    approval = root / "approval.json"
    approval.write_text(json.dumps({"status": "approved" if approved else "art_required"}), encoding="utf-8")
    files.extend([manifest, runtime_file, approval])
    checksums = root / "checksums.sha256"
    checksums.write_text("\n".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(root).as_posix()}"
        for path in files
    ) + "\n", encoding="utf-8")
    archive = tmp_path / "lot01.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        for path in root.rglob("*"):
            if path.is_file():
                bundle.write(path, path.relative_to(root.parent))
    return archive


def test_imports_approved_lot_and_generates_spriteframes(tmp_path: Path) -> None:
    archive = _build_archive(tmp_path)
    project = tmp_path / "project"
    project.mkdir()
    output = module.import_lot(archive, project)
    assert output.is_file()
    text = output.read_text(encoding="utf-8")
    for name in module.REQUIRED:
        assert f'&"{name}"' in text
        assert (output.parent / "animations" / name).is_dir()


def test_rejects_unapproved_lot(tmp_path: Path) -> None:
    archive = _build_archive(tmp_path, approved=False)
    project = tmp_path / "project"
    project.mkdir()
    try:
        module.import_lot(archive, project)
    except ValueError as exc:
        assert "não aprovado" in str(exc)
    else:
        raise AssertionError("lote sem aprovação foi importado")


def test_rejects_zip_slip(tmp_path: Path) -> None:
    archive = tmp_path / "unsafe.zip"
    with zipfile.ZipFile(archive, "w") as bundle:
        bundle.writestr("../escape.txt", "blocked")
    destination = tmp_path / "extract"
    destination.mkdir()
    try:
        module.safe_extract(archive, destination)
    except ValueError as exc:
        assert "inseguro" in str(exc)
    else:
        raise AssertionError("ZIP inseguro foi extraído")
