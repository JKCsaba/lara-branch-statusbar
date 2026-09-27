## V6.3.6 minimal native orientation re-evaluation branch

This build is based on the V6.3.5 physical-device results. It removes the two V6.3.5 failure modes: no replacement of SpringBoard's real root-folder transition callback, and no status-bar/status-window notification feedback graph. It keeps the original Lara upside-down policy, applies the source-grounded System Aperture mask-6 experiment plus live status-root mask/autorotate policy, and optionally listens only to `UIDeviceOrientationDidChangeNotification` to request UIKit supported-orientation re-evaluation.

Start with **V6.3.6: Apply Native Masks Only** after a clean respring. Only if native Home Screen rotation still works normally should you try **Enable Device Event Re-evaluation**. See `STATUSBAR_V6_3_6_MINIMAL_NATIVE_REEVAL_NOTES.md`.
## V3 + stock Dock one-shot fallback

The **One-shot V3 Status Bar + Stock Dock** control reads SpringBoard's
committed interface orientation and applies the existing V3 absolute status-bar
transform plus the existing V6.1 stock Dock lift (23 pt upside down, zero in
portrait). It does not touch the Search pill, start a timer, install a hook,
or load a library. It is a manual control: press it again after each rotation.

The original automatic goal remains unresolved in a sideloaded app. The V3 and
V6.1 setters run from Lara's RemoteCall session. An in-process event observer
can invoke existing SpringBoard methods but cannot execute these Lara functions
after Lara exits. Loading Lara's separately signed dylib into SpringBoard is
not a viable replacement on ordinary iOS due to library validation, and the
V7/V8 trial resprang on the target device. Do not reapply that trial build.
