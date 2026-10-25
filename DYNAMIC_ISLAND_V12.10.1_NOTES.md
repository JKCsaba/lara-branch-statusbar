# v12.10.1 — RemoteCall failure containment (NOT an orientation fix)

Source base: v12.10 no-poll, itself based on original v12.8 commit `2c3efe1`.

October 25, 2026 crash reports show `SIGABRT` in `lara`, from an uncaught
`dsexception` originating in `set_target_kaddr` during `ds_kread64`, reached
through `vmcreateshmemwithobj` > `vmmapremotepage` > `get_shmemForPage` >
`remoteRead`. Neither report establishes that the Island hook was installed.

This revision makes `get_shmemForPage` catch Objective-C exceptions around
`vmmapremotepage`, records the exception name/reason and page in `lastError`,
and returns NULL. The existing `remoteRead` stops on NULL and the v12.10
Island operation checks `lastError` before continuing. UI displays the error.

LIMITATIONS: No full Xcode compile or on-device test. Does not correct an
invalid kernel pointer, process memory object, offsets, kernel exploit state,
method ownership, or the Island orientation mechanism. It cannot guarantee
that another native fault, kernel panic, partially mutated VM state, or a
SpringBoard respring is impossible. Do NOT re-run the failing Lock action
merely to generate another report. Restarting Lara/RemoteCall is necessary
before another memory-access attempt after any `lastError` is set.

Working status bar / dock / gradients / v12.0 manual Island movement are
unchanged. No polling, keep-open, timer or callbacks were added.

The v12.8 IPA Mach-O disassembly shows the first `set_target_kaddr` throw
site returns at +200; both October 25, 2026 crash reports list +200. As the
function source remained unchanged, the invalid-kaddr branch (not setsockopt)
is strongly supported. `vmcreateshmemwithobj` therefore also checks its
computed `vm_object` size-field address with `ds_isvalid` before the first
kernel read; on failure it refuses the mapping. The additional catch protects
only against Objective-C exceptions; it does not catch native faults or undo
partial VM changes. The precise invalid pointer value is still unknown.

The source VM entry now also fails closed when `is_sub_map`,
`vme_kernel_object`, or a zero packed VM-object field is encountered, before
unpacking it as a normal `vm_object` pointer. The crash report does not reveal
whether any of these flags caused the invalid pointer; this is a structural
precondition, not an established device-specific diagnosis.
