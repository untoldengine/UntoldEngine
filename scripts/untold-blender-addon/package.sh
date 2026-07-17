#!/usr/bin/env bash

set -euo pipefail

ADDON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${ADDON_DIR}/.." && pwd)"
BUILD_DIR="${ADDON_DIR}/build"
STAGE_DIR="${BUILD_DIR}/untold_exporter"
ZIP_PATH="${BUILD_DIR}/untold_exporter.zip"

rm -rf "${BUILD_DIR}"
mkdir -p "${STAGE_DIR}/vendor"

cp "${ADDON_DIR}/untold_exporter/__init__.py" "${STAGE_DIR}/__init__.py"
cp "${ADDON_DIR}/untold_exporter/bridge.py" "${STAGE_DIR}/bridge.py"
cp "${ADDON_DIR}/untold_exporter/material_fidelity.py" "${STAGE_DIR}/material_fidelity.py"
cp "${ADDON_DIR}/untold_exporter/object_metadata.py" "${STAGE_DIR}/object_metadata.py"
cp "${ADDON_DIR}/untold_exporter/viewport_overlay.py" "${STAGE_DIR}/viewport_overlay.py"
cp "${SCRIPTS_DIR}/untoldexplorer.py" "${STAGE_DIR}/vendor/untoldexplorer.py"
cp "${SCRIPTS_DIR}/texbake.py" "${STAGE_DIR}/vendor/texbake.py"
cp "${SCRIPTS_DIR}/tilestreamingpartition.py" "${STAGE_DIR}/vendor/tilestreamingpartition.py"

(
  cd "${BUILD_DIR}"
  zip -qr "${ZIP_PATH}" untold_exporter
)

echo "Wrote ${ZIP_PATH}"
