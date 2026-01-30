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
rm -f "${BIN_DIR}"/*.exe "${BIN_DIR}"/*.dll


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
  local kind="$3"
  local log="${LOG_DIR}/${stem}.log"
  
  # The wrapper mounts the current dir as /work. 
  # We run from ROOT_DIR so we can direct output to build/win32 easily.
  local dpr_path="delphi/${dpr}"

  echo "Building ${stem} (${kind}) from ${dpr_path} ..."

  pushd "${ROOT_DIR}" >/dev/null

  # Wrapper runs from project dir (delphi/).
  # We use a relative output dir "build/win32" which ends up as delphi/build/win32
  # due to wrapper constraints/behavior.
  if ! "${DELPHI7_TOOLCHAIN}" compile --kind "${kind}" --out "build/win32" "${dpr_path}" >"${log}" 2>&1; then
      echo "ERROR: build failed for ${dpr}; see ${log}" >&2
      exit 1
  fi
  
  popd >/dev/null

  # Move artifact from delphi/build/win32 to build/win32
  # The wrapper effectively put it in delphi/build/win32
  local generated_artifact="${DELPHI_DIR}/build/win32/${stem}.${kind}"
  
  if [[ ! -f "${generated_artifact}" ]]; then
      echo "ERROR: generated artifact ${generated_artifact} not found!" >&2
      exit 1
  fi

  mv "${generated_artifact}" "${BIN_DIR}/"

  if [[ ! -f "${BIN_DIR}/${stem}.${kind}" ]]; then
      echo "ERROR: expected output ${BIN_DIR}/${stem}.${kind} not found!" >&2
      ls -lR "${BUILD_DIR}"
      exit 1
  fi

  echo "OK: built ${BIN_DIR}/${stem}.${kind}"
}

build_one "IdrTestConsole.dpr" "IdrTestConsole" "exe"
build_one "IdrTestGui.dpr"     "IdrTestGui"     "exe"
build_one "IdrTestDll.dpr"     "IdrTestDll"     "dll"

echo "All IdrTest binaries built into ${BIN_DIR}"