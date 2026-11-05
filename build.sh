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
    # This repository tracks compiled build artifacts; restoring them can
    # silently discard local changes. There is no safe implicit cleanup.
    echo "IDR_CLEAN_REFUSED reason=unowned_workspace action=none" >&2
    echo "Use a newly created disposable, positively owned workcell for clean builds;" >&2
    echo "remove only that owned workcell via its lifecycle owner, not this script." >&2
    exit 2
    ;;
  clean-plan|--clean-plan)
    # Non-mutating, machine-readable preview for people, automation and agents.
    echo "IDR_CLEAN_PLAN scope=build/ tracked_and_generated=true action=none"
    exit 0
    ;;
  build|--build|"")
    # Default action: build
    ;;
  *)
    echo "Usage: $0 [build|clean|clean-plan]"
    echo "  build (default): compile Delphi binaries"
    echo "  clean: refuses destructive cleanup (exit 2); use an owned workcell"
    echo "  clean-plan: read-only summary (no files changed)"
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
