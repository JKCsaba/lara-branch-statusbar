## V6.3.6 minimal native orientation re-evaluation branch

This build is based on the V6.3.5 physical-device results. It removes the two V6.3.5 failure modes: no replacement of SpringBoard's real root-folder transition callback, and no status-bar/status-window notification feedback graph. It keeps the original Lara upside-down policy, applies the source-grounded System Aperture mask-6 experiment plus live status-root mask/autorotate policy, and optionally listens only to `UIDeviceOrientationDidChangeNotification` to request UIKit supported-orientation re-evaluation.

Start with **V6.3.6: Apply Native Masks Only** after a clean respring. Only if native Home Screen rotation still works normally should you try **Enable Device Event Re-evaluation**. See `STATUSBAR_V6_3_6_MINIMAL_NATIVE_REEVAL_NOTES.md`.
