#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.3}"
GODOT_CHANNEL="${GODOT_CHANNEL:-stable}"
GODOT_RELEASE="${GODOT_VERSION}-${GODOT_CHANNEL}"
CACHE_ROOT="${GODOT_CACHE_DIR:-${ROOT_DIR}/.cache/godot/${GODOT_RELEASE}}"
GODOT_BIN="${GODOT_BIN:-${CACHE_ROOT}/godot}"
OUTPUT_DIR="${WINDOWS_OUTPUT_DIR:-${ROOT_DIR}/windows-build}"
DIST_DIR="${FIRST_PLAYABLE_DIST_DIR:-${ROOT_DIR}/dist}"
ZIP_NAME="${FIRST_PLAYABLE_WINDOWS_ZIP:-Taijifu-Masters-First-Playable-Windows-x86_64.zip}"
XDG_DATA_HOME_VALUE="${XDG_DATA_HOME:-${HOME}/.local/share}"
TEMPLATE_DIR="${GODOT_TEMPLATE_DIR:-${XDG_DATA_HOME_VALUE}/godot/export_templates/${GODOT_VERSION}.${GODOT_CHANNEL}}"
EDITOR_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz"
EXE_PATH="${OUTPUT_DIR}/Taijifu-Masters-First-Playable.exe"

log() { printf '\n[taijifu-windows] %s\n' "$*"; }
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
  mv "${extracted}" "${GODOT_BIN}"
  chmod +x "${GODOT_BIN}"
}

install_templates() {
  [[ -f "${TEMPLATE_DIR}/windows_release_x86_64.exe" ]] && return
  log "Instalando templates oficiais de exportação"
  local archive="${CACHE_ROOT}/export-templates.tpz" stage="${CACHE_ROOT}/templates-stage"
  download "${TEMPLATES_URL}" "${archive}"
  rm -rf "${stage}"
  mkdir -p "${stage}" "${TEMPLATE_DIR}"
  unzip -q -o "${archive}" -d "${stage}"
  local windows_template
  windows_template="$(find "${stage}" -type f -name 'windows_release_x86_64.exe' | head -n 1)"
  [[ -n "${windows_template}" ]] || { echo "Template windows_release_x86_64.exe não encontrado." >&2; exit 1; }
  cp -a "$(dirname "${windows_template}")/." "${TEMPLATE_DIR}/"
}

install_editor
install_templates
log "Godot detectado: $("${GODOT_BIN}" --version)"
log "Importando recursos"
"${GODOT_BIN}" --headless --editor --path "${ROOT_DIR}" --quit

log "Exportando preset Windows Desktop"
rm -rf "${OUTPUT_DIR}" "${DIST_DIR}/${ZIP_NAME}" "${DIST_DIR}/${ZIP_NAME}.sha256"
mkdir -p "${OUTPUT_DIR}" "${DIST_DIR}"
"${GODOT_BIN}" --headless --verbose --path "${ROOT_DIR}" --export-release "Windows Desktop" "${EXE_PATH}"

log "Validando executável"
test -s "${EXE_PATH}"
file "${EXE_PATH}" | tee "${OUTPUT_DIR}/executable-type.txt"
grep -Eq 'PE32|MS Windows' "${OUTPUT_DIR}/executable-type.txt"

cat > "${OUTPUT_DIR}/LEIA-ME.txt" <<'EOF'
TAIJIFU MASTERS — FIRST PLAYABLE

1. Execute Taijifu-Masters-First-Playable.exe.
2. Selecione a dificuldade da IA.
3. Escolha JOGAR CONTRA IA.
4. Controle Lian Wu e derrote o Rival de Treino.

Controles principais:
A/D mover | W saltar | F atacar | Q esquivar | R defender | Esc pausar

Assinatura: Tehkné Solutions
EOF

log "Gerando manifesto rastreável"
python3 "${ROOT_DIR}/scripts/create-first-playable-build-manifest.py" \
  --platform windows \
  --output-dir "${OUTPUT_DIR}" \
  --project-root "${ROOT_DIR}"

log "Empacotando ZIP Windows"
(
  cd "${OUTPUT_DIR}"
  zip -q -9 -r "${DIST_DIR}/${ZIP_NAME}" .
)
(
  cd "${DIST_DIR}"
  sha256sum "${ZIP_NAME}" | tee "${ZIP_NAME}.sha256"
)

log "Build Windows concluído"
find "${OUTPUT_DIR}" -maxdepth 1 -type f -printf '%f\t%k KB\n' | sort
ls -lh "${DIST_DIR}/${ZIP_NAME}" "${DIST_DIR}/${ZIP_NAME}.sha256"
