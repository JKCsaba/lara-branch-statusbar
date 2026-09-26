# Status Bar V6.3.4 — Callback Capture

V6.3.3 proved the orientation state itself is already correct on the target iPhone 12 / iOS 18.4 build:

- `UIApplication.activeInterfaceOrientation == 1` in normal portrait.
- `UIApplication.activeInterfaceOrientation == 2` in portrait-upside-down.
- Candidate C (`-[SBIconController setNeedsUpdateOfSupportedInterfaceOrientations]`) is absent.

V6.3.4 therefore stops the one-selector-per-build sequence. This revision does three things in one build:

1. **Bounded callback map** — checks a fixed set of plausible rotation/scene/status-bar callbacks on the live status-bar, window, root controller, main scene, Home Screen controller, root-folder controller, scene delegate, and `SBIconController`. It does not enumerate whole method lists and does not read remote class-name or type-encoding strings.
2. **Actual-firing detector** — chooses the highest-priority *concrete override* found by the map, temporarily replaces only that callback with `NSObject`'s existing `-retain` IMP, and uses the target object's retain-count increase as a one-rotation hit marker. The original IMP is stored as an associated object on the concrete class and is restored by the next button press.
3. **Native refresh + known-good control** — a native UIKit refresh pack can be tried without Lara transforms, and a separate control applies the already-proven V6 status-bar transform plus V6.2 Dock/Search lift from the current orientation value.

## Test order

Start from a clean SpringBoard if practical.

1. Open Lara and wait for SpringBoard RemoteCall to initialize.
2. Press **V6.3: Prepare Rotation Baseline** once.
3. While upright, press **V6.3: Probe Live Orientation State**. Expected result: `1`.
4. Press **V6.3.4: Capture Callback Map** once. The log will contain `V6.3.4 CALLBACK HIT` rows and, if a concrete override was found, one `V6.3.4 CALLBACK BEST` row.
5. Press **V6.3.4: Arm Best Callback Detector**. Expected result: `1`. This temporarily disables the original body of exactly one selected callback and replaces it with a harmless retain-count marker.
6. Leave Lara, rotate the physical phone exactly once to portrait-upside-down, wait for the Home Screen transition to settle, then reopen Lara.
7. Immediately press **V6.3.4: Check + Restore Callback Detector**. This restores the original IMP first, then reports either `result=FIRED`, `result=NO-HIT`, or `result=ambiguous`.
8. Confirm **V6.3: Probe Live Orientation State** returns `2` while upside-down.
9. Before using the manual control, optionally press **V6.3.4: Native Rotation Refresh Pack** and watch whether the status bar and/or Dock/Search move natively. This pack requests only existing UIKit/SpringBoard refresh/layout paths; it does not apply Lara's manual transform.
10. Finally press **V6.3.4: Apply Status Bar + Dock From Orientation**. This is the control: it reads the already-confirmed `activeInterfaceOrientation`, applies the known-good V6 status-bar transform, and applies the V6.2 Dock/Search lift from the same state. In orientation `2`, both should move to their upside-down geometry; in orientation `1`, both should restore.

## Important detector behavior

The detector is intentionally temporary. While it is armed, the selected callback's original body is not executed. Rotate **once**, then use **Check + Restore** immediately. If Lara is killed before you can restore, reopen it, run **Capture Callback Map** again, then press **Check + Restore**; the saved original IMP is stored on the SpringBoard class itself. A SpringBoard restart also clears the detector automatically.

A positive retain-count delta is strong evidence the selected callback fired during the physical transition. A zero/negative delta is treated as no hit; if the selected target object was recreated during the transition, the result is marked ambiguous.

## Callback priorities

The map prefers concrete overrides in roughly this order:

- `windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:` on the live main-window-scene delegate.
- `_windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:`.
- `viewWillTransitionToSize:withTransitionCoordinator:` on the live status/Home Screen/root-folder controller.
- `_updateToInterfaceOrientation:duration:force:` and `_rotateWindowToOrientation:updateStatusBar:duration:skipCallbacks:` on the live status window.
- Private `interfaceOrientationChanged:` / `deviceOrientationChanged:` style callbacks.
- Layout/trait callbacks only as lower-value fallbacks.

The map also reports whether each method is a concrete override or merely inherited from its superclass. Inherited UIKit defaults are not selected as the detector winner.

## What this build does not do

V6.3.4 still does not install the final permanent status-bar/Dock hook. The purpose is to get one piece of dynamic evidence for the real transition callback in a single build, while retaining the proven one-shot orientation-to-geometry path as a control.

There is no Lara timer, no silent-audio keepalive, no background polling loop, and no bulk runtime method enumeration.
