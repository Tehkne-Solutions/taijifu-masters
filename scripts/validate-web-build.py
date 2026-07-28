#!/usr/bin/env python3
"""Valida o pacote Web exportado pelo Godot antes do deploy."""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def fail(message: str) -> None:
    print(f"[taijifu-web] ERRO: {message}", file=sys.stderr)
    raise SystemExit(1)


def first_match(root: Path, patterns: tuple[str, ...]) -> Path | None:
    for pattern in patterns:
        matches = sorted(root.glob(pattern))
        if matches:
            return matches[0]
    return None


def main() -> None:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "web-build").resolve()
    if not output.is_dir():
        fail(f"diretório de saída inexistente: {output}")

    index = output / "index.html"
    if not index.is_file():
        fail("index.html não foi gerado")

    wasm = first_match(output, ("*.wasm",))
    pack = first_match(output, ("*.pck",))
    runtime_js = first_match(output, ("index.js", "*.js"))
    service_worker = first_match(output, ("*.service.worker.js", "*service*worker*.js"))
    manifest = first_match(output, ("*.manifest.json", "manifest.json", "*.webmanifest"))
    offline = first_match(output, ("*.offline.html", "offline.html"))
    shell_css = output / "taijifu-web-shell.css"
    shell_js = output / "taijifu-web-shell.js"
    menu_css = output / "taijifu-web-menu.css"
    menu_js = output / "taijifu-web-menu.js"
    gamepad_js = output / "taijifu-gamepad-web.js"
    mastery_js = output / "taijifu-controller-mastery-web.js"
    ghost_js = output / "taijifu-input-ghost-mastery-web.js"

    required = {
        "WebAssembly": wasm,
        "pacote PCK": pack,
        "runtime JavaScript": runtime_js,
        "service worker da PWA": service_worker,
        "manifesto da PWA": manifest,
        "página offline": offline,
        "estilos responsivos": shell_css if shell_css.is_file() else None,
        "runtime do shell Web": shell_js if shell_js.is_file() else None,
        "estilos do menu Web": menu_css if menu_css.is_file() else None,
        "runtime do menu Web": menu_js if menu_js.is_file() else None,
        "painel Web de gamepads": gamepad_js if gamepad_js.is_file() else None,
        "editor Web de maestria": mastery_js if mastery_js.is_file() else None,
        "painel Web de fantasma e certificações": ghost_js if ghost_js.is_file() else None,
    }
    missing = [label for label, path in required.items() if path is None]
    if missing:
        fail("artefatos ausentes: " + ", ".join(missing))

    assert wasm is not None
    assert pack is not None
    assert runtime_js is not None
    assert service_worker is not None
    assert manifest is not None
    assert offline is not None

    if wasm.stat().st_size < 100_000:
        fail(f"arquivo WASM anormalmente pequeno: {wasm.stat().st_size} bytes")
    if pack.stat().st_size < 1_000:
        fail(f"arquivo PCK anormalmente pequeno: {pack.stat().st_size} bytes")
    if shell_css.stat().st_size < 2_000:
        fail("folha de estilos responsiva está incompleta")
    if shell_js.stat().st_size < 4_000:
        fail("runtime do shell Web está incompleto")
    if menu_css.stat().st_size < 3_000:
        fail("folha de estilos do menu Web está incompleta")
    if menu_js.stat().st_size < 12_000:
        fail("runtime avançado do menu Web está incompleto")
    if gamepad_js.stat().st_size < 10_000:
        fail("painel Web de gamepads está incompleto")
    if mastery_js.stat().st_size < 14_000:
        fail("editor Web de maestria está incompleto")
    if ghost_js.stat().st_size < 12_000:
        fail("painel Web de fantasma e certificações está incompleto")

    html = index.read_text(encoding="utf-8", errors="replace")
    for asset in (wasm, pack, runtime_js, shell_css, shell_js, menu_css, menu_js, gamepad_js, mastery_js, ghost_js):
        if asset.name not in html:
            fail(f"index.html não referencia {asset.name}")
    if "<canvas" not in html.lower():
        fail("index.html não contém o canvas do Godot")

    required_html_markers = (
        "TAIJIFU_WEB_SHELL_HEAD",
        "TAIJIFU_WEB_SHELL_BODY",
        "TAIJIFU_GAMEPAD_WEB",
        "TAIJIFU_CONTROLLER_MASTERY_WEB",
        "TAIJIFU_INPUT_GHOST_MASTERY_WEB",
        'id="taijifu-shell"',
        'id="taijifu-enter"',
        'id="taijifu-menu"',
        'id="taijifu-tutorial-open"',
        'id="taijifu-settings-open"',
        'id="taijifu-web-dialog"',
        'id="taijifu-tutorial-view"',
        'id="taijifu-settings-view"',
        'id="taijifu-setting-contrast"',
        'id="taijifu-setting-touch-scale"',
        'id="taijifu-touch-controls"',
        'data-key="KeyA"',
        'data-key="KeyF"',
        'id="taijifu-fullscreen"',
    )
    for marker in required_html_markers:
        if marker not in html:
            fail(f"index.html não contém o marcador Web obrigatório: {marker}")

    shell_source = shell_js.read_text(encoding="utf-8", errors="replace")
    for marker in ("keyDefinition", "taijifu:input", "dataset.activeCode", "releaseAllKeys"):
        if marker not in shell_source:
            fail(f"runtime touch não contém o contrato obrigatório: {marker}")

    menu_source = menu_js.read_text(encoding="utf-8", errors="replace")
    for marker in (
        "taijifuGodotSetPaused",
        "taijifuGodotApplyBindings",
        "keyboardBindings",
        "taijifu-remap-grid",
        "taijifu-practice",
        "practiceCompleted",
        "p1_swap: 'KeyT'",
    ):
        if marker not in menu_source:
            fail(f"menu Web não contém o contrato avançado: {marker}")

    gamepad_source = gamepad_js.read_text(encoding="utf-8", errors="replace")
    for marker in (
        "taijifuGamepadExperienceCommand",
        "taijifu-gamepad-web-panel",
        "response_curve",
        "trigger_threshold",
        "start_fundamentals",
        "start_advanced",
        "requestAnimationFrame(pollCapture)",
    ):
        if marker not in gamepad_source:
            fail(f"painel de gamepad não contém o contrato obrigatório: {marker}")

    mastery_source = mastery_js.read_text(encoding="utf-8", errors="replace")
    for marker in (
        "taijifuControllerMasteryCommand",
        "taijifu-controller-mastery-panel",
        "taijifu-curve-svg",
        "set_curve",
        "set_triggers",
        "set_cancel",
        "start_dojo",
        "curve_points",
        "consistency_ms",
        "pointermove",
    ):
        if marker not in mastery_source:
            fail(f"editor de maestria não contém o contrato obrigatório: {marker}")

    ghost_source = ghost_js.read_text(encoding="utf-8", errors="replace")
    for marker in (
        "taijifuGhostMasteryCommand",
        "taijifu-input-ghost-panel",
        "start_recording",
        "stop_recording",
        "play_best",
        "taijifu-ghost-live",
        "renderComparison",
        "renderCertifications",
        "renderChallenges",
        "weapon_mastery",
    ):
        if marker not in ghost_source:
            fail(f"painel de fantasma não contém o contrato obrigatório: {marker}")

    manifest_data = json.loads(manifest.read_text(encoding="utf-8"))
    if manifest_data.get("display") != "standalone":
        fail("manifesto PWA não está em modo standalone")
    if manifest_data.get("orientation") != "landscape":
        fail("manifesto PWA não exige orientação paisagem")
    if manifest_data.get("lang") != "pt-BR":
        fail("manifesto PWA não está identificado como pt-BR")

    metadata = {
        "product": "Taijifu Masters",
        "publisher": "Tehkné Solutions",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git_sha": os.environ.get("VERCEL_GIT_COMMIT_SHA")
        or os.environ.get("GITHUB_SHA")
        or "local",
        "web_experience": {
            "responsive_shell": True,
            "touch_controls": True,
            "orientation_guard": True,
            "fullscreen": True,
            "pwa_install": True,
            "native_web_menu": True,
            "adaptive_tutorial": True,
            "accessibility_preferences": True,
            "persistent_control_settings": True,
            "godot_pause_bridge": True,
            "keyboard_remapping": True,
            "dynamic_touch_bindings": True,
            "in_arena_practice": True,
            "gamepad_web_panel": True,
            "analog_response_curves": True,
            "trigger_calibration": True,
            "combat_haptics": True,
            "advanced_combat_dojo": True,
            "controller_guid_profiles": True,
            "visual_curve_editor": True,
            "free_trigger_mapping": True,
            "parry_cancel_windows": True,
            "combo_metrics": True,
            "input_recording": True,
            "ghost_playback": True,
            "attempt_comparison": True,
            "technique_challenges": True,
            "style_mastery": True,
            "tai_ji_fu_certifications": True,
            "weapon_mastery_bridge": True,
        },
        "files": {
            "index": index.name,
            "wasm": wasm.name,
            "pack": pack.name,
            "runtime": runtime_js.name,
            "service_worker": service_worker.name,
            "manifest": manifest.name,
            "offline": offline.name,
            "shell_css": shell_css.name,
            "shell_js": shell_js.name,
            "menu_css": menu_css.name,
            "menu_js": menu_js.name,
            "gamepad_js": gamepad_js.name,
            "mastery_js": mastery_js.name,
            "ghost_js": ghost_js.name,
        },
        "sizes": {
            "wasm_bytes": wasm.stat().st_size,
            "pack_bytes": pack.stat().st_size,
            "shell_css_bytes": shell_css.stat().st_size,
            "shell_js_bytes": shell_js.stat().st_size,
            "menu_css_bytes": menu_css.stat().st_size,
            "menu_js_bytes": menu_js.stat().st_size,
            "gamepad_js_bytes": gamepad_js.stat().st_size,
            "mastery_js_bytes": mastery_js.stat().st_size,
            "ghost_js_bytes": ghost_js.stat().st_size,
        },
    }
    (output / "build-info.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    print("[taijifu-web] Artefatos validados:")
    for label, path in required.items():
        assert path is not None
        print(f"  - {label}: {path.name} ({path.stat().st_size} bytes)")
    print("[taijifu-web] UX Web: gravação, fantasma, comparação, desafios, certificações, gamepads, pausa e touch aprovados estruturalmente")


if __name__ == "__main__":
    main()
