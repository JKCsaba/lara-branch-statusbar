# Status Bar V6.3.1 — crash-hardened single-candidate test

## Why this revision exists

Two physical-device SpringBoard crash reports from iPhone13,2 / iOS 18.4 (22E240)
failed identically at PC/LR `0x401`. In Lara's `RemoteCall.h`, `0x401` is
`FAKE_LR_TROJAN`, the deliberate return trap used by the dedicated RemoteCall
thread. The Lara crash report from the same event aborted in:

`set_target_kaddr -> ... -> RemoteCall remoteRead -> rc_remote_class_name_v5 -> rc_v63_log_target -> v63_quick_discover_orientation_candidates`

So V6.3 Quick Discover failed in its remote metadata/string-reading path before
we had meaningfully tested the orientation callback itself.

## What V6.3.1 changes

- Quick Discover hard-disabled (`-90`).
- Deep Scan hard-disabled (`-90`).
- Old candidate-index invocation hard-disabled (`-90`).
- The live-orientation probe is reduced to **one** already-proven V6 query:
  `UIApplication.activeInterfaceOrientation`.
- No target enumeration or remote class-name reads occur in that probe.
- Added `@try/@catch` around the new minimal candidate operations so an
  Objective-C exception raised in Lara's RemoteCall/kernel-read path is caught
  locally instead of automatically escaping through the UI worker closure.
- Added one exact candidate only:
  `-[SBIconController updateContentViewOrientationAndLayoutIfNeeded]`.
- Added a read-only **Verify** button for that class/selector pair.
- Added a separate **Invoke Candidate A Once** button. It only runs after doing
  the same direct class/selector/method existence check, resolves
  `+[SBIconController sharedInstance]`, and queues one zero-argument invocation
  onto SpringBoard's main thread using the already-used async `NSInvocation`
  helper (`waitUntilDone:NO`).
- No remote class-name reads.
- No remote Objective-C type-encoding reads.
- No method enumeration.
- No timer / polling / silent-audio keepalive.
- No persistent background RemoteCall ownership.

## First test sequence

1. Clean respring.
2. Open Lara and initialize SpringBoard RemoteCall normally.
3. Press **V6.3: Prepare Rotation Baseline** once.
4. Press **V6.3.1: Verify Native Rotation Callback**.
   - `1` = the exact method exists on this build.
   - `0` = it does not exist; do not press Invoke.
   - `-80` = the wrapper caught an Objective-C exception; stop and send the log.
5. If Verify returned `1`, press the minimal orientation probe upright and then
   upside-down. Expected values are `1` and `2` respectively.
6. While physically upside-down and with the status bar still in the wrong
   state, press **V6.3.1: Invoke Candidate A Once** exactly once.
7. Observe whether the status bar immediately re-evaluates/moves. Do not spam the
   button. Send the resulting Lara log either way.

## Interpretation

If Candidate A visibly refreshes the status bar, SpringBoard already has an
existing update action we can reuse from a later orientation-transition hook.
If it does nothing, we move to the next single predetermined candidate in a new
build; we do not restore bulk scanning.

This revision still does **not** install a permanent orientation hook. The goal
is to establish one safe, exact SpringBoard callback/action at a time.
