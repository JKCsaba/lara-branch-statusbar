# Lara 0.2 — Status Bar V6 Safe Auto-Follow

## Why V6 exists

Real-device testing on the target iPhone 12 / iOS 18.4 established that the V3 status-bar geometry is correct in both portrait states:

- portrait: rotation `0`, translation `0`
- portrait-upside-down: rotation `pi`, translation equal to the live opposite-edge offset

The manual **Fallback: Sync Current Orientation** correctly switches between those two states.

The V5 native-window experiment did not. Pressing **Enable Dynamic Auto-Follow** caused SpringBoard to respring. V6 therefore removes that experiment from the user-facing status-bar controls instead of trying to make the private status-bar UIWindow autorotate.

## V6 design

**V6: Safe Auto-Follow — One Tap** does three things:

1. Calls Lara's existing `enable_upside_down(proc)` so SpringBoard supports portrait-upside-down.
2. Immediately applies the known-good status-bar state for SpringBoard's current `activeInterfaceOrientation`.
3. Starts a conservative 300 ms Lara-side poller. The poller reads the active orientation and only mutates the status-bar layer when portrait changes between `1` and `2`.

No SpringBoard UIKit method implementations are replaced by V6.

The actual transform is still the verified V3 model. V6 only automates when that model is selected.

## Main-thread safety

The old V3 test setter queued retained `NSInvocation` objects asynchronously and deliberately leaked them to avoid lifetime races. That was fine for one manual press but is inappropriate for an indefinitely running auto-follow loop.

V6's transform setter therefore uses the existing bounded `NSInvocationOperation` helper:

- operation is queued onto SpringBoard's real main thread with `waitUntilDone:NO`;
- Lara polls `isFinished` from RemoteCall's thread;
- after completion the operation is released;
- there is no exception-port takeover of SpringBoard's main thread.

This is the same main-thread strategy introduced for the safer floating-dock experiment.

## Idempotency

V6 stores the last synchronized portrait orientation as an associated object on the live status-bar object. During the 300 ms poll, the normal result is therefore `1` (already correct) and **no status-bar mutation is queued**. A real portrait orientation transition returns `0` and applies the two KVC values once.

If SpringBoard replaces the status-bar object, the associated marker disappears with it and the next poll naturally reapplies the current state.

## Background behavior / keepalive

Lara already contains a silent-audio keepalive and declares `UIBackgroundModes = audio`. V6 enables that keepalive automatically when needed.

Normally Lara destroys its SpringBoard RemoteCall session when it enters the background. While V6 auto-follow is active, `lara.swift` intentionally skips that cleanup so the lightweight orientation poll can continue after leaving Lara for the Home Screen.

**Trade-off:** V6 keeps Lara alive and retains the SpringBoard RemoteCall session while enabled. This costs more battery than a fully SpringBoard-resident hook, but it avoids the private UIWindow method replacement that was observed to crash SpringBoard. For this device-specific build, reliability is preferred over elegance.

Use **V6: Stop Auto-Follow** before intentionally destroying RemoteCall or doing unrelated long RemoteCall experiments. If V6 turned keepalive on itself, Stop turns it back off.

## UI changes

The status-bar section now exposes:

- **V6: Safe Auto-Follow — One Tap** — recommended path.
- **V6: Stop Auto-Follow** — stops the poller; leaves the current visual transform untouched.
- **Fallback: Working V3 — Static** — original known-good static upside-down state.
- **Fallback: Sync Current Orientation** — forces the now-safe V6/V3 geometry sync once.
- **Fallback: Restore Layer Transform** — restores the layer transform.
- **Read-Only Geometry Probe** — unchanged.

The crashing V5 Dynamic Auto-Follow buttons are removed from the UI, but the old V5 C functions remain in the source for reference/recovery and to minimize unrelated code churn.

## First-device test

1. Reboot/respring to clear all previous in-memory status-bar experiments.
2. Initialize Lara RemoteCall on SpringBoard.
3. Hold the phone in either normal portrait or portrait-upside-down.
4. Press **V6: Safe Auto-Follow — One Tap** once.
5. Leave Lara and return to the Home Screen.
6. Rotate normal -> upside-down -> normal several times.
7. Expected: Home Screen and status bar move together. There should be no respring.
8. Check Lara logs. A real transition should produce `V6 auto-follow: orientation change applied`; steady-state polls should not spam the log.

If status-bar movement stops after Lara is backgrounded, verify the silent-audio keepalive is still active. If SpringBoard resprings, collect the Lara log before trying another status-bar function.

## Build status

This source was mechanically checked in the current environment, but it cannot be compiled here against Apple's iPhoneOS SDK. Build it using the repository's existing Xcode/GitHub Actions path and test on the target device.
