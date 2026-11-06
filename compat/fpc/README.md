# Free Pascal Classes — original clean-room witness

Authority: private Delphi/C++Builder recovery DLE #5. Public-source-only research, not original Delphi 7 VCL source/ABI or product qualification.

Six falsifiable cases: TComponent owner/count/removal, published integer and method-event RTTI, TStream.WriteComponent/ReadComponent owned child/value with exact-once Loaded callback, sibling component forward-reference fixup, negative rejection of an unknown published property, and negative read of an unregistered class. Only original Pascal source is used, no historical binary source or borrowed VCL code.

The public workflow fetches ONLY the Pascal source text from the immutable PR head, no Git checkout, historic fixture EXE/DLL/DCU/RES, licensed toolchains, Docker images or artifacts. FPC comes from the Ubuntu 24.04 official fp-compiler 3.2.2 package. Executable lives in ephemeral runner scratch; no upload.

Deferred: inherited DFM, detailed Loaded-vs-fixup callback ordering, aliases, extended unknown-property and cross-form behavior, two-FPC-version delta, Win32 comparison, original Delphi oracle. The tested unknown-property case is an isolated refusal witness, not a general unknown-property compatibility claim. Forward-reference semantics are tested only for this original TComponent setup. No acceptance/merge/release.

## First-failure correction (exact initial head 9598172c)
Public FPC 3.2.2 first run 41545071382 compiled and passed owner-lifecycle and published-rtti, then failed at decoded child class. This was a real test-design error: ownership does not imply streaming; TComponent.GetChildren is empty by default. The revised TProbeRoot explicitly enumerates owned components only for its own root. The first failed run remains a durable negative receipt. Follow-on validation must check the new exact SHA; nothing in this correction proves Delphi VCL parity.

## Six-witness CI correction (2026-11-06)

Following the added unknown-property negative, the source emitted `PASS 6/6` while the original workflow still required `PASS 5/5`; that exact-head red failure is preserved in [run 41856823524](https://github.com/mark-e-deyoung/idr-testcase/actions/runs/41856823524). The workflow assertion was corrected without weakening any probe at commit `73f12ef5ddf11a03e806a80452c89a49d0c72a74`. [Run 42297719810](https://github.com/mark-e-deyoung/idr-testcase/actions/runs/42297719810) passed all six behavior checks under Ubuntu 24.04/FPC 3.2.2. This is FPC-only source evidence, not Delphi VCL parity, Win32, proprietary asset clearance or release acceptance.
