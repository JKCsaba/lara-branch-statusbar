# Status Bar + Dock V6.3.5 — Native Live Rotation

## What V6.3.4 proved on the target device

The V6.3.4 device log established the concrete facts used by this build:

- `UIApplication.activeInterfaceOrientation` is `1` upright and `2` portrait-upside-down.
- The live root-folder controller has a concrete `viewWillTransitionToSize:withTransitionCoordinator:` override, and the retain-count detector observed it firing during the physical 180-degree transition.
- The V6.3.4 **Native Rotation Refresh Pack** corrected the status bar and stock Dock while the phone was upside-down without applying the manual V3/V6 status-bar transform.
- The old Search/page-control target was not visually the Search button, so V6.3.5 deliberately leaves Search alone.

## V6.3.5 architecture

V6.3.5 keeps the original Lara upside-down policy call (`enable_upside_down`) and adds two narrow pieces:

1. The two System Aperture controller classes explicitly documented in the original Lara source as returning orientation mask `2` are given the same return-`6` mask used by Lara's working Home Screen patch. The replacement is installed on the concrete classes with `class_replaceMethod` through the existing saved-IMP helper.
2. SpringBoard's own `NSNotificationCenter` retains prebuilt `NSInvocation` objects that target existing zero-argument UIKit/SpringBoard refresh methods. They are registered for `UIApplicationDidChangeStatusBarOrientationNotification` plus `UIDeviceOrientationDidChangeNotification`. The invocations live in SpringBoard and are retained through an associated array on `UIApplication`, so Lara does not need to remain alive.

The notification callback uses a one-argument alias added to `NSInvocation`; its IMP is the normal `-invoke` implementation and its type encoding comes from `-invokeWithTarget:`. This lets NotificationCenter pass its notification object while the invocation dispatches its preconfigured zero-argument target action.

The registered actions are bounded and orientation-specific: status-bar view/window layout, root-folder supported-orientation reevaluation, optional zero-argument status orientation update methods if they actually exist, and stock Dock `setNeedsLayout` / `layoutIfNeeded`. Each notification first queues a retained inner `NSInvocation` asynchronously onto SpringBoard's main thread using the same `performSelectorOnMainThread:withObject:waitUntilDone:` mechanism already used elsewhere in Lara. The inner invocation then defers the real zero-argument refresh by 0.35 seconds with `performSelector:withObject:afterDelay:` so the physical 180-degree transition has time to commit before layout is forced. No Search/page-control transform is installed.

Before handing ownership back to UIKit, V6.3.5 clears any old Lara status-bar layer transform and the old V6.1 Dock translation. It then runs the already-tested V6.3.4 native refresh pack once for the current orientation.

## Test

1. Respring first if practical so the previous V6.3.4 manual transforms are gone.
2. Open Lara and wait for SpringBoard RemoteCall.
3. Press **V6.3.5: Enable Native Live Rotation** once. The return value is the number of persistent refresh actions installed.
4. Leave Lara. Rotate upright -> upside-down. Wait for the Home Screen transition to finish. The status bar and stock Dock should settle into the upside-down positions without another Lara button press.
5. Rotate upside-down -> upright. Both should return to their normal positions automatically.
6. Repeat several times, including leaving Lara in the background. There is no Lara timer/keepalive in this path.
7. If a single transition ever fails to settle, reopen Lara and press **V6.3.5: Native Refresh Now**. That runs the exact native refresh sequence from V6.3.4 without installing a manual transform.

**Remove Live Observers** unregisters only the V6.3.5 `NSInvocation` observer objects. Lara's original one-time orientation policy swizzles and the System Aperture orientation-mask patch remain for that SpringBoard lifetime; respring restores the process completely.

## Scope

This build intentionally implements only the requested status-bar rotation and stock Dock placement. It does not move the Home Screen Search control, does not run a polling loop, does not keep audio alive, and does not retain Lara's RemoteCall session after the normal app lifecycle cleanup.
