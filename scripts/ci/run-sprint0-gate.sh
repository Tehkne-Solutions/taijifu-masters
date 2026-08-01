#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_BIN="${GODOT_BIN:-${ROOT_DIR}/.cache/godot/${GODOT_VERSION}-${GODOT_CHANNEL}/godot}"

log() {
  printf '\n[sprint0-gate] %s\n' "$*"
}

run_contract() {
  local script_path="$1"
  log "Executando ${script_path}"
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "${ROOT_DIR}/${script_path}"
}

log "Gerando e validando o build Web essencial"
bash "${ROOT_DIR}/scripts/build-web.sh"

test -x "${GODOT_BIN}"
test -s "${ROOT_DIR}/web-build/index.html"
test -s "${ROOT_DIR}/web-build/index.wasm"
test -s "${ROOT_DIR}/web-build/index.pck"

run_contract "tests/sprint0_minimal_main_menu_contract.gd"
run_contract "tests/sprint0_single_native_flow_contract.gd"
run_contract "tests/sprint0_minimal_autoloads_contract.gd"
run_contract "tests/first_playable_scene_smoke.gd"

log "Validando importação completa do projeto"
"${GODOT_BIN}" --headless --editor --path "${ROOT_DIR}" --quit

log "SPRINT0_FINAL_GATE_OK"
