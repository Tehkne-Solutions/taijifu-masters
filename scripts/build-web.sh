#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_RELEASE="${GODOT_VERSION}-${GODOT_CHANNEL}"
CACHE_ROOT="${GODOT_CACHE_DIR:-${ROOT_DIR}/.cache/godot/${GODOT_RELEASE}}"
GODOT_BIN="${GODOT_BIN:-${CACHE_ROOT}/godot}"
OUTPUT_DIR="${WEB_OUTPUT_DIR:-${ROOT_DIR}/web-build}"
XDG_DATA_HOME_VALUE="${XDG_DATA_HOME:-${HOME}/.local/share}"
TEMPLATE_DIR="${GODOT_TEMPLATE_DIR:-${XDG_DATA_HOME_VALUE}/godot/export_templates/${GODOT_VERSION}.${GODOT_CHANNEL}}"
EDITOR_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"

log() { printf '\n[taijifu-web] %s\n' "$*"; }
download() { local url="$1" destination="$2"; mkdir -p "$(dirname "${destination}")"; curl --fail --location --retry 3 --retry-delay 2 --output "${destination}" "${url}"; }
install_editor() {
  [[ -x "${GODOT_BIN}" ]] && return
  log "Baixando Godot ${GODOT_VERSION} ${GODOT_CHANNEL}"
  mkdir -p "${CACHE_ROOT}"
  local archive="${CACHE_ROOT}/godot-editor.zip"
  download "${EDITOR_URL}" "${archive}"
  unzip -q -o "${archive}" -d "${CACHE_ROOT}"
  local extracted
  extracted="$(find "${CACHE_ROOT}" -maxdepth 1 -type f -name 'Godot_*linux.x86_64' | head -n 1)"
  [[ -n "${extracted}" ]] || { echo "Executável do Godot não encontrado." >&2; exit 1; }
  mv "${extracted}" "${GODOT_BIN}"; chmod +x "${GODOT_BIN}"
}
install_templates() {
  [[ -f "${TEMPLATE_DIR}/web_release.zip" ]] && return
  log "Instalando templates oficiais de exportação"
  local archive="${CACHE_ROOT}/export-templates.tpz" stage="${CACHE_ROOT}/templates-stage"
  download "${TEMPLATES_URL}" "${archive}"
  rm -rf "${stage}"; mkdir -p "${stage}" "${TEMPLATE_DIR}"
  unzip -q -o "${archive}" -d "${stage}"
  local web_template
  web_template="$(find "${stage}" -type f -name 'web_release.zip' | head -n 1)"
  [[ -n "${web_template}" ]] || { echo "Template web_release.zip não encontrado." >&2; exit 1; }
  cp -a "$(dirname "${web_template}")/." "${TEMPLATE_DIR}/"
}

install_editor
install_templates
log "Godot detectado: $("${GODOT_BIN}" --version)"
log "Importando recursos"
"${GODOT_BIN}" --headless --editor --path "${ROOT_DIR}" --quit
log "Exportando preset Web para ${OUTPUT_DIR}"
rm -rf "${OUTPUT_DIR}"; mkdir -p "${OUTPUT_DIR}"
"${GODOT_BIN}" --headless --verbose --path "${ROOT_DIR}" --export-release "Web" "${OUTPUT_DIR}/index.html"
log "Preparando manifesto, service worker e modo offline"
python3 "${ROOT_DIR}/scripts/prepare-web-pwa.py" "${OUTPUT_DIR}"
log "Injetando configuração visual de gamepads"
python3 "${ROOT_DIR}/scripts/inject-gamepad-web.py" "${OUTPUT_DIR}"
log "Injetando editor visual de curvas e dojo de combos"
python3 "${ROOT_DIR}/scripts/inject-controller-mastery-web.py" "${OUTPUT_DIR}"
log "Injetando gravação, fantasma e certificações"
python3 "${ROOT_DIR}/scripts/inject-input-ghost-mastery-web.py" "${OUTPUT_DIR}"
log "Injetando compartilhamento de fantasmas e desafios"
python3 "${ROOT_DIR}/scripts/inject-ghost-sharing-web.py" "${OUTPUT_DIR}"
log "Injetando biblioteca local de fantasmas"
python3 "${ROOT_DIR}/scripts/inject-ghost-library-web.py" "${OUTPUT_DIR}"
log "Injetando placar da corrida contra fantasmas"
python3 "${ROOT_DIR}/scripts/inject-ghost-race-web.py" "${OUTPUT_DIR}"
log "Injetando histórico das corridas contra fantasmas"
python3 "${ROOT_DIR}/scripts/inject-ghost-race-history-web.py" "${OUTPUT_DIR}"
log "Injetando séries contra fantasmas"
python3 "${ROOT_DIR}/scripts/inject-ghost-race-series-web.py" "${OUTPUT_DIR}"
log "Validando artefatos gerados"
python3 "${ROOT_DIR}/scripts/validate-web-build.py" "${OUTPUT_DIR}"
log "Build Web concluído"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -printf '%f\t%k KB\n' | sort