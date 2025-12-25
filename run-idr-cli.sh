#!/usr/bin/env bash
set -euo pipefail

WINEPREFIX="${WINEPREFIX:-$HOME/.wine-delphi7}"
export WINEPREFIX

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/build/win32"
LOGROOT="$ROOT/build/idr-cli"
mkdir -p "$LOGROOT"

IDR_EXE="${IDR_EXE:-}"
IDR_HOME="${IDR_HOME:-}"

if [[ -z "$IDR_EXE" && -n "$IDR_HOME" ]]; then
  IDR_EXE="$IDR_HOME/idr.exe"
fi
if [[ -d "$IDR_EXE" ]]; then
  IDR_EXE="$IDR_EXE/idr.exe"
fi
if [[ -z "$IDR_EXE" || ! -f "$IDR_EXE" ]]; then
  echo "ERROR: Set IDR_EXE to the Windows IDR executable, e.g.:"
  echo "  export IDR_EXE=\"$HOME/Tools/IDR/idr.exe\""
  exit 1
fi

# Ensure binaries exist; build if missing
if [[ ! -f "$OUT/IdrTestConsole.exe" || ! -f "$OUT/IdrTestGui.exe" || ! -f "$OUT/IdrTestDll.dll" ]]; then
  echo "Binaries missing — running ./build.sh first."
  "$ROOT/build.sh"
fi

HELP_LOG="$LOGROOT/idr_help.txt"
echo "==> Capturing IDR help output..."
(
  set +e
  wine "$IDR_EXE" "/?" >"$HELP_LOG" 2>&1 && exit 0
  wine "$IDR_EXE" "-h" >"$HELP_LOG" 2>&1 && exit 0
  wine "$IDR_EXE" "--help" >"$HELP_LOG" 2>&1 && exit 0
  exit 0
)
echo "  wrote $HELP_LOG"

try_cmd() {
  local tag="$1"; shift
  local logfile="$LOGROOT/${tag}.log"
  echo "==> $tag"
  echo "CMD: wine \"$IDR_EXE\" $*" | tee "$logfile"
  ( wine "$IDR_EXE" "$@" ) >>"$logfile" 2>&1 || true
  echo "  log: $logfile"
}

BINARIES=(
  "$OUT/IdrTestConsole.exe"
  "$OUT/IdrTestGui.exe"
  "$OUT/IdrTestDll.dll"
)

declare -a ANALYZE_FLAGS=(
  "/analyze" "/a" "-a" "--analyze"
)

declare -a SAVE_PROJECT_FLAGS=(
  "/save" "/saveproject" "/project" "-p" "--project"
)

declare -a EXPORT_FLAGS=(
  "/export" "/dump" "-e" "--export"
)

for bin in "${BINARIES[@]}"; do
  bn="$(basename "$bin")"
  bstem="${bn%.*}"
  echo
  echo "=============================="
  echo "Target: $bn"
  echo "=============================="

  for a in "${ANALYZE_FLAGS[@]}"; do
    try_cmd "${bstem}_analyze_${a//\//}" "$a" "$bin"
  done

  for s in "${SAVE_PROJECT_FLAGS[@]}"; do
    out_idp="$LOGROOT/${bstem}.idp"
    try_cmd "${bstem}_save_${s//\//}" "$s" "$out_idp" "$bin"
    try_cmd "${bstem}_save2_${s//\//}" "$bin" "$s" "$out_idp"
  done

  for e in "${EXPORT_FLAGS[@]}"; do
    out_dir="$LOGROOT/${bstem}_export"
    mkdir -p "$out_dir"
    try_cmd "${bstem}_export_${e//\//}" "$e" "$out_dir" "$bin"
    try_cmd "${bstem}_export2_${e//\//}" "$bin" "$e" "$out_dir"
  done
done

echo
echo "Done. Review logs under: $LOGROOT"
echo "Tip: open $HELP_LOG and then prune/add switch candidates in this script."
