#!/usr/bin/env bash
set -euo pipefail

# package-installer.sh
#
# Packages the built IdrTest binaries into an Inno Setup installer.
# Uses the containerized innosetup-packager from borland-toolchains.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
BIN_DIR="${BUILD_DIR}/win32"
INSTALLER_DIR="${BUILD_DIR}/installer"
DIST_DIR="${INSTALLER_DIR}/dist"

# Prefer an explicit toolchain checkout (its local directory name may vary).
# Keep the historical sibling checkout default for existing installations.
IS_PACKAGER="${INNOSETUP_PACKAGER:-}"
if [[ -z "${IS_PACKAGER}" ]]; then
  TOOLCHAIN_ROOT="${BORLAND_TOOLCHAIN_ROOT:-${ROOT_DIR}/../borland-toolchains}"
  IS_PACKAGER="${TOOLCHAIN_ROOT%/}/scripts/innosetup-packager.sh"
fi
if [[ "${IS_PACKAGER}" == */* && "${IS_PACKAGER}" != /* ]]; then
  IS_PACKAGER="${ROOT_DIR}/${IS_PACKAGER}"
fi

if [[ ! -x "${IS_PACKAGER}" ]]; then
  echo "ERROR: innosetup-packager.sh not found at ${IS_PACKAGER}" >&2
  exit 1
fi

APP_NAME="IdrTestcase"
APP_VERSION="1.1"
OUTPUT_BASE="IdrTestcase-Setup"
SRC_DIR="${INSTALLER_DIR}/src"
ISS_PATH="${INSTALLER_DIR}/${APP_NAME}.iss"
INSTALLER_PATH="${DIST_DIR}/${OUTPUT_BASE}.exe"

# Package only already produced, rights-cleared inputs in an owned disposable
# workcell. Refuse existing staged files and installers instead of deleting them.
for parent in "${BUILD_DIR}" "${BIN_DIR}" "${INSTALLER_DIR}" "${DIST_DIR}"; do
  if [[ -L "${parent}" ]]; then
    echo "IDR_PACKAGE_REFUSED reason=symlinked_parent action=none" >&2
    exit 2
  fi
done
for item in "${SRC_DIR}" "${ISS_PATH}" "${INSTALLER_PATH}"; do
  if [[ -e "${item}" || -L "${item}" ]]; then
    echo "IDR_PACKAGE_REFUSED reason=existing_output action=none" >&2
    exit 2
  fi
done
for artifact in IdrTestGui.exe IdrTestConsole.exe IdrTestDll.dll; do
  if [[ ! -f "${BIN_DIR}/${artifact}" || -L "${BIN_DIR}/${artifact}" ]]; then
    echo "IDR_PACKAGE_REFUSED reason=missing_or_symlinked_input action=none" >&2
    exit 2
  fi
done

mkdir -p "${INSTALLER_DIR}" "${DIST_DIR}"
mkdir "${SRC_DIR}" || { echo "IDR_PACKAGE_REFUSED reason=staging_create_failed action=none" >&2; exit 2; }
for artifact in IdrTestGui.exe IdrTestConsole.exe IdrTestDll.dll; do
  cp -- "${BIN_DIR}/${artifact}" "${SRC_DIR}/${artifact}"
done

cat > "${ISS_PATH}" <<EOF
[Setup]
AppName=${APP_NAME}
AppVersion=${APP_VERSION}
DefaultDirName={pf}\\${APP_NAME}
OutputDir=dist
OutputBaseFilename=${OUTPUT_BASE}
Compression=lzma2
SolidCompression=yes
DisableReadyMemo=yes
PrivilegesRequired=admin

[Files]
Source: "src\\IdrTestGui.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "src\\IdrTestConsole.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "src\\IdrTestDll.dll"; DestDir: "{app}"; Flags: ignoreversion
EOF

echo "Building installer with an already admitted packager image..."
pushd "${INSTALLER_DIR}" >/dev/null

# No implicit image-build. Image provisioning is a separately admitted operation.
# Compile
"${IS_PACKAGER}" compile "${APP_NAME}.iss" --payload-image --dist "dist"

popd >/dev/null

echo "Installer created at: ${DIST_DIR}/${OUTPUT_BASE}.exe"
