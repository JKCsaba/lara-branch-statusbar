# Lara Island 12.8 — experimental manual portrait lock

Based directly on the working v12.0 source. This adds two separate controls:
**Lock Island in Portrait** and **Restore Island Rotation**. The existing
v12.0 Move/Restore position controls keep their original behavior.

This is source code for building an experimental IPA. It has not been compiled
with Xcode or tested on an iPhone. It is not a confirmed fix for expansion,
clipping, touch alignment, or iOS 18.4 compatibility.

## Build and try

1. Build with the included GitHub Actions workflow or scripts/build_ipa.sh on
   a Mac with Xcode and ldid. The app display name is Lara Island 12.8 and its
   bundle version is 129. Sideload the resulting IPA as usual.
2. Start from a fresh SpringBoard session if any earlier Island experiment
   was applied. Initialize Lara and enable the upside-down support as usual.
3. Hold the phone **normally upright**. Start a timer or music. Let the Island
   settle in its ordinary portrait layout before pressing **Lock Island in
   Portrait**. Keep the phone upright while that action runs.
4. Turn the phone upside down. Use the existing **Move Dynamic Island** control
   with your previously working offset. The lock itself does not move it.
5. Check compact and expanded activities, labels, animation direction and
   taps. A success message means the replacement handler was read back; it
   does not establish that these behaviors work.
6. To undo, press **Restore Island Rotation**, then rotate the phone once.
   Restore position separately if desired. A respring/reboot clears the lock.

## What changed

The experiment suppresses future calls to
SBSystemApertureController's
_applyOrientation:withPreviousOrientation:animationSettings: after the Island
has settled naturally in portrait. It does not call that private handler with
fabricated animation settings. It also freezes landscape orientation; this is
a manual portrait-only experiment, not a selective upside-down orientation
remapper.

Before installation, it verifies the method's argument and return types,
rejects an inherited target method, and checks the exact instructions of an
existing constant-return leaf implementation before using it as a void no-op.
It requires an Island window and two normal-portrait observations from
SpringBoard. These checks cannot prove the aperture's internal layout has
settled; holding it upright before pressing Lock remains necessary.

The original implementation is saved under a unique selector on the same
SpringBoard class. This allows Restore after reopening Lara, provided that
SpringBoard has not restarted. A detected conflicting implementation is not
overwritten. If a call fails after a mutation, do not assume nothing changed:
use Restore or start a fresh SpringBoard session.

The handler can do more than rotate content. Suppressing it may affect layout,
visibility, or activity transitions. Moving the full-screen window can also
still cause clipping. If the Island is missing or expansion remains wrong,
restore rotation and position; this prototype has not solved that outcome.

## Scope and verification

The original v12.0 rc.m is retained byte-for-byte as a prefix. Other than the
new rc.m section, changes are limited to rc.h, RemoteView.swift, app display
name/build metadata, and these notes. No dylib, global rotation patch, view
transform, recurring timer, or view-tree scan was added. RotationHook,
RemoteCall, build scripts and workflows retain their v12.0 bytes.

Local checks cover donor instruction acceptance/rejection, baseline file
comparison, plist/version consistency and ZIP integrity. They do not replace
an Xcode build or device testing.

Result codes: 0 = change read back; 1 = already in requested state; -1 = invalid
RemoteCall; -2 = no unique Island window; -21 = unsupported target method;
-22 = unsupported donor instructions; -23 = normal portrait was not observed;
-24 = saved-state/implementation conflict; -25 = runtime operation failed.

Primary reference for the separate content-orientation handler:
https://gist.github.com/khanhduytran0/e5fedf77c970464faff4660164518dba
The reference is older than iOS 18.4; runtime checks are not evidence of full
behavioral compatibility. This implementation is independent and is not the
reference jailbreak tweak.
