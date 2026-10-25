# No-poll safety revision (source variant, not device verified)

The original v12.10 ZIP contained `rc_invoke_objc_on_main_poll()` twice in
`rc_island1210_orientation()`, polling `NSInvocationOperation.isFinished` on
SpringBoard through Lara's RemoteCall. This variant removes that entire
orientation-preflight function, both calls, the `usleep` between them, and the
Island-window traversal formerly used as a precondition to the new hook.

Pressing Lock now makes only **one-off** RemoteCall requests: checking a
small allowlist of classes/methods, verifying the donor instruction sequence,
saving the original IMP, installing a constant-portrait IMP, and reading back
the change. No repeating timers, scheduled operations, event callbacks, or
SpringBoard-to-Lara requests were added. After the button finishes, its IMP
works entirely in SpringBoard and Lara can be closed. Returning the one-time
result to Lara's UI is normal app-local logging, not SpringBoard calling Lara.

**Scope:** Other pre-existing features elsewhere in Lara may use polling,
including the original helper `rc_invoke_objc_on_main_poll`, but this Island
orientation action does not call it. If you activate those unrelated controls,
their own behavior remains unchanged.

**Risk:** RemoteCall and modifying SpringBoard's Objective-C method tables
are still intrusive, and a crash/respring remains possible. No Xcode build
or iOS 18.4 runtime validation was performed.

**User precondition:** Hold the phone upright before pressing Lock. The code
no longer tries to verify that orientation, specifically to avoid polling.

---

# Lara Island v12.10 — narrow orientation-query experiment

## Status: SOURCE PATCH ONLY — NOT AN ON-DEVICE VERIFIED FIX

Base: Git commit `2c3efe1` (v12.8). No v12.9 diagnostic code is present.
This revision **does not prove** correct compact/expanded Dynamic Island layout on iOS 18.4.

### Confirmed from the source

* v12.0 window movement identifies `SBSystemApertureWindow` and updates `frame`; it is unchanged.
* v12.8 `SBSystemApertureController` `_applyOrientation:withPreviousOrientation:animationSettings:` was not present on the user's device, per device logs in the prior conversation; the v12.8 hook never installed.
* `enable_upside_down()` does not modify the System Aperture view controller's orientation mask. Its notes show an existing portrait-only mask (`2`).
* v12.9 used broad remote metadata operations and crashed SpringBoard on the user's device. This branch uses v12.8 and excludes all v12.9 diagnostics.

### Public-source support (not evidence of iOS 18.4 implementation)

* 2024 Dynamic Island tweak by khanhduytran0: https://gist.github.com/khanhduytran0/e5fedf77c970464faff4660164518dba — separates window autorotation from content orientation, but relies on old selector.
* iOS 18.1 SpringBoard header list: https://developer.limneos.net/?framework=SpringBoard&ios=18.1 — includes System Aperture element-orientation authority/observing types.
* iOS 18.2 runtime header repositories: https://github.com/lechium/iPhone_OS_18.2_22C150 and https://github.com/qingralf/iOS18-Runtime-Headers — public archives, but their contents do not verify the specific iOS 18.4 method's owner or call sites here.
* Apple UIKit orientation docs: https://developer.apple.com/documentation/uikit/uiinterfaceorientation ; https://developer.apple.com/documentation/uikit/uiviewcontroller/supportedinterfaceorientations
* Apple view rotation note: https://developer.apple.com/library/archive/qa/qa1890/_index.html

### Actual behavior change

The experimental **Lock Island in Portrait** button no longer targets `_applyOrientation:withPreviousOrientation:animationSettings:` and does not freeze an orientation callback.

It locates exactly one declared method named
`activeElementInterfaceOrientationForSystemApertureElementOrientationObserver:` on a small allowlist of three potential owners (`SBSystemApertureElementAuthority`, `SBSystemApertureController`, `SBSystemApertureViewController`). It verifies return and argument types, checks a small ARM64 constant-one donor, and replaces the query's IMP to always return `UIInterfaceOrientationPortrait` (`1`). The expected (UNVERIFIED) result is that a caller requesting the Island element's orientation sees portrait even when SpringBoard itself is upside down.

No view/window transforms, no orientation events or refresh calls are synthesized. Window movement remains exactly v12.0.

If zero/multiple methods match, type checks fail, or the donor cannot be verified, it does NOT install an override. If another patch owns the method, it refuses. It stores its original IMP under a uniquely named selector for Restore across Lara relaunches, but this does not survive a SpringBoard restart (which automatically resets it). `Restore Island Rotation` restores the previous IMP.

**Important limitation:** The matched method may not control the compact/expanded Island's actual geometry. Matching a selector and an IMP readback proves only that the hook is installed, not that the Island looks or expands correctly. It may also affect element behavior unrelated to the desired orientation. Device-level validation is required.

### How to build

Push this source on a separate GitHub branch and manually start the included GitHub Actions workflow (macOS/Xcode). Check the build log, then obtain `lara-ipa` artifact from a PR or `release-ipa` artifact from a workflow dispatch. There is no locally compiled or signed IPA included. Keep the previous working IPA.

### Test and rollback

1. Keep v12.8 IPA available. Back up any device-specific settings you need.
2. Install this build. Initialize SpringBoard RemoteCall, enable the existing working upside-down tweaks normally.
3. Hold the phone upright. Start music/a timer to observe the Island if desired. Tap **Lock Island in Portrait** once. If it says unsupported, do not repeat without new evidence.
4. Only if it reports successful hook installation, rotate upside down, test compact and expanded content/touches, then use **Move Dynamic Island** with the previously working offset (780 points) if needed.
5. Tap **Restore Island Rotation** and rotate once, or respring to clear the experimental IMP. A respring is also the rollback if layout is broken or Restore does not work.
6. Verify unrelated status-bar, dock and gradients still behave like v12.8.

### Codes

* `0` — Method-IMP change (or restore) was verified; **NOT** proof of correct UI.
* `1` — Already active / already restored.
* `-21` — No unique verified target method: NO hook installed.
* `-22` — Donor gadget incompatible/unavailable: NO hook installed.
* `-23` — Removed from this no-poll variant (no runtime orientation preflight).
* `-24` — Unexpected owner/other modification; do not retry without respring.
* `-25` — Runtime setter/readback/add operation failed. Inspect log; respring if uncertain.
* `-2` — Removed from this no-poll variant (no Island window preflight).

### Validation performed without the device

* Source rooted in the exact v12.8 Git commit (`2c3efe1`).
* Only four existing files changed, in addition to this notes file.
* `git diff --check` passed.
* Isolated Objective-C syntax check of the new method-hook block passed with a minimal non-Apple stub harness.
* No full Xcode build, codesigning, iPhone install or SpringBoard runtime validation was possible in this Linux environment.
