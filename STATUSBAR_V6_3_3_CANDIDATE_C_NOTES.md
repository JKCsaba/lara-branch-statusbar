# Status Bar V6.3.3 — Candidate C

## Result carried forward from V6.3.2

Physical-device testing on iPhone13,2 / iOS 18.4 showed both earlier SBIconController candidates are absent:

- Candidate A: `-[SBIconController updateContentViewOrientationAndLayoutIfNeeded]`
- Candidate B: `-[SBIconController _updateContentViewOrientationAndLayoutIfNeeded]`

For Candidate B, `class_getInstanceMethod(...)` returned `0`, and the guarded Invoke path correctly returned without invoking anything. The same run reconfirmed that `UIApplication.activeInterfaceOrientation` reports `1` in normal portrait and `2` in portrait-upside-down.

## What V6.3.3 tests

V6.3.3 advances one position in the original bounded selector list and tests only:

`-[SBIconController setNeedsUpdateOfSupportedInterfaceOrientations]`

This is **Candidate C**.

## Crash-hardening rules retained

- Quick Discover remains disabled.
- Deep Scan remains disabled.
- Bulk candidate-index invocation remains disabled.
- No Objective-C method enumeration.
- No remote class-name string reads.
- No remote type-encoding string reads.
- No polling timer.
- No silent-audio keepalive.
- No persistent background RemoteCall session.
- Verify and Invoke are separate actions.
- Candidate C is invoked only after `class_getInstanceMethod(...)` succeeds.
- `method_getNumberOfArguments(...)` must report `2` (`self` + `_cmd`, meaning zero explicit arguments).
- `class_getMethodImplementation(...)` must return a nonzero IMP.
- Invocation, if allowed, is queued once onto SpringBoard's main thread with the existing asynchronous `NSInvocation` helper.

## Buttons

### V6.3: Prepare Rotation Baseline

Unchanged. Enables portrait-upside-down support and performs one known-good V6 status-bar sync. It starts no watchdog.

### V6.3: Probe Live Orientation State

Reads only `UIApplication.activeInterfaceOrientation`.

Expected values:

- `1` = Portrait
- `2` = PortraitUpsideDown

### V6.3.3: Verify Candidate C

Performs only the direct class/selector/method lookup for:

`SBIconController` + `setNeedsUpdateOfSupportedInterfaceOrientations`

Return values:

- `1` = Candidate C exists and matches the expected zero-explicit-argument shape.
- `0` = Candidate C is absent. Do not invoke it.
- `-5` = method exists but its runtime argument count/IMP is not safe for this test. Do not invoke it.
- `-80` = a local Objective-C exception was caught. Stop and inspect the Lara log.

### V6.3.3: Invoke Candidate C Once

Re-verifies Candidate C, resolves `+[SBIconController sharedInstance]`, and queues exactly one zero-explicit-argument invocation on SpringBoard's main thread.

If the method is absent, the function logs `result=not-run reason=method-absent` and returns without invoking anything.

## Test sequence

1. Clean respring.
2. Initialize SpringBoard RemoteCall.
3. Press **V6.3: Prepare Rotation Baseline** once.
4. Press **V6.3.3: Verify Candidate C** once.
5. If it returns anything other than `1` (`0`, `-5`, or `-80`), stop and send the log. Do not press Invoke.
6. If it returns `1`, probe upright and upside-down; expected results are `1` then `2`.
7. Stay physically upside-down while the Home Screen is already rotated and the status bar is still visually wrong.
8. Press **V6.3.3: Invoke Candidate C Once** exactly once.
9. Observe whether the status bar re-evaluates or moves. Send the resulting log either way.

## Scope

V6.3.3 still does not install a permanent orientation hook. It remains a single-candidate existence/action test intended to identify a safe native SpringBoard transition/update point without reintroducing bulk discovery or continuous RemoteCall polling.
