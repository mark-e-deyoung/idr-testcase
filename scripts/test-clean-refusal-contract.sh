#!/usr/bin/env bash
# Public-safe synthetic safety contract: never run legacy destructive clean.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "${TMP}"' EXIT
mkdir -p "${TMP}/work/build/win32" "${TMP}/work/build/idr-cli"
cp "${ROOT}/build.sh" "${TMP}/work/build.sh"
printf 'historical-fixture\n' >"${TMP}/work/build/win32/fixture.exe"
printf 'important-log\n' >"${TMP}/work/build/idr-cli/recovery.log"
git -C "${TMP}/work" init -q
git -C "${TMP}/work" -c user.name='Contract Test' -c user.email='contract@example.invalid' add build/win32/fixture.exe
git -C "${TMP}/work" -c user.name='Contract Test' -c user.email='contract@example.invalid' commit -qm "synthetic fixture baseline"
printf 'unique-human-edit\n' >"${TMP}/work/build/win32/fixture.exe"

passed=0
for action in clean --clean; do
  rc=0
  bash "${TMP}/work/build.sh" "${action}" >"${TMP}/run.log" 2>&1 || rc=$?
  [[ "${rc}" -eq 2 ]] || { echo "FAIL: ${action} should refuse with 2 (got ${rc})" >&2; exit 1; }
  grep -Fq 'IDR_CLEAN_REFUSED reason=unowned_workspace action=none' "${TMP}/run.log" || { echo "FAIL: no machine-readable refusal" >&2; exit 1; }
  [[ "$(cat "${TMP}/work/build/win32/fixture.exe")" == unique-human-edit ]] || { echo "FAIL: modified tracked binary was restored" >&2; exit 1; }
  [[ "$(cat "${TMP}/work/build/idr-cli/recovery.log")" == important-log ]] || { echo "FAIL: untracked recovery log removed" >&2; exit 1; }
  echo "PASS: ${action} fail-closed, tracked and untracked data preserved"
  passed=$((passed+1))
done
for action in clean-plan --clean-plan; do
  rc=0
  bash "${TMP}/work/build.sh" "${action}" >"${TMP}/run.log" 2>&1 || rc=$?
  [[ "${rc}" -eq 0 ]] || { echo "FAIL: ${action} plan failed (got ${rc})" >&2; exit 1; }
  grep -Fq 'IDR_CLEAN_PLAN scope=build/ tracked_and_generated=true action=none' "${TMP}/run.log" || { echo "FAIL: missing plan evidence" >&2; exit 1; }
  [[ "$(cat "${TMP}/work/build/win32/fixture.exe")" == unique-human-edit ]] || { echo "FAIL: plan modified tracked file" >&2; exit 1; }
  [[ "$(cat "${TMP}/work/build/idr-cli/recovery.log")" == important-log ]] || { echo "FAIL: plan modified log" >&2; exit 1; }
  echo "PASS: ${action} read-only"
  passed=$((passed+1))
done
echo "PASS: ${passed}/4 clean safety checks (not licensed product qualification)"
[[ "${passed}" -eq 4 ]]
