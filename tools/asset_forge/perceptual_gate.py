#!/usr/bin/env python3
import argparse, hashlib, json
from pathlib import Path
from PIL import Image, ImageChops, ImageStat

SCHEMA = "taijifu/asset-forge-perceptual-report/v1"

def ahash(path: Path, size: int = 16) -> str:
    img = Image.open(path).convert("L").resize((size, size))
    mean = sum(img.getdata()) / (size * size)
    bits = ''.join('1' if px >= mean else '0' for px in img.getdata())
    return f"{int(bits, 2):0{size*size//4}x}"

def distance(a: str, b: str) -> float:
    return (int(a, 16) ^ int(b, 16)).bit_count() / (len(a) * 4)

def run(config_path: Path, strict: bool = False) -> int:
    cfg = json.loads(config_path.read_text(encoding="utf-8"))
    root = Path(cfg["root"])
    files = {item["id"]: root / item["path"] for item in cfg["assets"]}
    missing = [k for k, p in files.items() if not p.is_file()]
    hashes = {k: ahash(p) for k, p in files.items() if p.is_file()}
    comparisons = []
    for pair in cfg.get("comparisons", []):
        a, b = pair["a"], pair["b"]
        if a in hashes and b in hashes:
            d = distance(hashes[a], hashes[b])
            comparisons.append({"a": a, "b": b, "distance": round(d, 6), "threshold": pair["max_distance"], "passed": d <= pair["max_distance"]})
    ready = not missing and all(x["passed"] for x in comparisons)
    report = {"schema": SCHEMA, "pack_id": cfg["pack_id"], "ready": ready, "missing": missing, "comparisons": comparisons}
    out = Path(cfg["report"]); out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 9 if strict and not ready else 0

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("config", type=Path); ap.add_argument("--strict", action="store_true")
    args = ap.parse_args(); raise SystemExit(run(args.config, args.strict))
