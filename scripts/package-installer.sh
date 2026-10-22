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

mkdir -p "${INSTALLER_DIR}" "${DIST_DIR}"

APP_NAME="IdrTestcase"
APP_VERSION="1.1"
OUTPUT_BASE="IdrTestcase-Setup"

echo "Creating Inno Setup script..."
cat > "${INSTALLER_DIR}/${APP_NAME}.iss" <<EOF
[Setup]
AppName=${APP_NAME}
AppVersion=${APP_VERSION}
DefaultDirName={pf}\\${APP_NAME}
OutputDir=dist
OutputBaseFilename=${OUTPUT_BASE}
Compression=lzma2
SolidCompression=yes
DisableReadyMemo=yes
; Require admin for Program Files
PrivilegesRequired=admin

[Files]
Source: "${BIN_DIR}/IdrTestGui.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "${BIN_DIR}/IdrTestConsole.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "${BIN_DIR}/IdrTestDll.dll"; DestDir: "{app}"; Flags: ignoreversion

[Run]
; No auto-run, we run manually in tests
EOF

echo "Building installer..."

# We need to run the packager from a directory that contains or can access the source files.
# The IS_PACKAGER script mounts the current directory as /work.
# Our source files are in BIN_DIR (absolute path).
# Inno Setup in the container sees /work.
# We should run from INSTALLER_DIR, but the [Files] Source paths are absolute host paths?
# No, Inno Setup running in Wine inside Docker won't see host absolute paths unless mapped.
# 
# Best approach: Copy binaries to INSTALLER_DIR/src so everything is relative.

SRC_DIR="${INSTALLER_DIR}/src"
rm -rf "${SRC_DIR}"
mkdir -p "${SRC_DIR}"
cp "${BIN_DIR}"/* "${SRC_DIR}/"

# Update ISS to use relative paths
cat > "${INSTALLER_DIR}/${APP_NAME}.iss" <<EOF
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

pushd "${INSTALLER_DIR}" >/dev/null

# Build the packager image if needed (idempotent usually)
"${IS_PACKAGER}" image-build

# Compile
"${IS_PACKAGER}" compile "${APP_NAME}.iss" --payload-image --dist "dist"

popd >/dev/null

echo "Installer created at: ${DIST_DIR}/${OUTPUT_BASE}.exe"
