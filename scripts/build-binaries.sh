#!/usr/bin/env bash
set -euo pipefail

# build-binaries.sh
#
# Build the IdrTest console/GUI/DLL binaries using the containerized
# Delphi 7 toolchain from the borland-toolchains project.
#
# Usage:
#   ./scripts/build-binaries.sh
# Environment:
#   - DELPHI7_TOOLCHAIN (optional): path to delphi7-toolchain.sh.
#     If unset, the script expects delphi7-toolchain.sh on PATH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DELPHI_DIR="${ROOT_DIR}/delphi"
BUILD_DIR="${ROOT_DIR}/build"
BIN_DIR="${BUILD_DIR}/win32"
LOG_DIR="${BUILD_DIR}/logs"

mkdir -p "${BIN_DIR}" "${LOG_DIR}"

# Resolve the toolchain wrapper. Prefer an explicit env var, then PATH, then a
# sibling borland-toolchains checkout (common in this workspace layout).
DELPHI7_TOOLCHAIN="${DELPHI7_TOOLCHAIN:-}"
if [[ -z "${DELPHI7_TOOLCHAIN}" ]]; then
  if command -v delphi7-toolchain.sh >/dev/null 2>&1; then
    DELPHI7_TOOLCHAIN="delphi7-toolchain.sh"
  elif [[ -x "${ROOT_DIR}/../borland-toolchains/scripts/delphi7-toolchain.sh" ]]; then
    DELPHI7_TOOLCHAIN="${ROOT_DIR}/../borland-toolchains/scripts/delphi7-toolchain.sh"
  else
    DELPHI7_TOOLCHAIN="delphi7-toolchain.sh"
  fi
fi

# Resolve the toolchain wrapper:
# - If it contains a slash, treat it as a path (relative to ROOT_DIR if needed).
# - Otherwise, treat it as a bare command to be found on PATH.
if [[ "${DELPHI7_TOOLCHAIN}" == */* ]]; then
  if [[ "${DELPHI7_TOOLCHAIN}" != /* ]]; then
    DELPHI7_TOOLCHAIN="${ROOT_DIR}/${DELPHI7_TOOLCHAIN}"
  fi
  if [[ ! -x "${DELPHI7_TOOLCHAIN}" ]]; then
    echo "ERROR: toolchain wrapper not executable at: ${DELPHI7_TOOLCHAIN}" >&2
    exit 2
  fi
else
  if ! command -v "${DELPHI7_TOOLCHAIN}" >/dev/null 2>&1; then
    echo "ERROR: cannot find ${DELPHI7_TOOLCHAIN} on PATH." >&2
    echo "       Install borland-toolchains or set DELPHI7_TOOLCHAIN to its delphi7-toolchain.sh." >&2
    echo "       Example: export DELPHI7_TOOLCHAIN=../borland-toolchains/scripts/delphi7-toolchain.sh" >&2
    exit 2
  fi
fi

build_one() {
  local dpr="$1"
  local stem="$2"
  local log="${LOG_DIR}/${stem}.log"

  echo "Building ${stem} from ${dpr} ..."

  # The delphi7-toolchain wrapper is expected to:
  #   - compile the DPR inside a Docker+Wine container
  #   - place the resulting EXE/DLL under an out/ directory that is
  #     relative to the project root.
  #
  # To keep this script generic, we run the toolchain wrapper from
  # the delphi/ directory and then copy the resulting binary into
  # build/win32/.

  pushd "${DELPHI_DIR}" >/dev/null
  set +e
  "${DELPHI7_TOOLCHAIN}" compile "${dpr}" >"${log}" 2>&1
  local rc=$?
  set -e
  popd >/dev/null

  # Copy the expected binary into build/win32. The exact output path
  # is toolchain-wrapper-specific; by convention we expect:
  #   out/delphi7/<stem>/<stem>.exe or .dll
  #
  # We check both .exe and .dll to cover console/GUI and DLL targets.

  local src_base="${DELPHI_DIR}/out/delphi7/${stem}/${stem}"
  local src=""

  if [ -f "${src_base}.exe" ]; then
    src="${src_base}.exe"
  elif [ -f "${src_base}.dll" ]; then
    src="${src_base}.dll"
  else
    if [[ ${rc} -ne 0 ]]; then
      echo "ERROR: build failed for ${dpr}; see ${log}" >&2
    fi
    echo "ERROR: expected binary not found for ${stem} (looked for ${src_base}.exe/.dll)" >&2
    exit 1
  fi

  if [[ ${rc} -ne 0 ]]; then
    echo "WARNING: toolchain wrapper exited with ${rc} but output was produced for ${stem}." >&2
  fi

  if ! cp "${src}" "${BIN_DIR}/"; then
    echo "ERROR: failed to copy ${src} into ${BIN_DIR}" >&2
    exit 1
  fi

  echo "OK: built ${BIN_DIR}/$(basename "${src}")"
}

build_one "IdrTestConsole.dpr" "IdrTestConsole"
build_one "IdrTestGui.dpr" "IdrTestGui"
build_one "IdrTestDll.dpr" "IdrTestDll"

echo "All IdrTest binaries built into ${BIN_DIR}"
