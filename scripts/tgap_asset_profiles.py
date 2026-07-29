#!/usr/bin/env python3
"""Perfis declarativos por classe de asset TGAP."""

from __future__ import annotations

from typing import Any

PROFILES: dict[str, dict[str, Any]] = {
    "character": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 12.0, "visual": {"canvas": [128, 128], "alpha": "required", "min_margin": 2, "baseline_min_ratio": 0.70, "pivot": "bottom_center", "pivot_drift_limit": 12}},
    "unit": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 12.0, "visual": {"canvas": [128, 128], "alpha": "required", "min_margin": 2, "baseline_min_ratio": 0.70, "pivot": "bottom_center", "pivot_drift_limit": 12}},
    "vfx": {"animated": True, "frames_root": "frames", "metadata_root": "metadata", "frame_digits": 2, "default_fps": 18.0, "visual": {"canvas": [256, 256], "alpha": "required", "min_margin": 0, "baseline_min_ratio": None, "pivot": "center", "pivot_drift_limit": 24}},
    "tile": {"animated": False, "visual": {"canvas": [128, 64], "alpha": "allowed", "min_margin": 0, "baseline_min_ratio": None, "pivot": "center", "pivot_drift_limit": None}},
    "prop": {"animated": False, "visual": {"canvas": [128, 128], "alpha": "required", "min_margin": 1, "baseline_min_ratio": 0.65, "pivot": "bottom_center", "pivot_drift_limit": None}},
    "environment": {"animated": False, "visual": {"canvas": None, "alpha": "allowed", "min_margin": 0, "baseline_min_ratio": None, "pivot": "none", "pivot_drift_limit": None}},
    "ui": {"animated": False, "visual": {"canvas": None, "alpha": "allowed", "min_margin": 0, "baseline_min_ratio": None, "pivot": "none", "pivot_drift_limit": None}},
}


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    result = dict(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def resolve_profile(manifest: dict[str, Any]) -> dict[str, Any]:
    asset_class = str(manifest.get("asset_class", "character"))
    base = dict(PROFILES.get(asset_class, PROFILES["character"]))
    profile = deep_merge(base, manifest.get("validation_profile", {}))
    profile["asset_class"] = asset_class
    return profile
