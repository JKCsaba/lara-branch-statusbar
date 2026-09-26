# Status Bar V6.3.2 — Candidate B

## Result carried forward from V6.3.1

Physical-device testing on iPhone13,2 / iOS 18.4 established that Candidate A is absent:

`-[SBIconController updateContentViewOrientationAndLayoutIfNeeded]`

`class_getInstanceMethod(...)` returned `0`, and the guarded Invoke path correctly refused to execute it. The same test also confirmed that `UIApplication.activeInterfaceOrientation` reports `1` in normal portrait and `2` in portrait-upside-down, and the manual known-good V6 sync still applies the correct status-bar transform.

## What V6.3.2 tests

V6.3.2 advances exactly one predetermined selector on the same class:

`-[SBIconController _updateContentViewOrientationAndLayoutIfNeeded]`

This is **Candidate B**. The only semantic change from the V6.3.1 candidate test is the leading underscore in the selector.

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
- Both Candidate B actions are wrapped in Objective-C `@try/@catch`.
- The candidate is invoked only after a direct `class_getInstanceMethod(...)` existence check succeeds.
- `method_getNumberOfArguments(...)` must report `2` (`self` + `_cmd`, meaning zero explicit arguments), and `class_getMethodImplementation(...)` must return a nonzero IMP. No type-encoding string is read.
- Invocation, if allowed, is queued once onto SpringBoard's main thread with the existing asynchronous `NSInvocation` helper.

## Buttons

### V6.3: Prepare Rotation Baseline

Unchanged. Enables portrait-upside-down support and performs one known-good V6 status-bar sync. It starts no watchdog.

### V6.3: Probe Live Orientation State

Unchanged in behavior. It reads only `UIApplication.activeInterfaceOrientation`.

Expected values:

- `1` = Portrait
- `2` = PortraitUpsideDown

### V6.3.2: Verify Candidate B

Performs only the direct class/selector/method lookup for:

`SBIconController` + `_updateContentViewOrientationAndLayoutIfNeeded`

Return values:

- `1` = Candidate B exists.
- `0` = Candidate B is absent. Do not invoke it.
- `-5` = method exists but its runtime argument count/IMP is not safe for this zero-argument test. Do not invoke it.
- `-80` = a local Objective-C exception was caught. Stop and inspect the Lara log.

### V6.3.2: Invoke Candidate B Once

Re-verifies Candidate B, resolves `+[SBIconController sharedInstance]`, and queues exactly one zero-explicit-argument invocation on SpringBoard's main thread.

If the method is absent, the function logs `result=not-run reason=method-absent` and returns without invoking anything.

## Test sequence

1. Clean respring.
2. Initialize SpringBoard RemoteCall.
3. Press **V6.3: Prepare Rotation Baseline** once.
4. Press **V6.3.2: Verify Candidate B** once.
5. If it returns anything other than `1` (`0`, `-5`, or `-80`), stop and send the log. Do not press Invoke.
6. If it returns `1`, probe orientation upright and upside-down; expected results are `1` then `2`.
7. Stay physically upside-down while the Home Screen is already rotated and the status bar is still visually wrong.
8. Press **V6.3.2: Invoke Candidate B Once** exactly once.
9. Observe whether the status bar re-evaluates or moves. Send the resulting log either way.

## Scope

V6.3.2 still does not install a permanent orientation hook. It is a single-candidate existence/action test intended to identify a safe native SpringBoard transition/update point without reintroducing bulk discovery or continuous RemoteCall polling.
