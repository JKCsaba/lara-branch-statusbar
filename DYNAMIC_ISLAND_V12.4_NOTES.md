# Dynamic Island 12.4 — window autorotation freeze

This build starts from the user-confirmed 12.0 implementation. It keeps the exact
12.0 window resolver and frame movement to the calibrated 780-point offset. The
new option targets only the resolved `SBSystemApertureWindow`:

1. checks that the window responds to `setAutorotates:forceUpdateInterfaceOrientation:`;
2. invokes that method on SpringBoard's main thread with both flags false;
3. moves the window using the existing 12.0 absolute frame helper;
4. applies the navbar-style `transform.rotation.z = pi` to the window layer.

It does not replace a controller method, call `_applyOrientation:...`, inspect
private controller ivars, run delayed work, enumerate subviews, or start an
orientation listener. Restore reverses the visual transform, reenables autorotation,
and restores the captured frame. A respring also clears the in-process state.

The selector is private and its iOS 18.4 behavior is not device-tested here. If
the window does not respond, the button returns an error before changing the
window. If the method exists but is unsafe on this build, SpringBoard may still
respring; use one clean test and return to the known-working 12.0 build.

Usage: enable upside-down, leave the offset at 780, tap **Freeze + Mirror Dynamic
Island** once. Test collapsed and expanded music. Do not tap the old Move button
(the v12.0 helper remains compiled only as the internal frame/restore helper).
