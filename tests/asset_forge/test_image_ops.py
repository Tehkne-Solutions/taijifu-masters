from __future__ import annotations

import importlib.util
from pathlib import Path

from PIL import Image

MODULE_PATH = Path(__file__).resolve().parents[2] / "tools" / "asset_forge" / "image_ops.py"
spec = importlib.util.spec_from_file_location("image_ops", MODULE_PATH)
image_ops = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(image_ops)


def test_remove_chroma_preserves_subject_and_clears_background():
    image = Image.new("RGBA", (4, 4), (0, 255, 0, 255))
    image.putpixel((2, 2), (23, 105, 194, 255))
    result = image_ops.remove_chroma(image, (0, 255, 0), 8)
    assert result.getpixel((0, 0))[3] == 0
    assert result.getpixel((2, 2))[3] == 255


def test_normalize_canvas_anchors_content_to_pivot():
    image = Image.new("RGBA", (10, 20), (255, 255, 255, 255))
    result = image_ops.normalize_canvas(image, 64, 64, 32, 60, margin=0)
    assert result.size == (64, 64)
    bbox = result.getchannel("A").getbbox()
    assert bbox is not None
    assert bbox[2] <= 64
    assert bbox[3] == 60


def test_split_grid_writes_individual_pngs(tmp_path: Path):
    source = tmp_path / "sheet.png"
    sheet = Image.new("RGBA", (8, 4), (0, 0, 0, 0))
    sheet.paste((255, 0, 0, 255), (0, 0, 4, 4))
    sheet.paste((0, 0, 255, 255), (4, 0, 8, 4))
    sheet.save(source)
    written = image_ops.split_grid(source, tmp_path / "out", 2, 1, "frame_{frame:02d}.png")
    assert len(written) == 2
    assert Image.open(tmp_path / "out/frame_01.png").getpixel((1, 1))[:3] == (255, 0, 0)
    assert Image.open(tmp_path / "out/frame_02.png").getpixel((1, 1))[:3] == (0, 0, 255)


def test_build_atlas_generates_png_and_metadata(tmp_path: Path):
    first = tmp_path / "a.png"
    second = tmp_path / "b.png"
    Image.new("RGBA", (16, 16), (255, 0, 0, 255)).save(first)
    Image.new("RGBA", (16, 16), (0, 0, 255, 255)).save(second)
    output = tmp_path / "atlas.png"
    metadata = tmp_path / "atlas.json"
    report = image_ops.build_atlas([first, second], output, metadata, max_width=64, padding=2)
    assert output.is_file()
    assert metadata.is_file()
    assert len(report["frames"]) == 2
    assert report["schema"] == "taijifu/asset-forge-atlas/v2"
