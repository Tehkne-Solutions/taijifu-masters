#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_BIN="${GODOT_BIN:-${ROOT_DIR}/.cache/godot/${GODOT_VERSION}-${GODOT_CHANNEL}/godot}"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/sprint0"

log() {
  printf '\n[sprint0-gate] %s\n' "$*"
}

run_contract() {
  local script_path="$1"
  log "Executando ${script_path}"
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script "${ROOT_DIR}/${script_path}"
}

assert_clean_log() {
  local log_path="$1"
  if grep -E "SCRIPT ERROR: Parse Error|Failed to load script|InputMap action .*doesn't exist" "${log_path}"; then
    echo "Gate falhou: erro estrutural encontrado em ${log_path}" >&2
    exit 1
  fi
}

mkdir -p "${ARTIFACT_DIR}"

log "Gerando e validando o build Web essencial"
bash "${ROOT_DIR}/scripts/build-web.sh"

test -x "${GODOT_BIN}"
test -s "${ROOT_DIR}/web-build/index.html"
test -s "${ROOT_DIR}/web-build/index.wasm"
test -s "${ROOT_DIR}/web-build/index.pck"

run_contract "tests/sprint0_minimal_main_menu_contract.gd"
run_contract "tests/sprint0_single_native_flow_contract.gd"
run_contract "tests/sprint0_minimal_autoloads_contract.gd"
run_contract "tests/tgap/runtime_smoke_test.gd"
run_contract "tests/tgap/runtime_scene_matrix_smoke.gd"
run_contract "tests/first_playable_scene_smoke.gd"

log "Validando importação completa do projeto"
set -o pipefail
"${GODOT_BIN}" --headless --editor --path "${ROOT_DIR}" --quit 2>&1 | tee "${ARTIFACT_DIR}/godot-import.log"
assert_clean_log "${ARTIFACT_DIR}/godot-import.log"

log "SPRINT0_FINAL_GATE_OK"
