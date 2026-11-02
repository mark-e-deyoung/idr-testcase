# idr-testcase (Delphi 7 / Win32) — IDR command-line correctness harness corpus

This is a Delphi **7** (Win32) mini-suite designed to compile under **Wine** and produce three binaries:

- `IdrTestConsole.exe` — console app (lots of RTTI/symbols, clear stdout markers)
- `IdrTestGui.exe` — VCL GUI app (DFM resources + message handlers + events)
- `IdrTestDll.dll` — DLL with stdcall exports (exports table + calling conventions)

The code is intentionally written to:
1) **Compile with Delphi 7** (no modern RTL assumptions).
2) Exercise many Delphi constructs that decompilers typically recover (VMT, published RTTI,
   dispatch tables, interfaces, exceptions, resources, init/fini sections, etc.).
3) Emit **explicit feature markers** in comments and (for the console app) in stdout so you can
   tie IDR output back to the feature being validated.

> Note: The GUI app is mainly for *analysis* (DFM/resources + event handlers). You do not need to run it.

## Feature map (what this testcase tries to cover)

All tests include **IDR_FEATURE** markers in code and standardized runtime tags in the console output.

- **PE / Resources**
  - `.res` compiled from `.rc` via `brcc32` (stringtable entries)
  - VCL DFM resource via `{$R *.dfm}`
- **Units / Init / Finalization**
  - `initialization` / `finalization` blocks in `uOO.pas`
- **OOP / VMT**
  - base/derived classes, overrides, virtual vs dynamic methods
  - properties (including published) to force RTTI
- **Published RTTI**
  - `{$M+}` classes with `published` properties/events
- **Windows messages / dispatch table**
  - `message WM_USER + N` handler + `Dispatch`
- **Interfaces**
  - `TInterfacedObject` implementing two interfaces with explicit GUIDs
  - explicit `QueryInterface(IID_..., ...)` (Delphi 7-safe)
- **Exceptions**
  - custom exception hierarchy, try/except, try/finally
- **Types**
  - enums/sets/subranges
  - packed records + variant records
  - dynamic arrays
  - Variant values/arrays
- **Strings / conversions**
  - `AnsiString`, `WideString`, `ShortString`, `PChar`, `PWideChar`
- **Threads**
  - `TThread` subclass + `Resume` + `WaitFor`

## Build (Delphi 7 via borland-toolchains container)

The build is driven by `build.sh`, which delegates to
`scripts/build-binaries.sh` and compiles with the **containerized**
Delphi 7 toolchain from the `borland-toolchains` project.

### Build admission and source custody

**Current authority:** [private Delphi/C++Builder recovery DLE #5](https://github.com/mark-e-deyoung/borland-container-packager/issues/5). This public repository already tracks historical EXE, DLL, DCU, and RES files. Their independent binary provenance/redistribution rights and licensed compiler inputs are **not** cleared by the synthetic workflow results. Do not publish, package, or move them into public runners or cloud images.

The `build.sh clean` and `build.sh --clean` commands now **refuse** with `IDR_CLEAN_REFUSED` and status 2; `build.sh clean-plan` only reports planned scope. Ordinary `build.sh` also refuses if the expected build artifacts or logs already exist (`IDR_BUILD_REFUSED`); the packager refuses existing staging, manifests, installer output or symlinked inputs (`IDR_PACKAGE_REFUSED`). No toolchain or installer command should silently overwrite historical tracked binaries or a human's uncommitted work.

A real build requires a separately **admitted sovereign/local actor**, compatible licensed and rights-cleared Delphi 7 / Inno Setup toolchains, a pinned image identity, and a **new positively owned disposable source-only workcell with initially absent outputs**. Prepare it from an independently verified source manifest. A plain clone of this repository includes tracked historical build artifacts and is **not** a fresh output workcell; never use `git clean`, `git restore`, `rm -rf`, or destructive scripted cleanup as a workaround. Do not assume local host paths or worktree cleanliness from GitHub.

For historical compatibility, `scripts/build-binaries.sh` can locate a sibling `../borland-toolchains/scripts/delphi7-toolchain.sh` when neither explicit override nor a wrapper on `PATH` is supplied. Verify the actual current checkout rather than renaming or replacing local trees.

### Alternate: toolchain wrapper on PATH

If you installed the wrapper elsewhere, ensure it is on PATH or set:

```bash
export DELPHI7_TOOLCHAIN=/path/to/existing-approved-toolchain/scripts/delphi7-toolchain.sh
# In an admitted, fresh source-only disposable workcell only:
./build.sh
```

When the toolchain repository has a different local directory name, use a
single explicit checkout root for **both** building and packaging (no symlink or
repository rename required):

```bash
export BORLAND_TOOLCHAIN_ROOT=/absolute/path/to/your-existing-approved-toolchain-checkout
# In an admitted, fresh source-only disposable workcell only:
./build.sh
./scripts/package-installer.sh
```

`DELPHI7_TOOLCHAIN` remains the highest-priority compiler wrapper override.
`INNOSETUP_PACKAGER` can separately specify the full executable path to the
Inno Setup wrapper. Both scripts retain the historical sibling lookup when
these variables are unset. The packager no longer implicitly builds an image;
image provisioning requires separate admission. Keep licensed snapshots and
packaged outputs on approved sovereign/local custody surfaces.

Outputs are placed in `build/win32/` and logs in `build/logs/` in the
owned workcell only. The public CI contracts use fake compiler/installer
stand-ins; a successful synthetic run is not Delphi/Wine/installer qualification.

## Run IDR CLI (best-effort probing)

Because IDR builds/forks differ in CLI switches, the runner:
1) Captures `idr.exe /?` output
2) Tries a small set of common “analyze/export/save project” switch patterns
3) Logs everything under `build/idr-cli/`

```bash
export IDR_EXE="/path/to/idr.exe"
./run-idr-cli.sh
```

If you paste the contents of `build/idr-cli/idr_help.txt` back into chat, we can
tighten `run-idr-cli.sh` to your exact IDR build (no guessing).
