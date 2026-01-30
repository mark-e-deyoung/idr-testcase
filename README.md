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

### Recommended: sibling borland-toolchains checkout

If you have this workspace layout:

```
workspace/
  borland-toolchains/
  idr-testcase/
```

Then `scripts/build-binaries.sh` auto-detects
`../borland-toolchains/scripts/delphi7-toolchain.sh`.

Build:

```bash
cd ~/Projects/sandbox-idr/workspace/idr-testcase
chmod +x build.sh scripts/build-binaries.sh run-idr-cli.sh
./build.sh
./build.sh clean   # remove build outputs
```

### Alternate: toolchain wrapper on PATH

If you installed the wrapper elsewhere, ensure it is on PATH or set:

```bash
export DELPHI7_TOOLCHAIN=/path/to/borland-toolchains/scripts/delphi7-toolchain.sh
./build.sh
```

Outputs are placed in `build/win32/` and logs in `build/logs/`.

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
