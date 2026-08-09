#!/usr/bin/env python3
"""Materialize the clean Lian Wu First Playable LOT01.

C64 uses only the recovered historical Lian Wu Character Lock images as visual
sources. The first-playable animations are whole-sprite continuous transforms:
no limb cutouts, no redraw and no regional compositing seams. Fighter physics
continues to provide actual translation, jumping, knockback and dodge travel.

These assets remain a First Playable runtime layer, not a claim of final authored
frame-by-frame animation.

Tehkné Solutions
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from lian_wu_canonical_identity import validate_source

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError as exc:
    raise SystemExit("C64_LOT01=BLOCKED missing dependency Pillow") from exc

SIGNATURE = "Tehkné Solutions"
CANVAS = (1024, 1024)
ALPHA_THRESHOLD = 3
BASELINE = 969
NEUTRAL_REL = Path("assets/characters/lian_wu/character_lock/lian_wu_neutral.png")
STANCE_REL = Path("assets/characters/lian_wu/character_lock/lian_wu_combat_stance.png")
NEUTRAL_FILE_SHA = "0e435757b5c8a114f3ba91653f79bc86db51ee9cf3bfb74c529efed5d4ff7ab5"
STANCE_FILE_SHA = "c8e6cd1feece7c2a54cf2279085c2a4bb33338dd6a3dcb3e4d5a2402b537631c"
CANONICAL_RGBA_SHA = "0bedec17308acd2c7b392f2c989cf97238908aa4f18b73371aa67c741eb6030b"
CANONICAL_BOUNDS = (325, 70, 720, 970)
TARGET_REL = Path("assets/tgap/pack_01_lian_wu/first_playable_lot_01")
CANDIDATE_REL = Path("assets/pack_01_characters/lian_wu/frames/c64_clean")

SPECS = {
    "idle": (8.0, True, 5),
    "run": (12.0, True, 8),
    "jump_start": (12.0, False, 4),
    "airborne": (10.0, True, 3),
    "fall": (12.0, False, 3),
    "attack_light": (10.0, False, 5),
    "guard": (6.0, True, 1),
    "dodge": (14.0, False, 5),
    "hit": (12.0, False, 4),
    "ko": (8.0, False, 5),
}
REQUIRED = tuple(SPECS.keys())


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def alpha_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.convert("RGBA").getchannel("A")
    return alpha.point(lambda v: 255 if v >= ALPHA_THRESHOLD else 0).getbbox() or (0, 0, 0, 0)


def offset(image: Image.Image, dx: int, dy: int) -> Image.Image:
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.alpha_composite(image, (int(dx), int(dy)))
    return out


def align_baseline(image: Image.Image) -> Image.Image:
    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        raise ValueError("empty_alpha_after_transform")
    dy = BASELINE - (bounds[3] - 1)
    return offset(image, 0, dy) if dy else image


def continuous_shear(image: Image.Image, factor: float, dx: int = 0) -> Image.Image:
    """Lean the complete sprite around the foot baseline without cutting regions."""
    inverse = (1.0, factor, -factor * BASELINE - dx, 0.0, 1.0, 0.0)
    posed = image.transform(
        image.size,
        Image.Transform.AFFINE,
        inverse,
        resample=Image.Resampling.NEAREST,
        fillcolor=(0, 0, 0, 0),
    )
    return align_baseline(posed)


def vertical_squash(image: Image.Image, factor: float) -> Image.Image:
    """Clean whole-sprite crouch around the canonical baseline."""
    bounds = alpha_bounds(image)
    crop = image.crop(bounds)
    height = max(1, int(round(crop.height * factor)))
    resized = crop.resize((crop.width, height), Image.Resampling.NEAREST)
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    x = int(round((bounds[0] + bounds[2] - resized.width) * 0.5))
    y = BASELINE - resized.height + 1
    out.alpha_composite(resized, (x, y))
    return out


def whole_rotate(image: Image.Image, degrees: float, dx: int = 0) -> Image.Image:
    bounds = alpha_bounds(image)
    pivot = (
        int(round((bounds[0] + bounds[2]) * 0.5)),
        int(round(bounds[1] + (bounds[3] - bounds[1]) * 0.68)),
    )
    posed = image.rotate(
        degrees,
        resample=Image.Resampling.NEAREST,
        center=pivot,
        expand=False,
        fillcolor=(0, 0, 0, 0),
    )
    if dx:
        posed = offset(posed, dx, 0)
    return align_baseline(posed)


def assert_frame(image: Image.Image, label: str) -> tuple[int, int, int, int]:
    if image.size != CANVAS:
        raise ValueError(f"{label}:canvas={image.size}")
    bounds = alpha_bounds(image)
    if bounds == (0, 0, 0, 0):
        raise ValueError(f"{label}:empty_alpha")
    if bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= CANVAS[0] or bounds[3] >= CANVAS[1]:
        raise ValueError(f"{label}:canvas_clip bounds={bounds}")
    if bounds[3] - 1 != BASELINE:
        raise ValueError(f"{label}:baseline={bounds[3]-1} expected={BASELINE}")
    return bounds


def save_family(repo: Path, name: str, frames: list[Image.Image]) -> list[dict]:
    folder = repo / CANDIDATE_REL / name
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    for index, frame in enumerate(frames, start=1):
        bounds = assert_frame(frame, f"{name}:{index}")
        path = folder / f"char_lian_wu__{name}__f{index:02d}.png"
        frame.save(path, format="PNG", optimize=False, compress_level=9)
        rows.append({
            "index": index,
            "path": path.relative_to(repo).as_posix(),
            "sha256": sha256(path),
            "alpha_bounds": list(bounds),
            "baseline_y": bounds[3] - 1,
        })
    return rows


def replace_with_exact(repo: Path, rows: list[dict], index: int, source: Path) -> None:
    target = repo / rows[index]["path"]
    shutil.copyfile(source, target)
    with Image.open(target) as opened:
        bounds = assert_frame(opened.convert("RGBA"), f"exact_handoff:{target.name}")
    rows[index].update({
        "sha256": sha256(target),
        "alpha_bounds": list(bounds),
        "baseline_y": bounds[3] - 1,
    })


def validate_diversity(name: str, rows: list[dict]) -> None:
    minimum = int(SPECS[name][2])
    unique = len({row["sha256"] for row in rows})
    if unique < minimum:
        raise ValueError(f"{name}:insufficient_diversity unique={unique} minimum={minimum}")


def generate_clean_families(repo: Path) -> dict:
    neutral_path = repo / NEUTRAL_REL
    stance_path = repo / STANCE_REL
    identity = validate_source(neutral_path)
    if identity["file_sha256"] != NEUTRAL_FILE_SHA:
        raise ValueError("neutral_file_identity_not_exact_historical")
    if identity["decoded_rgba_sha256"] != CANONICAL_RGBA_SHA:
        raise ValueError("neutral_rgba_identity_not_exact_historical")
    if sha256(stance_path) != STANCE_FILE_SHA:
        raise ValueError("combat_stance_hash_mismatch")

    neutral = Image.open(neutral_path).convert("RGBA")
    stance = Image.open(stance_path).convert("RGBA")
    if neutral.size != CANVAS or stance.size != CANVAS:
        raise ValueError("character_lock_canvas_mismatch")
    if alpha_bounds(neutral) != CANONICAL_BOUNDS:
        raise ValueError(f"neutral_bounds={alpha_bounds(neutral)} expected={CANONICAL_BOUNDS}")

    families_images = {
        "idle": [continuous_shear(neutral, k) for k in (0.0, 0.006, 0.012, 0.018, 0.009, 0.0)],
        "run": [
            continuous_shear(neutral, k, dx)
            for k, dx in ((0.04,2),(0.07,5),(0.10,8),(0.06,5),(0.02,1),(0.08,6),(0.11,8),(0.05,4))
        ],
        "jump_start": [vertical_squash(neutral, f) for f in (1.00, 0.95, 0.90, 0.94)],
        "airborne": [continuous_shear(neutral, k) for k in (0.06, 0.09, 0.04)],
        "fall": [continuous_shear(neutral, k) for k in (-0.02, -0.05, -0.08)],
        "attack_light": [
            neutral.copy(),
            continuous_shear(stance, 0.03, 2),
            continuous_shear(stance, 0.08, 7),
            continuous_shear(stance, 0.13, 13),
            continuous_shear(stance, 0.055, 5),
            neutral.copy(),
        ],
        "guard": [stance.copy()],
        "dodge": [
            continuous_shear(neutral, 0.04, -2),
            continuous_shear(neutral, 0.09, -7),
            continuous_shear(neutral, 0.14, -12),
            continuous_shear(neutral, 0.08, -6),
            neutral.copy(),
        ],
        "hit": [
            continuous_shear(neutral, -0.04, 2),
            continuous_shear(neutral, -0.09, 7),
            continuous_shear(neutral, -0.025, 3),
            neutral.copy(),
        ],
        "ko": [
            whole_rotate(neutral, 12.0, 4),
            whole_rotate(neutral, 30.0, 11),
            whole_rotate(neutral, 52.0, 17),
            whole_rotate(neutral, 72.0, 21),
            whole_rotate(neutral, 90.0, 24),
        ],
    }

    families = {name: save_family(repo, name, frames) for name, frames in families_images.items()}

    # Preserve exact historical byte identity at semantic neutral handoffs.
    for name, indices in {
        "idle": (0, 5),
        "jump_start": (0,),
        "attack_light": (0, 5),
        "dodge": (4,),
        "hit": (3,),
    }.items():
        for index in indices:
            replace_with_exact(repo, families[name], index, neutral_path)

    # Guard is the exact historical combat stance, byte-for-byte.
    replace_with_exact(repo, families["guard"], 0, stance_path)

    for name in REQUIRED:
        validate_diversity(name, families[name])

    metadata = {
        "schema": "tehkne/taijifu-c64-clean-first-playable-families/v1",
        "signature": SIGNATURE,
        "status": "candidate_pending_contact_sheet_review",
        "character_id": "lian_wu",
        "source": {
            "neutral": NEUTRAL_REL.as_posix(),
            "neutral_sha256": NEUTRAL_FILE_SHA,
            "neutral_decoded_rgba_sha256": CANONICAL_RGBA_SHA,
            "combat_stance": STANCE_REL.as_posix(),
            "combat_stance_sha256": STANCE_FILE_SHA,
            "alpha_bounds": list(CANONICAL_BOUNDS),
            "baseline_y": BASELINE,
        },
        "families": families,
        "generation_policy": {
            "method": "whole_sprite_continuous_affine_v1",
            "redraw": False,
            "regional_cutouts": False,
            "regional_compositor_promoted": False,
            "regional_compositor_rejection_reason": "visible seam and duplicate-region artifacts in enlarged visual review",
            "identity_mutation": False,
            "nearest_neighbor_transform": True,
            "baseline_preserved": True,
            "fighter_physics_owns_world_translation": True,
            "first_playable_not_final_authored_animation": True,
            "visual_review_required_before_repo_binary_promotion": True,
        },
    }
    meta = repo / "assets/pack_01_characters/lian_wu/metadata/c64_first_playable_families.json"
    meta.parent.mkdir(parents=True, exist_ok=True)
    meta.write_text(json.dumps(metadata, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return metadata


def collect_source_frames(repo: Path, name: str) -> list[Path]:
    frames = sorted((repo / CANDIDATE_REL / name).glob("*.png"))
    if not frames:
        raise ValueError(f"no_frames={name}")
    return frames


def write_spriteframes(target: Path, animation_files: dict[str, list[Path]]) -> None:
    resources: list[str] = []
    ids: dict[Path, int] = {}
    ext_id = 1
    for name in REQUIRED:
        for frame in animation_files[name]:
            ids[frame] = ext_id
            resources.append(f'[ext_resource type="Texture2D" path="res://{frame.as_posix()}" id="{ext_id}"]')
            ext_id += 1
    animations: list[str] = []
    for name in REQUIRED:
        fps, loop, _ = SPECS[name]
        rows = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%d")}' % ids[path]
            for path in animation_files[name]
        )
        animations.append(
            '{"frames": [%s], "loop": %s, "name": &"%s", "speed": %.3f}'
            % (rows, "true" if loop else "false", name, fps)
        )
    target.write_text("\n".join([
        f'[gd_resource type="SpriteFrames" load_steps={ext_id} format=3]',
        "",
        *resources,
        "",
        "[resource]",
        "animations = [%s]" % ",\n".join(animations),
        "",
    ]), encoding="utf-8")


def build_contact_sheet(repo: Path, target: Path, animation_files: dict[str, list[Path]]) -> None:
    thumb, label_w, gap = 112, 150, 8
    max_frames = max(len(v) for v in animation_files.values())
    sheet = Image.new("RGB", (label_w + max_frames * (thumb + gap) + gap, len(REQUIRED) * (thumb + 28) + 20), "white")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    for row, name in enumerate(REQUIRED):
        y = 10 + row * (thumb + 28)
        draw.text((8, y + 45), name, fill="black", font=font)
        for col, path in enumerate(animation_files[name]):
            image = Image.open(repo / path).convert("RGBA")
            crop = image.crop(alpha_bounds(image))
            crop.thumbnail((thumb, thumb), Image.Resampling.NEAREST)
            tile = Image.new("RGBA", (thumb, thumb), (240, 240, 240, 255))
            tile.alpha_composite(crop, ((thumb - crop.width) // 2, thumb - crop.height))
            sheet.paste(tile.convert("RGB"), (label_w + col * (thumb + gap), y))
            draw.text((label_w + col * (thumb + gap) + 2, y + thumb + 2), f"f{col+1:02d}", fill="black", font=font)
    sheet.save(target, format="PNG", compress_level=9)


def materialize(repo: Path, metadata: dict) -> dict:
    target = repo / TARGET_REL
    if target.exists():
        shutil.rmtree(target)
    (target / "animations").mkdir(parents=True, exist_ok=True)

    animation_files: dict[str, list[Path]] = {}
    for name in REQUIRED:
        sources = collect_source_frames(repo, name)
        destination = target / "animations" / name
        destination.mkdir(parents=True, exist_ok=True)
        copied: list[Path] = []
        for index, source in enumerate(sources, start=1):
            out = destination / f"char_lian_wu__{name}__f{index:02d}.png"
            shutil.copyfile(source, out)
            copied.append(out.relative_to(repo))
        animation_files[name] = copied

    resource = target / "lian_wu_first_playable_frames.tres"
    write_spriteframes(resource, animation_files)

    runtime = {
        "schema": "tehkne/taijifu-first-playable-runtime-map/v1",
        "signature": SIGNATURE,
        "animations": {
            name: {
                "path": f"animations/{name}",
                "fps": SPECS[name][0],
                "loop": SPECS[name][1],
                "frames": len(animation_files[name]),
            }
            for name in REQUIRED
        },
    }
    manifest = {
        "schema": "tehkne/taijifu-first-playable-lot/v1",
        "signature": SIGNATURE,
        "lot_id": "pack_01_lian_wu_first_playable_lot_01",
        "stage": "C64",
        "status": "candidate_pending_contact_sheet_review",
        "character_id": "lian_wu",
        "visual_method": "whole_sprite_continuous_affine_v1",
        "source_character_lock_sha256": NEUTRAL_FILE_SHA,
        "source_character_lock_rgba_sha256": CANONICAL_RGBA_SHA,
        "required_animations": list(REQUIRED),
        "animation_count": len(REQUIRED),
        "frame_count": sum(len(v) for v in animation_files.values()),
        "spriteframes": resource.relative_to(repo).as_posix(),
        "c64_families_metadata": "assets/pack_01_characters/lian_wu/metadata/c64_first_playable_families.json",
    }
    approval = {
        "schema": "tehkne/taijifu-first-playable-approval/v1",
        "signature": SIGNATURE,
        "status": "candidate_pending_visual_review",
        "technical_generation": "pass",
        "binary_promotion_allowed": False,
        "required_review_artifact": "c64-lian-first-playable-contact-sheet.png",
    }
    (target / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (target / "runtime-map.json").write_text(json.dumps(runtime, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (target / "approval.json").write_text(json.dumps(approval, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    checks: list[str] = []
    for path in sorted(target.rglob("*")):
        if path.is_file() and path.name != "checksums.sha256":
            checks.append(f"{sha256(path)}  {path.relative_to(target).as_posix()}")
    (target / "checksums.sha256").write_text("\n".join(checks) + "\n", encoding="utf-8")

    contact = repo / "c64-lian-first-playable-contact-sheet.png"
    build_contact_sheet(repo, contact, animation_files)

    report = {
        "schema": "tehkne/taijifu-c64-lot01-materialization-report/v1",
        "signature": SIGNATURE,
        "status": "candidate_pending_contact_sheet_review",
        "required_animation_count": len(REQUIRED),
        "frame_count": manifest["frame_count"],
        "animations": {name: len(animation_files[name]) for name in REQUIRED},
        "spriteframes": resource.relative_to(repo).as_posix(),
        "contact_sheet": contact.name,
        "source_exact_historical": True,
        "visual_method": manifest["visual_method"],
        "regional_seam_artifacts_removed": True,
    }
    (repo / "c64-lian-first-playable-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", default=".")
    args = parser.parse_args()
    repo = Path(args.repo_root).resolve()
    try:
        metadata = generate_clean_families(repo)
        report = materialize(repo, metadata)
    except (OSError, ValueError) as exc:
        print(f"C64_LOT01=BLOCKED {exc}")
        return 2
    print("C64_LOT01_MATERIALIZATION=PASS")
    print(f"animations={report['required_animation_count']}/10")
    print(f"frames={report['frame_count']}")
    print(f"spriteframes={report['spriteframes']}")
    print(f"visual_method={report['visual_method']}")
    print("regional_seam_artifacts_removed=PASS")
    print("visual_review=PENDING")
    print(f"SIGNATURE={SIGNATURE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
