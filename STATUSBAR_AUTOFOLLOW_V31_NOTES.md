# Lara status-bar auto-follow V3.1

## Goal

This revision starts from the **working V3 source** and changes only the status-bar experiment requested for the iPhone 12 / iOS 18.4 test device.

V3 proved that the status bar can be made visually correct in portrait-upside-down by applying a fixed 180-degree rotation and moving the 61pt strip from y=0 to y=895 inside its measured 956pt parent. The remaining defect was that this was a **fixed transform**: after the Home Screen rotated back to normal portrait, the status bar stayed at the physical edge/rotation that belonged to portrait-upside-down.

V3.1 removes that fixed-orientation assumption. The status bar is returned to an identity transform and SpringBoard/UIKit is instructed to let the status-bar window follow SpringBoard's **active interface orientation**. There is no timer and no polling from Lara, so it can continue to work after Lara is backgrounded/suspended.

## What is deliberately unchanged

- Existing DarkSword / VFS / sandbox / RemoteCall setup.
- Existing `enable_upside_down()` behavior for Home Screen and Cover Sheet.
- Home/Lock supported orientations remain **portrait + portrait-upside-down only** (mask `0x6`).
- No landscape orientation is enabled by this patch.
- No status-bar style/layout spoofing is added. This revision does **not** attempt to fix a Nugget/device-layout override or change the notch model/status-bar content spacing.
- No wallpaper behavior, mute/silent shortcut behavior, or other requested future work is included.
- No synchronous SpringBoard-main-thread takeover is reintroduced. Main-thread UIKit work continues to use queued `NSInvocation` + `performSelectorOnMainThread(... waitUntilDone:NO)`.

## New combined button

The two V3 test steps are replaced in Lara's RemoteCall Customizer UI by one button:

`V3.1: Enable + Auto-Follow Status Bar`

It does all of the following in one call:

1. Calls the already-working `enable_upside_down()` so Home/Lock remain limited to normal portrait and portrait-upside-down.
2. Resolves the live SpringBoard status-bar view, its window, and the **live concrete root-view-controller class**.
3. Queues the old V3 layer transform back to identity:
   - `transform.rotation.z = 0`
   - `transform.translation.y = 0`
4. Overrides only the live status-bar root-controller class so:
   - `supportedInterfaceOrientations` returns mask `0x6`.
   - `shouldAutorotate` returns YES when that selector exists.
5. On the live concrete SpringBoard application class:
   - bridges `statusBarOrientation` to SpringBoard's existing `activeInterfaceOrientation` implementation when available;
   - overrides `_statusBarOrientationFollowsWindow:` to YES when that private selector exists.
6. Queues `setNeedsUpdateOfSupportedInterfaceOrientations` on the status-bar root controller.
7. Queues `+[UIViewController attemptRotationToDeviceOrientation]` when available.

The important design point is that V3.1 does **not** inject an orientation watcher. SpringBoard already tracks the main display's active interface orientation; this patch makes the status-bar window participate in that path instead of pinning a manual +pi/+895 transform.

## Why `class_replaceMethod` is used

The existing Lara upside-down tweak uses `method_setImplementation`, which is fine for its already-known concrete SpringBoard methods. For the new status-bar work, some target methods can be inherited from UIKit. Calling `method_setImplementation` on a Method obtained through inheritance risks changing a superclass implementation for more objects than intended.

V3.1 therefore calls `class_replaceMethod` on the **actual live concrete class**. This creates/replaces an override only on that class. The original effective IMP is stored as an associated `NSNumber` on the Class object before replacement so the status-bar-specific overrides can later be restored functionally.

## Restore behavior

`V3.1: Restore Status Bar` now:

- queues rotation and translation back to zero;
- restores the saved status-bar-root `supportedInterfaceOrientations` IMP;
- restores the saved status-bar-root `shouldAutorotate` IMP;
- restores SpringBoard's saved `statusBarOrientation` IMP;
- restores SpringBoard's saved `_statusBarOrientationFollowsWindow:` IMP;
- requests another orientation reevaluation.

It does **not** undo the older `enable_upside_down()` swizzles because the original Lara implementation never saved those IMPs. A SpringBoard restart/respring clears all of these in-memory session changes.

## Diagnostic button

`V3.1: Geometry + Orientation Probe` still prints the proven geometry and now also prints orientation state. The useful line is:

```text
(rc) STATUS BAR ORIENTATION V3.1 app=... window=... rootVC=... active=... status=... scene=... rootMask=0x... shouldAutorotate=... followsWindow=...
```

For the requested two portrait states, UIKit interface-orientation values are expected to be:

- `1` = Portrait
- `2` = PortraitUpsideDown

After V3.1 has applied successfully, the important expected values are:

- `rootMask=0x6`
- `shouldAutorotate=1` (if the selector exists on this runtime)
- `followsWindow=1` (if `_statusBarOrientationFollowsWindow:` exists)
- `status` should track `active` as the Home Screen changes between 1 and 2.

## Expected apply log

Exact pointers/classes vary by boot, but a successful run should contain lines similar to:

```text
(rc) status bar V3.1: queued identity transform (rotation=0 translation=0)
(rc) V3.1 auto-follow context: appClass=SpringBoard statusClass=... windowClass=... rootClass=...
(rc) V3.1 override[status-root-mask6]: supportedInterfaceOrientations ...
(rc) V3.1 override[status-root-autorotate]: shouldAutorotate ...
(rc) V3.1 override[status-orientation-follows-active]: statusBarOrientation ...
(rc) V3.1 override[status-follows-window]: _statusBarOrientationFollowsWindow: ...
(rc) async-main[statusbar-setNeedsUpdateOfSupportedInterfaceOrientations]: queued ...
(rc) V3.1 auto-follow READY: activeOrientation=1 statusBarOrientation=1 rootMask=0x6 failures=0
```

A selector can be absent on this exact iOS build; optional missing selectors are logged as `unavailable; skipping`. The final probe is what tells us which path the device actually exposes.

## First-device test sequence

1. Install/build this V3.1 source exactly like the working V3 build.
2. Open Lara, run DarkSword/setup as usual, and initialize RemoteCall on SpringBoard.
3. **Do not press the old V3 static rotate/move steps**; they are no longer exposed in the UI.
4. Press **V3.1: Enable + Auto-Follow Status Bar** once.
5. Wait for the `V3.1 auto-follow READY` line.
6. Return to the Home Screen.
7. Hold the phone normal portrait: the status bar should occupy the normal physical top edge.
8. Rotate the phone 180 degrees until Home Screen enters portrait-upside-down: the status bar should rotate and move with it to the new physical top edge.
9. Rotate normal -> upside-down -> normal at least twice. The bar should follow both directions without reopening Lara.
10. If the bar does not follow, initialize RemoteCall again if needed and press **V3.1: Geometry + Orientation Probe** once in normal portrait and once in portrait-upside-down. The two `STATUS BAR ORIENTATION V3.1` lines are the most useful output to send back.

## Safety / rollback

All orientation changes in this revision are process-memory changes in SpringBoard. No system file is overwritten by this feature. If SpringBoard behaves badly, force restart the iPhone (Volume Up, Volume Down, then hold Side until the Apple logo). A SpringBoard/device restart removes the in-memory transforms and method overrides.

## Build status

The source has been mechanically checked here for the intended diffs and API references. It cannot be compiled against Apple's iPhoneOS UIKit SDK or real-device-tested in this environment. The GitHub Actions macOS/Xcode workflow included in the source remains the build route, exactly as with V3.
