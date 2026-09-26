# Lara 0.2 — Status Bar / Floating Dock V5

## Baseline

This tree starts from the user-supplied `lara-0.2-statusbar-v3-restored-source(2).zip`, which itself contains the working V3 asynchronous status-bar implementation.

V5 deliberately keeps the proven V3 layer transform available. It does **not** reintroduce the V3.1 `UIApplication.statusBarOrientation` / `_statusBarOrientationFollowsWindow:` overrides that caused the real-device regression.

## 1. Working V3 in one tap

The UI button **V5: Working V3 — One Tap** calls the existing combined V3-restored function:

1. `enable_upside_down(proc)`
2. 180-degree status-bar layer rotation
3. opposite-edge Y translation

The opposite-edge translation is derived from the live status-bar bounds and its parent bounds. On the measured test device that is still `956 - 61 = 895pt`; it is not stored as a hard-coded 895 constant.

This is the known-good static fallback. A static +pi/opposite-edge transform is only visually correct in portrait-upside-down. The manual **Fallback: Sync Current Orientation** button remains available.

## 2. V5 dynamic auto-follow experiment

The button **V5: Enable Dynamic Auto-Follow** is a new approach and should be tested separately from the known-good V3 fallback.

It:

1. enables SpringBoard portrait + portrait-upside-down support using the existing Lara code;
2. resolves the live status-bar view, its UIWindow, and its root view controller;
3. returns the old V3 layer rotation/translation to identity;
4. gives the status-bar root controller a portrait + portrait-upside-down mask (`0x6`) and `shouldAutorotate = YES` when available;
5. checks the concrete live status-bar window class for `setAutorotates:forceUpdateInterfaceOrientation:`;
6. replaces only that concrete window implementation with the immediate superclass implementation, saving the previous effective IMP for restoration;
7. calls `setAutorotates:YES forceUpdateInterfaceOrientation:YES` on SpringBoard's real main thread;
8. if available, asks the UIWindow to update immediately to SpringBoard's current `activeInterfaceOrientation`;
9. requests a supported-orientation update / `attemptRotationToDeviceOrientation`.

The important difference from V3.1 is that V5 does **not** rewrite SpringBoard's `statusBarOrientation` getter and does **not** force `_statusBarOrientationFollowsWindow:`. It targets the UIWindow autorotation layer instead.

The motivation is a known SpringBoard pattern where special system-window subclasses can suppress UIWindow autorotation. The V5 probe prints the concrete window class, superclass, active/status-bar orientation, root mask, and current/superclass implementations of `setAutorotates:forceUpdateInterfaceOrientation:`.

Expected success log begins with lines similar to:

```
(rc) V5 native context: barClass=... windowClass=... super=... rootClass=...
(rc) V5 override[status-window-autorotate]: ...
(rc) main-poll[v5-window-autorotates-yes]: completed ...
(rc) V5 native dynamic READY: activeOrientation=... window=... root=...; manual V3 transform is identity
```

Because this exact status-bar window behavior cannot be device-tested here, treat dynamic mode as experimental until the iPhone confirms normal -> upside-down -> normal works repeatedly.

## 3. Floating dock freeze fix

The original `enable_floating_dock()` wrapped dock creation and installation in `doRemoteCallSyncOnMainThread`. That helper commandeers SpringBoard's main thread using RemoteCall's exception-port mechanism. The status-bar work already demonstrated that leaving SpringBoard's main UI thread in that path can wedge interaction.

V5 removes `doRemoteCallSyncOnMainThread` from the floating-dock function.

For main-thread-only operations it now:

- constructs an `NSInvocation` in the RemoteCall thread;
- wraps it in `NSInvocationOperation`;
- queues `start` onto SpringBoard's actual main thread with `waitUntilDone:NO`;
- polls the operation's thread-safe `isFinished` state from the RemoteCall thread with a bounded timeout;
- reads the invocation return value only after completion.

This allows `createFloatingDockControllerForWindowScene:` to return its controller without an exception-port takeover of SpringBoard's main thread. Installation, stock dock hiding, and relayout use the same mechanism.

The button is now **V5: Enable Floating Dock (Safe)**.

## Recommended first-device test order

Use a clean SpringBoard session for each major experiment so results are unambiguous.

### A. Confirm the known-good one-click V3 path

1. Reboot/respring.
2. Initialize Lara RemoteCall on SpringBoard.
3. Rotate the phone to portrait-upside-down.
4. Press **V5: Working V3 — One Tap** exactly once.
5. Confirm that Home Screen orientation, status-bar 180-degree rotation, and opposite-edge placement match the old working V3 result.

### B. Test dynamic status-bar follow separately

1. Reboot/respring again.
2. Initialize RemoteCall.
3. Press **V5: Dynamic Status Bar Probe** and save the log.
4. Press **V5: Enable Dynamic Auto-Follow** once.
5. Rotate normal portrait -> portrait-upside-down -> normal portrait several times.
6. Press **V5: Dynamic Status Bar Probe** once in each portrait orientation if it does not follow correctly.

Do not apply the static V3 transform first for this test: dynamic mode intentionally owns the status bar with an identity layer transform.

### C. Test the dock independently

1. With SpringBoard responsive and RemoteCall initialized, press **V5: Enable Floating Dock (Safe)**.
2. The important success line is:

```
(rc) V5 floating dock READY controller=0x...; no doRemoteCallSyncOnMainThread used
```

If a `main-poll[...] timed out` line appears, stop there and collect the log. The helper intentionally leaves the operation queued instead of hijacking SpringBoard's main thread.

## Recovery

All changes made by these status-bar/dock functions are in SpringBoard process memory. A SpringBoard restart/device restart clears the transforms, method replacements, and floating dock controller state. If SpringBoard becomes non-responsive, use the hardware force-restart sequence rather than pressing more Lara actions while it is wedged.

## Build status

The source was mechanically inspected and the modified code paths were checked for balanced syntax/braces in this environment. It has not been compiled against Apple's iPhoneOS SDK or run on the physical iPhone here. Use the repository's existing GitHub Actions/Xcode build route.
