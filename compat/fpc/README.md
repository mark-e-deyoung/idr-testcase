# Free Pascal Classes — original clean-room witness

Authority: private Delphi/C++Builder recovery DLE #5. Public-source-only research, not original Delphi 7 VCL source/ABI or product qualification.

Four falsifiable cases: TComponent owner/count/removal, published integer and method-event RTTI, TStream.WriteComponent/ReadComponent owned child/value, negative read of an unregistered class. Only original Pascal source is used, no historical binary source or borrowed VCL code.

The public workflow fetches ONLY the Pascal source text from the immutable PR head, no Git checkout, historic fixture EXE/DLL/DCU/RES, licensed toolchains, Docker images or artifacts. FPC comes from the Ubuntu 24.04 official fp-compiler 3.2.2 package. Executable lives in ephemeral runner scratch; no upload.

Deferred: inherited DFM, forward reference fixup and Loaded ordering, aliases, unknown-property and cross-form behavior, two-FPC-version delta, Win32 comparison, original Delphi oracle. No acceptance/merge/release.