# v11.7 — Search pill diagnostic only

This is a diagnostic build, not the Search lift fix. No pill movement is applied.

## Baseline

Built directly from the full uploaded `lara-branch-statusbar-11.3.zip`, commit
`7dc38f17ed80a9f97767c62e7e78baf351eda67b`.

No reconstructed repo or 11.4/11.5/11.6 source was used. The entire original
`lara/kexploit/pe/rc.m` is preserved as an identical byte prefix. Only a new
self-contained Search diagnostic block is appended. Gradient rendering and host
resolution, status/navigation handling, Dock lift, upside-down rotation,
MobileGestalt, RotationHook, project settings and build workflows are unchanged.
The existing marketing version remains unchanged; the new UI and log identify
this diagnostic as v11.7.

## Run

1. Run your existing GitHub Actions workflow to build the IPA, then sideload it.
2. Initialize RemoteCall as usual. Keep your usual 11.3 setup.
3. Under Tweaks, tap **Diagnose Home Search Pill** once and wait for its result.
4. Export the full Lara log. Look for `(rc) v11.7 search diagnostic:` entries.

There is no Lift/Restore Search button in this build. The new button does not
change geometry, layers, hitboxes, gradients or orientation.

## Evidence collected

- Resolve the existing stock Dock and walk its ancestors to the Home hierarchy.
  No UIApplication window enumeration and no loading controller views.
- Check that SBHSearchPillView exists on the actual device and find instances
  by runtime `isKindOfClass:` checks within that Home hierarchy.
- Log the native Home subtree using `recursiveDescription` when available,
  including surrounding material/background views and their descendants.
- Log each pill's ancestor chain: native view description (class, address,
  layer and any reported transform), frame, bounds, interaction, hidden and
  clipping flags, plus gesture recognizer descriptions.
- Log the same explicit metadata for up to 12 immediate siblings per level
  at the first four ancestor levels; the native subtree provides further context.

UIKit diagnostic getters are scheduled on SpringBoard's main thread with
NSInvocationOperation. Getter return sizes are checked before copying bytes.
Object results, arrays, queued views and ancestors are retained during inspection
and released afterwards. A timed-out operation is left owned until SpringBoard
restart because it may still execute; the diagnostic stops at that point.

Limits are explicit in the log: 512 visited/pending views, four matching pills,
16 ancestors and 256 KiB per text dump. These are live sequential observations,
not an atomic freeze of SpringBoard. A missing/truncated hierarchy or timeout is
reported rather than choosing an unverified parent.

## Validation

- All original repo files except rc.m, rc.h and RemoteView.swift are identical.
- All original rc.m bytes are identical; the addition is appended.
- Removing the one header declaration and the new Swift Section exactly
  reconstructs those two baseline files.
- `git diff --no-index --check` passes.
- C control-flow/format syntax of the isolated diagnostic passes GCC with
  `-Wall -Wextra -Werror` after substituting the three Objective-C remote-read
  expressions with declarations. This is a structural check, not an Objective-C
  or iPhoneOS compilation.
- Xcode/Swift/iPhoneOS build and physical-device validation were not available
  in this environment. Your Actions build and exported device log are required.

The next change can move the actual owning Search control once the device log
identifies the complete text/background/interaction hierarchy.

## References

Apple demonstrates UIView recursiveDescription in its debugger talk:
https://developer.apple.com/videos/play/wwdc2018/412/

Foundation operation behavior:
https://developer.apple.com/library/archive/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationObjects/OperationObjects.html
