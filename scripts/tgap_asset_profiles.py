#!/usr/bin/env python3
"""Perfis declarativos por classe de asset TGAP."""

from __future__ import annotations

from typing import Any

PROFILES: dict[str, dict[str, Any]] = {
    "character": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 12.0},
    "unit": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 12.0},
    "vfx": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 18.0},
    "tile": {"animated": False},
    "prop": {"animated": False},
    "environment": {"animated": False},
    "ui": {"animated": False},
}


def resolve_profile(manifest: dict[str, Any]) -> dict[str, Any]:
    asset_class = str(manifest.get("asset_class", "character"))
    base = dict(PROFILES.get(asset_class, {}))
    base.update(manifest.get("validation_profile", {}))
    base["asset_class"] = asset_class
    return base
