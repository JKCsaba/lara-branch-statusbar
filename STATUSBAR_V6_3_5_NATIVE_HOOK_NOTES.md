# Lara V6.3.5 — Native SpringBoard rotation hook

Target used for the physical-device discovery: iPhone 12 (`iPhone13,2`) on iOS 18.4.

## What V6.3.4 proved

- `UIApplication.activeInterfaceOrientation` changes natively between `1` (portrait) and `2` (portrait upside down).
- The live root-folder controller has a concrete `viewWillTransitionToSize:withTransitionCoordinator:` override and the V6.3.4 retain-marker test observed that callback firing during a real physical rotation.
- Replacing that callback body temporarily did not prevent the Home Screen from completing the rotation on the test device.
- The V6.3.4 Native Rotation Refresh Pack corrected the status-bar path after SpringBoard had committed orientation `2`.

## V6.3.5 design

`V6.3.5: Enable Automatic Native Rotation` performs a one-time install in SpringBoard. It does not create a Lara-side timer and it does not keep `RemoteCall` alive in the background.

The install does the following:

1. Runs the existing upside-down policy enabling path once.
2. Clears legacy manual status-bar and Dock/Search transforms so UIKit starts from identity geometry.
3. Makes the live status-bar root controller advertise portrait + portrait-upside-down and autorotation.
4. Replaces only the concrete root-folder `viewWillTransitionToSize:withTransitionCoordinator:` override with the existing `setNeedsUpdateOfSupportedInterfaceOrientations` IMP. The original IMP is saved as an associated object for restoration.
5. Creates retained `NSInvocation` proxy observers inside SpringBoard for native orientation notifications. Those proxies call only existing zero-argument UIKit methods such as `setNeedsUpdateOfSupportedInterfaceOrientations`, `setNeedsStatusBarAppearanceUpdate`, and `setNeedsLayout` on the live status-bar/Home Screen/Dock objects.
6. Runs one immediate native refresh for the current committed orientation.

No executable payload is injected and no polling loop is installed. After the one-time install, the normal SpringBoard/UIKit event path is responsible for future updates.

## Dock behavior

V6.3.5 deliberately uses the stock Dock's native relayout path on each rotation instead of reintroducing the old 30-second/manual `transform.translation.y` watchdog. This is the path that can return to normal portrait automatically. The visible Search pill is intentionally untouched because the previous `pageControl` resolver was proven to target the wrong object on this build.

## Buttons

- **V6.3.5: Enable Automatic Native Rotation** — install the event path.
- **V6.3.5: Force Native Refresh** — run the same one-shot native refresh manually if you want to resync without reinstalling the hook.
- **V6.3.5: Disable + Restore Hook** — remove the proxy observers and restore the saved root-folder/status-root implementations.

The V6.3.4 controls are kept below these buttons only for diagnostics/fallback.

## Suggested first test

1. Start from a clean SpringBoard session.
2. Open Lara and wait until SpringBoard RemoteCall is ready.
3. Press **V6.3.5: Enable Automatic Native Rotation** once.
4. Leave Lara. Rotate portrait -> upside down -> portrait several times.
5. Check that the status bar and stock Dock relayout on both transitions without reopening Lara.
6. If either side misses one transition, reopen Lara and press **Force Native Refresh** once, then collect the `V6.3.5` log lines.

## Scope

This build intentionally does not touch the Home Screen Search pill, bottom gradient, Shortcuts notifications, floating dock, or unrelated tweaks.
