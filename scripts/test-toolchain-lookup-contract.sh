#!/usr/bin/env bash
set -euo pipefail

# License-clean synthetic qualification of toolchain wrapper discovery only.
# Everything lives in a disposable directory; no Borland/Wine/Docker binaries.
# A previous source-hardening commit accidentally removed executable mode from
# wrappers; validate the exact Git index as a separate non-runtime preflight.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "${TMP}"' EXIT

# The checked-out wrapper scripts must stay executable, not merely Bash-parsable.
# This check fails on historical 100644 regression even when tests call bash.
for tracked in scripts/build-binaries.sh scripts/package-installer.sh build.sh; do
    mode="$(git -C "${SCRIPT_DIR}/.." ls-files -s -- "${tracked}" | awk '{print $1}')"
    if [[ "${mode}" != 100755 ]]; then
        echo "FAIL: ${tracked} must have Git executable mode 100755 (observed ${mode:-missing})" >&2
        exit 1
    fi
done
echo "PASS: 3/3 executable Git modes retained"

FIXTURE="${TMP}/idr-testcase"
TOOLCHAIN="${TMP}/actual-toolchain"
mkdir -p "${TOOLCHAIN}/scripts"

fresh_fixture() {
    local dst="$1" stem
    mkdir -p "${dst}/scripts" "${dst}/delphi"
    cp "${SCRIPT_DIR}/build-binaries.sh" "${SCRIPT_DIR}/package-installer.sh" "${dst}/scripts/"
    chmod +x "${dst}/scripts/"*.sh
    for stem in IdrTestConsole IdrTestGui IdrTestDll; do
        printf 'program %s; begin end.\n' "${stem}" > "${dst}/delphi/${stem}.dpr"
    done
}
fresh_fixture "${FIXTURE}"

cat > "${TOOLCHAIN}/scripts/delphi7-toolchain.sh" <<'STUB_COMPILER'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == compile ]] || exit 50
shift
kind='' out='' source=''
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --kind) kind="$2"; shift 2 ;;
        --out) out="$2"; shift 2 ;;
        *) source="$1"; shift ;;
    esac
done
[[ -n "${kind}" && -n "${out}" && -n "${source}" ]] || exit 51
stem="$(basename "${source}" .dpr)"
mkdir -p "delphi/${out}"
printf 'synthetic %s %s\n' "${stem}" "${kind}" > "delphi/${out}/${stem}.${kind}"
printf 'compiler:%s\n' "${stem}" >> "${MOCK_TRACE}"
STUB_COMPILER

cat > "${TOOLCHAIN}/scripts/innosetup-packager.sh" <<'STUB_PACKAGER'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
    image-build)
        printf 'packager:image-build\n' >> "${MOCK_TRACE}"
        ;;
    compile)
        [[ "${2:-}" == IdrTestcase.iss ]] || exit 61
        mkdir -p dist
        printf 'synthetic installer\n' > dist/IdrTestcase-Setup.exe
        printf 'packager:compile\n' >> "${MOCK_TRACE}"
        ;;
    *) exit 62 ;;
esac
STUB_PACKAGER
chmod +x "${TOOLCHAIN}/scripts/"*.sh
export MOCK_TRACE="${TMP}/mock-trace.log"

# 1. An existing checkout with a nonhistorical name must work end to end.
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${FIXTURE}/scripts/build-binaries.sh"
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${FIXTURE}/scripts/package-installer.sh"
for artifact in IdrTestConsole.exe IdrTestGui.exe IdrTestDll.dll; do
    [[ -s "${FIXTURE}/build/win32/${artifact}" ]] || {
        echo "ERROR: expected synthetic output missing: ${artifact}" >&2
        exit 1
    }
done
[[ -s "${FIXTURE}/build/installer/dist/IdrTestcase-Setup.exe" ]] || exit 1
echo "PASS: checkout root drives all three builds and packaging"

# 2. Compiler override in its own clean workcell.
OVERRIDE_FIXTURE="${TMP}/override-fixture"
fresh_fixture "${OVERRIDE_FIXTURE}"
BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
DELPHI7_TOOLCHAIN="${TOOLCHAIN}/scripts/delphi7-toolchain.sh" \
    bash "${OVERRIDE_FIXTURE}/scripts/build-binaries.sh"
echo "PASS: DELPHI7_TOOLCHAIN override precedence"

# 3. Packager override in an independent clean workcell.
PACK_FIXTURE="${TMP}/pack-fixture"
fresh_fixture "${PACK_FIXTURE}"
mkdir -p "${PACK_FIXTURE}/build/win32"
cp "${FIXTURE}/build/win32/"*.exe "${FIXTURE}/build/win32/"*.dll "${PACK_FIXTURE}/build/win32/"
BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
INNOSETUP_PACKAGER="${TOOLCHAIN}/scripts/innosetup-packager.sh" \
    bash "${PACK_FIXTURE}/scripts/package-installer.sh"
echo "PASS: INNOSETUP_PACKAGER override precedence"

# 4. Invalid explicit root fails with its own missing-wrapper error, not a stale artifact.
BAD_FIXTURE="${TMP}/invalid-fixture"
fresh_fixture "${BAD_FIXTURE}"
if BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
    bash "${BAD_FIXTURE}/scripts/build-binaries.sh" > "${TMP}/negative.log" 2>&1; then
    echo "ERROR: invalid toolchain root was silently accepted" >&2
    exit 1
fi
grep -Fq 'toolchain wrapper not executable' "${TMP}/negative.log"
echo "PASS: invalid explicit root fails closed"

# 5. Existing output must not be removed by a second build.
before="$(cat "${FIXTURE}/build/win32/IdrTestConsole.exe")"
rc=0
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${FIXTURE}/scripts/build-binaries.sh" > "${TMP}/build-refusal.log" 2>&1 || rc=$?
[[ "${rc}" == 2 ]] || { echo "FAIL: preexisting binary build not refused" >&2; exit 1; }
grep -Fq 'IDR_BUILD_REFUSED reason=existing_output action=none' "${TMP}/build-refusal.log"
[[ "$(cat "${FIXTURE}/build/win32/IdrTestConsole.exe")" == "${before}" ]]
echo "PASS: existing tracked-like output preserved"

# 6. Existing packaging staging must not be recursively deleted.
before="$(cat "${FIXTURE}/build/installer/src/IdrTestGui.exe")"
rc=0
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${FIXTURE}/scripts/package-installer.sh" > "${TMP}/package-refusal.log" 2>&1 || rc=$?
[[ "${rc}" == 2 ]] || { echo "FAIL: existing package staging not refused" >&2; exit 1; }
grep -Fq 'IDR_PACKAGE_REFUSED reason=existing_output action=none' "${TMP}/package-refusal.log"
[[ "$(cat "${FIXTURE}/build/installer/src/IdrTestGui.exe")" == "${before}" ]]
echo "PASS: existing package staging preserved"

# 7. A pre-existing ISS manifest must not be overwritten.
ISS_FIXTURE="${TMP}/iss-fixture"
fresh_fixture "${ISS_FIXTURE}"
mkdir -p "${ISS_FIXTURE}/build/installer" "${ISS_FIXTURE}/build/win32"
printf 'do-not-overwrite\n' > "${ISS_FIXTURE}/build/installer/IdrTestcase.iss"
rc=0
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${ISS_FIXTURE}/scripts/package-installer.sh" > "${TMP}/iss-refusal.log" 2>&1 || rc=$?
[[ "${rc}" == 2 ]] || { echo "FAIL: existing ISS not refused" >&2; exit 1; }
grep -Fq 'IDR_PACKAGE_REFUSED reason=existing_output action=none' "${TMP}/iss-refusal.log"
[[ "$(cat "${ISS_FIXTURE}/build/installer/IdrTestcase.iss")" == do-not-overwrite ]]
echo "PASS: existing ISS preserved"

# 8. Symlinked binary output directory cannot redirect writes outside workcell.
LINK_BUILD_FIXTURE="${TMP}/linked-build-fixture"
fresh_fixture "${LINK_BUILD_FIXTURE}"
mkdir -p "${LINK_BUILD_FIXTURE}/build" "${TMP}/protected-build"
printf 'protected\n' > "${TMP}/protected-build/proof.txt"
ln -s "${TMP}/protected-build" "${LINK_BUILD_FIXTURE}/build/win32"
rc=0
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${LINK_BUILD_FIXTURE}/scripts/build-binaries.sh" > "${TMP}/linked-build-refusal.log" 2>&1 || rc=$?
[[ "${rc}" == 2 ]] || { echo "FAIL: symlinked output not refused" >&2; exit 1; }
grep -Fq 'IDR_BUILD_REFUSED reason=symlinked_parent action=none' "${TMP}/linked-build-refusal.log"
[[ "$(cat "${TMP}/protected-build/proof.txt")" == protected ]]
[[ ! -e "${TMP}/protected-build/IdrTestConsole.exe" ]]
echo "PASS: symlinked build output refused without outside write"

# 9. Installer input may not be a symlink to an external binary.
LINK_PACKAGE_FIXTURE="${TMP}/linked-package-fixture"
fresh_fixture "${LINK_PACKAGE_FIXTURE}"
mkdir -p "${LINK_PACKAGE_FIXTURE}/build/win32"
cp "${FIXTURE}/build/win32/"*.exe "${FIXTURE}/build/win32/"*.dll "${LINK_PACKAGE_FIXTURE}/build/win32/"
printf 'external-binary-sentinel\n' > "${TMP}/external-source.exe"
rm -f -- "${LINK_PACKAGE_FIXTURE}/build/win32/IdrTestGui.exe"
ln -s "${TMP}/external-source.exe" "${LINK_PACKAGE_FIXTURE}/build/win32/IdrTestGui.exe"
rc=0
BORLAND_TOOLCHAIN_ROOT="${TOOLCHAIN}" \
    bash "${LINK_PACKAGE_FIXTURE}/scripts/package-installer.sh" > "${TMP}/linked-package-refusal.log" 2>&1 || rc=$?
[[ "${rc}" == 2 ]] || { echo "FAIL: symlinked installer input not refused" >&2; exit 1; }
grep -Fq 'IDR_PACKAGE_REFUSED reason=missing_or_symlinked_input action=none' "${TMP}/linked-package-refusal.log"
[[ "$(cat "${TMP}/external-source.exe")" == external-binary-sentinel ]]
[[ ! -e "${LINK_PACKAGE_FIXTURE}/build/installer/src" ]]
echo "PASS: symlinked installer input refused without staging"

if grep -Fq 'packager:image-build' "${MOCK_TRACE}"; then
    echo "FAIL: implicit image-build attempted" >&2
    exit 1
fi
echo "PASS: 9/9 synthetic toolchain and source-custody checks (NOT compiler qualification)"
