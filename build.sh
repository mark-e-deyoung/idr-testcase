#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/delphi"
OUT="$ROOT/build/win32"
DCU="$ROOT/build/dcu"
LOG="$ROOT/build/logs"
RESOUT="$ROOT/build/res"

mkdir -p "$OUT" "$DCU" "$LOG" "$RESOUT"

# ---------------------------------------------------------------------------
# Bottle / Wine integration
# ---------------------------------------------------------------------------

# Default Bottles bottle name; override with BOTTLE_NAME if desired.
BOTTLE_NAME="${BOTTLE_NAME:-Delphi7-Win32}"

# Helper that prefers Bottles CLI; falls back to system wine if needed.
bottles_cli() {
  if command -v bottles-cli >/dev/null 2>&1; then
    bottles-cli "$@"
  elif command -v flatpak >/dev/null 2>&1; then
    flatpak run --command=bottles-cli com.usebottles.bottles "$@"
  else
    return 1
  fi
}

USE_BOTTLES=0
if bottles_cli --help >/dev/null 2>&1; then
  USE_BOTTLES=1
fi

if [[ "$USE_BOTTLES" -eq 0 ]]; then
  if ! command -v wine >/dev/null 2>&1; then
    echo "ERROR: Neither Bottles CLI nor system wine is available."
    echo "  - Install Bottles CLI (bottles-cli / Flatpak) or"
    echo "  - Install wine and re-run this script."
    exit 1
  fi
fi

# Map a Unix path to the Z: drive used by Wine/Bottles.
to_win_path() {
  local unix_path="$1"
  if [[ "$unix_path" != /* ]]; then
    unix_path="$PWD/$unix_path"
  fi
  printf 'Z:%s\n' "${unix_path//\//\\}"
}

run_tool() {
  local exe="$1"
  shift
  if [[ "$USE_BOTTLES" -eq 1 ]]; then
    echo "Running via Bottles: $exe $*"
    # Use Bottles' `run` subcommand with an explicit executable.
    # Additional arguments are passed after `--` and received by the Windows tool.
    bottles_cli run -b "$BOTTLE_NAME" --executable "$exe" -- "$@"
  else
    echo "Running via system wine: $exe $*"
    wine "$exe" "$@"
  fi
}

# Windows paths to Delphi tools inside the bottle.
: "${DCC32_WIN:=C:\\Program Files\\Borland\\Delphi7\\Bin\\DCC32.EXE}"
: "${BRCC32_WIN:=C:\\Program Files\\Borland\\Delphi7\\Bin\\BRCC32.EXE}"

echo "Using bottle name: $BOTTLE_NAME"
echo "Using DCC32_WIN:   $DCC32_WIN"
echo "Using BRCC32_WIN:  $BRCC32_WIN"

build_res() {
  local rc="$1"
  local outres="$2"
  echo "==> brcc32 $(basename "$rc") -> $(basename "$outres")"
  (
    cd "$SRC"
    # brcc32 writes .res next to .rc by default; use -fo to control output.
    # Use Z: mapping so the bottle can see host paths.
    run_tool "$BRCC32_WIN" -r \
      -fo"$(to_win_path "$outres")" \
      "$(to_win_path "$rc")"
  ) |& tee "$LOG/brcc32-$(basename "$rc").log"
  [[ -f "$outres" ]] || { echo "ERROR: expected $outres"; exit 1; }
}

compile() {
  local proj="$1"
  local name="$2"
  echo "==> Building $name"
  (
    cd "$SRC"
    # -B: build all units
    # -Q: quiet (less noisy)
    # -E: EXE/DLL output dir
    # -N: DCU output dir
    run_tool "$DCC32_WIN" -B -Q \
      "-E$(to_win_path "$OUT")" \
      "-N$(to_win_path "$DCU")" \
      "$proj"
  ) |& tee "$LOG/${name}.log"
}

# Build project .res files from .rc (keeps CLI builds deterministic outside the IDE)
build_res "$SRC/IdrTestConsole.rc" "$RESOUT/IdrTestConsole.res"
build_res "$SRC/IdrTestGui.rc"     "$RESOUT/IdrTestGui.res"
build_res "$SRC/IdrTestDll.rc"     "$RESOUT/IdrTestDll.res"

# Copy the .res into the delphi source folder where {$R <name>.res} expects it
cp -f "$RESOUT/IdrTestConsole.res" "$SRC/IdrTestConsole.res"
cp -f "$RESOUT/IdrTestGui.res"     "$SRC/IdrTestGui.res"
cp -f "$RESOUT/IdrTestDll.res"     "$SRC/IdrTestDll.res"

compile "IdrTestConsole.dpr" "IdrTestConsole"
compile "IdrTestGui.dpr"     "IdrTestGui"
compile "IdrTestDll.dpr"     "IdrTestDll"

echo
echo "Build complete. Outputs:"
ls -la "$OUT" | sed 's/^/  /'
