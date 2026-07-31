from __future__ import annotations

import hashlib
import importlib.util
import json
import zipfile
from pathlib import Path

MODULE_PATH = Path(__file__).parents[1] / "tools/asset_forge/import_training_rival_lot01.py"
spec = importlib.util.spec_from_file_location("training_rival_importer", MODULE_PATH)
module = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(module)


def _build_zip(tmp_path: Path, approved: bool = True) -> Path:
    root = tmp_path / "TRAINING_RIVAL_LOT_01"
    root.mkdir()
    animations = {}
    checksum_lines = []
    for animation in module.REQUIRED:
        folder = root / "animations" / animation
        folder.mkdir(parents=True)
        frame = folder / f"char_training_rival__{animation}__f001.png"
        frame.write_bytes(b"png-data-" + animation.encode())
        relative = frame.relative_to(root).as_posix()
        checksum_lines.append(f"{hashlib.sha256(frame.read_bytes()).hexdigest()}  {relative}")
        animations[animation] = {"fps": 12, "loop": animation in {"idle", "run", "airborne", "fall", "guard"}}
    (root / "manifest.json").write_text(json.dumps({"lot_id": module.LOT_ID, "animations": animations}), encoding="utf-8")
    (root / "approval.json").write_text(json.dumps({"status": "approved" if approved else "art_review"}), encoding="utf-8")
    (root / "runtime-map.json").write_text("{}", encoding="utf-8")
    for metadata in ("manifest.json", "approval.json", "runtime-map.json"):
        file_path = root / metadata
        checksum_lines.append(f"{hashlib.sha256(file_path.read_bytes()).hexdigest()}  {metadata}")
    (root / "checksums.sha256").write_text("\n".join(checksum_lines) + "\n", encoding="utf-8")
    archive = tmp_path / "training-rival.zip"
    with zipfile.ZipFile(archive, "w") as zf:
        for path in root.rglob("*"):
            if path.is_file():
                zf.write(path, arcname=f"{root.name}/{path.relative_to(root).as_posix()}")
    return archive


def test_imports_approved_package(tmp_path: Path) -> None:
    archive = _build_zip(tmp_path)
    project = tmp_path / "project"
    project.mkdir()
    destination = module.import_package(archive, project)
    resource = destination / "training_rival_first_playable_frames.tres"
    assert resource.exists()
    content = resource.read_text(encoding="utf-8")
    for animation in module.REQUIRED:
        assert f'&"{animation}"' in content


def test_rejects_unapproved_package(tmp_path: Path) -> None:
    archive = _build_zip(tmp_path, approved=False)
    project = tmp_path / "project"
    project.mkdir()
    try:
        module.import_package(archive, project)
    except ValueError as error:
        assert "não aprovado" in str(error)
    else:
        raise AssertionError("lote não aprovado foi aceito")
