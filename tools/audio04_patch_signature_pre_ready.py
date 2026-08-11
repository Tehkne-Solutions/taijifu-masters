#!/usr/bin/env python3
from pathlib import Path

PATH = Path("scripts/vertical_slice/first_playable_audio_director.gd")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"AUDIO04_SIGNATURE_PATCH=BLOCKED {label} count={count}")
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding="utf-8")
    text = replace_once(
        text,
        "const AMBIENCE_SLEW_PER_SECOND := 0.72\n",
        "const AMBIENCE_SLEW_PER_SECOND := 0.72\nconst MASTER_CEILING_FALLBACK := 0.86\n",
        "fallback_constant",
    )
    text = replace_once(
        text,
        "func presentation_signature() -> Dictionary:\n\treturn {\n",
        "func presentation_signature() -> Dictionary:\n\tvar master_ceiling := _mix_policy.master_ceiling() if _mix_policy != null else MASTER_CEILING_FALLBACK\n\treturn {\n",
        "signature_fallback",
    )
    text = replace_once(
        text,
        '"master_ceiling": _mix_policy.master_ceiling(),',
        '"master_ceiling": master_ceiling,',
        "signature_value",
    )
    PATH.write_text(text, encoding="utf-8")
    print("AUDIO04_SIGNATURE_PATCH=PASS")
    print("SIGNATURE=Tehkné Solutions")


if __name__ == "__main__":
    main()
