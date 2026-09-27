# Lara V6.3.7 — Native Visual Follow

## Purpose

V6.3.7 is a narrow extension of the crash-free V6.3.6 architecture. It keeps SpringBoard's real rotation callback untouched and keeps Lara out of the runtime loop after installation.

## What changed

- Reuses V6.3.6 portrait + portrait-upside-down policy/mask setup.
- Reuses the single `UIDeviceOrientationDidChangeNotification` source.
- Reuses the delayed SpringBoard-main-thread `NSInvocation` path.
- Adds exactly two visual invalidations on a real device-orientation event:
  - live status-bar view -> `setNeedsLayout`
  - live stock Dock host -> `setNeedsLayout`
- Still asks the root-folder/home/status-root controllers to re-evaluate supported orientations and status-bar appearance.
- Does **not** call `layoutIfNeeded`.
- Does **not** observe status-bar/frame-change notifications.
- Does **not** replace `viewWillTransitionToSize:withTransitionCoordinator:`.
- Does **not** start a Lara timer, watchdog, audio keepalive, or persistent RemoteCall loop.

## Important limitation

The proven V3 status-bar transform and V6.1 `-23 pt` Dock transform are Lara-side RemoteCall routines. They are not executable code resident in SpringBoard after the RemoteCall session is torn down. Therefore V6.3.7 intentionally does not pretend those C routines can be called later by an in-process notification observer. This build tests the strongest no-injection/native-only path available from the existing primitives: let SpringBoard commit orientation, then narrowly invalidate the two live visual hosts so native layout can follow.

If this makes both visuals correct on the target iPhone 12/iOS 18.4, the final architecture is achieved without injected executable code. If the status bar still needs the explicit V3 `pi` + opposite-edge transform or the Dock still needs the explicit `-23 pt` transform after each transition, then the remaining missing primitive is a real SpringBoard-resident executable callback/trampoline (or separately loadable injected module) that can run the existing two-state setter after Lara exits. Replacing a callback with an unrelated IMP is not an acceptable substitute.

## Test order

1. Clean respring.
2. Initialize Lara RemoteCall to SpringBoard.
3. Press **V6.3.7: Enable Native Visual Follow** once.
4. Leave/terminate Lara.
5. Rotate portrait -> upside-down -> portrait at least 20 times.
6. Check status bar and Dock separately.
7. Lock/unlock, open an app and return Home, open Control Center and Notification Center, then repeat rotations.
8. Leave the phone running for at least 30–60 minutes with Lara closed.
9. If a respring occurs, capture the SpringBoard/Lara logs before enabling any older experimental controls.

Expected install logging includes `V6.3.7 NATIVE-VISUAL ready` and six or fewer observer registrations depending on which live objects/selectors resolve. There should be no idle stream of RemoteCall orientation probes.
