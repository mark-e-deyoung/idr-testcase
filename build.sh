#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/delphi"
OUT="$ROOT/build/win32"
DCU="$ROOT/build/dcu"
LOG="$ROOT/build/logs"
RESOUT="$ROOT/build/res"

ACTION="${1:-build}"

case "$ACTION" in
  clean|--clean)
    echo "Cleaning build artifacts under $ROOT/build"
    # If this is a git checkout, reset tracked build/ files to HEAD
    # so the prebuilt fixtures (EXE/DLL/DCU/RES) are restored.
    if command -v git >/dev/null 2>&1; then
      if git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$ROOT" restore build || true
      fi
    fi
    # Drop untracked IDR CLI logs/exports entirely.
    rm -rf "$ROOT/build/idr-cli"
    exit 0
    ;;
  build|--build|"")
    # Default action: build
    ;;
  *)
    echo "Usage: $0 [build|clean]"
    echo "  build (default): compile Delphi binaries"
    echo "  clean: remove build outputs under build/"
    exit 1
    ;;
esac

mkdir -p "$OUT" "$DCU" "$LOG" "$RESOUT"

# ---------------------------------------------------------------------------
# Containerized borland-toolchains build (preferred)
# ---------------------------------------------------------------------------

if [[ ! -x "$ROOT/scripts/build-binaries.sh" ]]; then
  echo "ERROR: missing build helper at $ROOT/scripts/build-binaries.sh" >&2
  exit 1
fi

"$ROOT/scripts/build-binaries.sh"
