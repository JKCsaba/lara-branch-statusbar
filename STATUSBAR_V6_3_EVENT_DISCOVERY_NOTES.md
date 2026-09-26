# Lara V6.3 — Foreground Event/Orientation Discovery

V6.3 replaces the V6.2 background watchdog experiment with a foreground-only discovery build.

## Why this revision exists

Physical-device testing on the target iPhone 12 / iOS 18.4 showed that the known-good V6/V3 status-bar transform itself is correct, but keeping Lara's exception-based SpringBoard RemoteCall alive in the background is not sufficiently stable. V6.2 still produced delayed SpringBoard resprings even after reducing its watchdog from 400 ms to 30 seconds.

V6.3 therefore starts **no orientation timer**, enables **no silent-audio keepalive**, and no longer preserves SpringBoard RemoteCall when Lara enters the background. Leaving Lara tears RemoteCall down through the original background cleanup path.

The goal of this build is narrower: identify the SpringBoard object/method that already participates in the Home Screen orientation transition, and identify any native no-argument update method that can refresh the status-bar path without Lara continuously polling.

For this diagnostic build, Lara itself also advertises `UIInterfaceOrientationPortraitUpsideDown` on iPhone. That lets the phone enter orientation `2` while Lara remains foregrounded, so candidate methods can be invoked without keeping RemoteCall alive in the background. This is a diagnostic-app capability only; it does not change the Home Screen orientation mask beyond the existing `enable_upside_down()` swizzles.

## Unchanged known-good geometry

The V6 status-bar transform code is intentionally untouched:

- portrait -> rotation 0, translation 0
- portrait-upside-down -> rotation +pi, opposite-edge Y translation calculated from live bounds

`V6.3: Prepare Rotation Baseline` calls the existing upside-down SpringBoard swizzles and performs one immediate known-good V6 sync. It does **not** start a watcher afterward.

`Fallback: Manual Known-Good V6 Sync` remains available for comparison.

## New V6.3 tools

### Probe Live Orientation State

Prints:

- SpringBoard `activeInterfaceOrientation`
- `statusBarOrientation`
- main scene `interfaceOrientation`
- status-bar root-controller orientation mask / autorotation state
- status-bar frame/bounds, parent bounds, and status-window bounds
- the concrete runtime class for ten live targets

Targets are:

0. SpringBoard application
1. status-bar view
2. status-bar window
3. status-bar root view controller
4. main window scene
5. home-screen controller
6. `SBIconController` shared instance
7. root-folder controller
8. main-window-scene delegate
9. `SBMainWorkspace` shared instance

### Quick Discover Candidates

This is the recommended first discovery step. Instead of dumping every Objective-C method in SpringBoard, it probes a bounded selector matrix against the ten live targets. That keeps RemoteCall traffic much lower.

The matrix includes update/action selectors such as:

- `updateContentViewOrientationAndLayoutIfNeeded`
- `setNeedsUpdateOfSupportedInterfaceOrientations`
- status-bar/orientation update variants
- `setNeedsLayout` / `layoutIfNeeded` on relevant view/controller targets

It also records argument-taking transition/event methods as **metadata-only hook candidates**, including:

- `viewWillTransitionToSize:withTransitionCoordinator:`
- `_updateToInterfaceOrientation:duration:force:`
- `_rotateWindowToOrientation:updateStatusBar:duration:skipCallbacks:`
- `_performInitialLayoutWithOrientation:`

The seed names are only hypotheses. V6.3 verifies their existence and real runtime type encodings on the device before reporting them.

Each discovered entry is logged as:

```text
(rc) V6.3 CANDIDATE #N kind=ACTION|EVENT target=... class=... selector=... args=... imp=... mode=... types=...
```

Objective-C `args=2` means the method has only implicit `self` + `_cmd` and therefore takes **no explicit arguments**.

### Deep Scan Selected Target

This is optional and should only be used if Quick Discover does not expose a useful method.

It scans only:

- the selected target's concrete class, and
- one superclass,

with a hard cap of 96 inspected methods total. It filters names for orientation/rotation/status-bar/interface/transition/layout/update terms and adds matches to the candidate table.

This is intentionally not an all-SpringBoard class dump.

### Invoke Selected No-Arg Candidate

A candidate can only be manually invoked when its Objective-C argument count is exactly 2 (`self` + `_cmd`). Argument-taking transition/event methods are refused and remain metadata-only.

The invocation is queued onto SpringBoard's main thread using Lara's bounded `NSInvocationOperation` helper. After invocation, V6.3 automatically prints another orientation/geometry probe.

The visual result must still be checked on-device. The useful success case is:

1. Home Screen is already portrait-upside-down.
2. Status bar is in the wrong state.
3. Invoke one no-argument candidate.
4. Status bar immediately becomes correct without calling the manual V6 transform.

If that happens, send the full `V6.3 CANDIDATE` and `V6.3 INVOKE` lines for that candidate. That gives the next revision a concrete native SpringBoard update path.

## Background behavior

V6.3 restores normal Lara behavior:

- entering background -> destroy RemoteCall
- no status-bar timer
- no status-bar audio keepalive
- no automatic foreground sync

The one-time method swizzles installed by `enable_upside_down()` live inside SpringBoard and remain until SpringBoard resprings. The RemoteCall channel itself does not need to remain alive for those existing IMP replacements.

## Recommended first test

1. Clean respring.
2. Open Lara and initialize SpringBoard RemoteCall.
3. Keep Lara in normal portrait and press **V6.3: Prepare Rotation Baseline** once.
4. Press **V6.3: Quick Discover Candidates** and save the log before invoking anything.
5. While staying inside Lara, rotate the phone 180 degrees. This V6.3 build allows Lara itself to enter portrait-upside-down, so SpringBoard's active orientation can become `2` without backgrounding Lara.
6. Press **V6.3: Probe Live Orientation State** and confirm the log reports `active=2` (and ideally `scene=2`).
7. If the status bar is now visually wrong, inspect the logged candidates. Prefer an `ACTION` candidate with `args=2` whose selector is clearly orientation/status-bar/update related.
8. Select that candidate number and press **V6.3: Invoke Selected No-Arg Candidate** once.
9. Note whether the status bar immediately moved/rotated into the correct state.
10. Do **not** enable Dock/Search lift, gradient, or Shortcuts experiments during this isolation test.

If Quick Discover has no plausible update method, deep-scan target **6 (`SBIconController`)** first, then target **3 (status-bar root VC)**, then target **1 (status-bar view)**.

## Build validation

The modified Swift files pass `swiftc -frontend -parse` in the current environment. The complete iOS target cannot be compiled here because the Apple iPhoneOS SDK/UIKit/Foundation frameworks are not available in this container. The repository's existing macOS/Xcode workflow remains the real build check.
