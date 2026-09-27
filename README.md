## V6.3.6 minimal native orientation re-evaluation branch

This build is based on the V6.3.5 physical-device results. It removes the two V6.3.5 failure modes: no replacement of SpringBoard's real root-folder transition callback, and no status-bar/status-window notification feedback graph. It keeps the original Lara upside-down policy, applies the source-grounded System Aperture mask-6 experiment plus live status-root mask/autorotate policy, and optionally listens only to `UIDeviceOrientationDidChangeNotification` to request UIKit supported-orientation re-evaluation.

Start with **V6.3.6: Apply Native Masks Only** after a clean respring. Only if native Home Screen rotation still works normally should you try **Enable Device Event Re-evaluation**. See `STATUSBAR_V6_3_6_MINIMAL_NATIVE_REEVAL_NOTES.md`.
# Native status-bar and Dock rotation candidate

The **Install Native Status Bar + Dock Rotation** control packages
`RotationHook/LaraRotationHook.m` as a separate iOS arm64e dynamic library.
`scripts/build_ipa.sh` places and signs that image in the IPA. Lara applies the
V6.3.6 masks-only policy, loads the image into SpringBoard with a single remote
`dlopen`, and calls its installer once. A failed load returns `-3`; the control
does not install any hook in that case. iOS library validation or sandbox access
may reject loading a sideloaded app's library into SpringBoard; this has **not**
been verified on the target iPhone.

The runtime wraps the concrete root-folder controller's
`viewWillTransitionToSize:withTransitionCoordinator:` override, calls its
original IMP with the original arguments, and applies V3 absolute status-bar
geometry and the V6.1 23-point Dock lift after transition completion. It reads
`activeInterfaceOrientation` at that point, resolves current views each time,
and performs no Lara timer or recurring RemoteCall. The runtime image remains
loaded until SpringBoard restarts. The Remove control restores the original
IMP if it still owns that method; it does not unload the image.

This is source-level integration, **not a validated IPA**. Build requires Xcode,
the iOS SDK, `xcpretty`, and `ldid`; no macOS/iOS build or physical-device
rotation test was possible in this workspace. Test only after a clean respring,
with access to SpringBoard crash logs. A SpringBoard restart clears the hook.
The existing V6.3.6 diagnostic controls remain available independently.
