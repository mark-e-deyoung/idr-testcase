#!/usr/bin/env bash
set -euo pipefail

# License-clean synthetic qualification of toolchain wrapper discovery only.
# Everything lives in a disposable directory; no Borland/Wine/Docker binaries.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "${TMP}"' EXIT

FIXTURE="${TMP}/idr-testcase"
TOOLCHAIN="${TMP}/actual-toolchain"
mkdir -p "${FIXTURE}/scripts" "${FIXTURE}/delphi" "${TOOLCHAIN}/scripts"
cp "${SCRIPT_DIR}/build-binaries.sh" "${SCRIPT_DIR}/package-installer.sh" "${FIXTURE}/scripts/"
chmod +x "${FIXTURE}/scripts/"*.sh
for stem in IdrTestConsole IdrTestGui IdrTestDll; do
    printf 'program %s; begin end.\n' "${stem}" > "${FIXTURE}/delphi/${stem}.dpr"
done

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

# 2. The explicit compiler wrapper has precedence even with an invalid root.
BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
DELPHI7_TOOLCHAIN="${TOOLCHAIN}/scripts/delphi7-toolchain.sh" \
    bash "${FIXTURE}/scripts/build-binaries.sh"
echo "PASS: DELPHI7_TOOLCHAIN override precedence"

# 3. The explicit packager executable has precedence over the checkout root.
BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
INNOSETUP_PACKAGER="${TOOLCHAIN}/scripts/innosetup-packager.sh" \
    bash "${FIXTURE}/scripts/package-installer.sh"
echo "PASS: INNOSETUP_PACKAGER override precedence"

# 4. An invalid explicit root fails rather than silently using another checkout.
if BORLAND_TOOLCHAIN_ROOT="${TMP}/not-a-toolchain" \
    bash "${FIXTURE}/scripts/build-binaries.sh" > "${TMP}/negative.log" 2>&1; then
    echo "ERROR: invalid toolchain root was silently accepted" >&2
    exit 1
fi
echo "PASS: invalid explicit root fails closed"

echo "PASS: 4/4 synthetic toolchain discovery checks (NOT compiler qualification)"
