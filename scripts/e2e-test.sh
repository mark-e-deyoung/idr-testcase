#!/usr/bin/env bash
set -euo pipefail

# e2e-test.sh
#
# Builds, packages, and tests IdrTestcase in a disposable WineBot container.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Prerequisites
need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing $1" >&2; exit 2; }; }
need docker

# Config
APP_NAME="IdrTestcase"
INSTALLER_PATH="${ROOT_DIR}/build/installer/dist/${APP_NAME}-Setup.exe"
TEST_PREFIX="/tmp/idr-e2e"
TEST_IMAGE="delphi7-toolchain:latest"

echo "=== Step 1: Building Binaries ==="
"${SCRIPT_DIR}/build-binaries.sh"

echo "=== Step 2: Packaging Installer ==="
"${SCRIPT_DIR}/package-installer.sh"

if [[ ! -f "${INSTALLER_PATH}" ]]; then
    echo "ERROR: Installer not found at ${INSTALLER_PATH}"
    exit 1
fi

echo "=== Step 3: Running E2E Test in Container ==="

INSTALLER_DIR="$(dirname "${INSTALLER_PATH}")"
INSTALLER_NAME="$(basename "${INSTALLER_PATH}")"

# Create a temporary test script to run inside the container
TEST_SCRIPT_HOST="${ROOT_DIR}/build/run_test_in_container.sh"

# Use quoted EOF to prevent host expansion. All vars must be passed as env vars.
cat > "${TEST_SCRIPT_HOST}" <<'EOF'
#!/bin/bash
set -euo pipefail
# WINEPREFIX and other vars are passed from docker env

echo "--- Setting up Wine ---"
mkdir -p "${WINEPREFIX}"
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
# Wait for Xvfb
sleep 2

wineboot -u
# Wait for wineboot
wineserver -w || true

echo "--- Installing ${APP_NAME} ---"
# Map the /mnt/installer volume to a drive letter or access directly
# Z: is typically mapped to /
INSTALLER_PATH_WIN="Z:\\mnt\\installer\\${INSTALLER_NAME}"
wine "${INSTALLER_PATH_WIN}" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG='C:\\install.log'

echo "--- Verifying Install ---"
if [ ! -f "${WINEPREFIX}/drive_c/Program Files/${APP_NAME}/IdrTestGui.exe" ]; then
    echo "ERROR: IdrTestGui.exe not found installed."
    echo "Install log tail:"
    tail -n 20 "${WINEPREFIX}/drive_c/install.log" || true
    exit 1
fi

echo "--- Running Console Smoke Test ---"
cd "${WINEPREFIX}/drive_c/Program Files/${APP_NAME}"
if timeout --kill-after=5s 30s wine 'IdrTestConsole.exe' > console.log 2>&1; then
    :
else
    rc=$?
    echo "ERROR: console executable failed (exit ${rc})" >&2
    cat console.log >&2
    exit "${rc}"
fi
echo "Console Output:"
cat console.log
echo "----------------------"
if ! grep -Fq '[IDR_FEATURE:done] console testcase completed' console.log; then
    echo "ERROR: console completion marker missing" >&2
    exit 1
fi

echo "--- Running Automation Test ---"
# Run with /automate flag. It should create C:\Program Files\IdrTestcase\idr_test_artifact.txt
cd "${WINEPREFIX}/drive_c/Program Files/${APP_NAME}"
# Timeout to prevent hanging if logic fails
# The installed application runs only in this disposable container.
# Remove an earlier artifact before the run: existence alone is not completion.
rm -f idr_test_artifact.txt
if timeout --kill-after=5s 30s wine 'IdrTestGui.exe' /automate; then
    :
else
    rc=$?
    echo "ERROR: GUI automation failed (exit ${rc})" >&2
    exit "${rc}"
fi

if [ -f 'idr_debug.txt' ]; then
    echo "--- IDR DEBUG LOG ---"
    cat 'idr_debug.txt'
    echo "---------------------"
fi

if [ -f 'idr_test_artifact.txt' ] && grep -Fxq 'Automated interaction successful.' idr_test_artifact.txt; then
    echo "SUCCESS: fresh automation artifact contains expected completion text."
    cat 'idr_test_artifact.txt'
else
    echo "ERROR: fresh automation completion artifact missing or invalid."
    ls -l
    exit 1
fi

echo "--- Uninstalling ---"
if [ -f 'unins000.exe' ]; then
    wine 'unins000.exe' /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
    wineserver -w || true
else
    echo "ERROR: unins000.exe not found."
    exit 1
fi

echo "--- E2E Test Script Completed ---"
EOF

chmod +x "${TEST_SCRIPT_HOST}"

docker run --rm \
    -v "${INSTALLER_DIR}:/mnt/installer" \
    -v "${TEST_SCRIPT_HOST}:/run_test.sh" \
    -e HOST_UID=\"$(id -u)\" \
    -e HOST_GID=\"$(id -g)\" \
    -e WINEPREFIX="${TEST_PREFIX}" \
    -e WINEARCH="win32" \
    -e APP_NAME="${APP_NAME}" \
    -e INSTALLER_NAME="${INSTALLER_NAME}" \
    --entrypoint bash \
    "${TEST_IMAGE}" \
    /run_test.sh

echo "=== E2E Test Passed ==="