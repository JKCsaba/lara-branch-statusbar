# Lara status-bar V6.3.7 native visual follow

Start from a clean respring and test **V6.3.7: Enable Native Visual Follow**. This keeps the V6.3.6 no-polling architecture and adds only delayed `setNeedsLayout` invalidations for the live status-bar view and stock Dock host. See `STATUSBAR_V6_3_7_NATIVE_VISUAL_FOLLOW_NOTES.md`.

## V6.3.6 minimal native orientation re-evaluation branch

This build is based on the V6.3.5 physical-device results. It removes the two V6.3.5 failure modes: no replacement of SpringBoard's real root-folder transition callback, and no status-bar/status-window notification feedback graph. It keeps the original Lara upside-down policy, applies the source-grounded System Aperture mask-6 experiment plus live status-root mask/autorotate policy, and optionally listens only to `UIDeviceOrientationDidChangeNotification` to request UIKit supported-orientation re-evaluation.

Start with **V6.3.6: Apply Native Masks Only** after a clean respring. Only if native Home Screen rotation still works normally should you try **Enable Device Event Re-evaluation**. See `STATUSBAR_V6_3_6_MINIMAL_NATIVE_REEVAL_NOTES.md`.
