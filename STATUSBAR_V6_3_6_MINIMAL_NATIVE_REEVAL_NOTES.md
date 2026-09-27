# Lara V6.3.6 — minimal native orientation re-evaluation

## Why this exists

The V6.3.5 live-notification build installed eight observers, then entered the V6.3.4 full native refresh while those observers were already active. The device log ended before the refresh completed / before the V6.3.5 ready line, matching the immediate SpringBoard respring. The other V6.3.5 build replaced the live root-folder `viewWillTransitionToSize:withTransitionCoordinator:` implementation with an unrelated zero-argument orientation-reevaluation IMP; on-device that stopped normal rotation.

V6.3.6 removes both mechanisms.

## What V6.3.6 changes

- Keeps the existing Lara `enable_upside_down()` policy path.
- Does **not** replace `viewWillTransitionToSize:withTransitionCoordinator:` or any other live rotation transition callback.
- Patches only the two System Aperture classes documented by the original Lara source as hard-returning portrait-only masks, plus the currently live status-bar root controller, to support portrait + portrait-upside-down.
- `Masks Only` installs no notification observers.
- Optional event mode listens only for `UIDeviceOrientationDidChangeNotification`. It does not listen for status-bar orientation/frame notifications, so its own UI refresh cannot re-trigger its event source.
- Event actions are limited to `setNeedsUpdateOfSupportedInterfaceOrientations` and `setNeedsStatusBarAppearanceUpdate`; there are no automatic status-window/Dock `layoutIfNeeded` calls and no V6.3.4 full refresh pack.
- No Lara timer, watchdog, silent-audio keepalive, or persistent RemoteCall.

## Test order

1. Clean respring first. Do not test on top of V6.3.5 state.
2. Open Lara and wait for SpringBoard RemoteCall initialization.
3. Press **V6.3.6: Apply Native Masks Only** once.
4. Leave Lara. Rotate normal portrait -> upside-down -> normal portrait. Confirm the Home Screen itself still rotates normally. Observe status bar.
5. If Home Screen rotation remains healthy but status bar still does not follow, reopen Lara and press **V6.3.6: Enable Device Event Re-evaluation** once.
6. Repeat normal -> upside-down -> normal.
7. If a transition is missed, use **Force Orientation Re-evaluation** once. This does not run the old V6.3.4 full refresh pack.
8. Send the `V6.3.6` log lines and describe separately what Home Screen, status bar, and stock Dock did.

`Disable + Restore V6.3.6` removes the V6.3.6 observers and restores only the V6.3.6 status-root/System-Aperture methods. The original Lara orientation-policy changes are still one-shot SpringBoard changes; a respring is the clean full reset.
