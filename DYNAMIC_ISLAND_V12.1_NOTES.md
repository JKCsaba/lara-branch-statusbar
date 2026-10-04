# Lara Island 12.1 — inward expansion prototype

## Confirmed starting point

The user confirmed that the 12.0 Island-window move works at 780 on iPhone 12/iOS 18.4. Expanded music grows toward the display edge and is clipped. This revision preserves the entire original 11.3 rc.m prefix and the complete 12.0 Island resolver/movement code. Existing Dock, status/navigation, Home/Lock gradients, Gestalt, RotationHook, RemoteCall transport and build workflows remain unchanged. Search experiments are absent.

## New behavior

Adds Place Island + Fix Expansion, default edge 780. It uses the confirmed Island-window resolver, then searches the Island scene delegate, SpringBoard application, Island root controller and its direct child controllers for a class-validated SBSystemApertureController. Named object fields and directly held fields explicitly typed as that controller are checked through Objective-C runtime metadata. There is no subview traversal or recursive controller walk. This controller access path is not device-confirmed.

The native _applyOrientation:withPreviousOrientation:animationSettings: method must be a concrete override with void return, five total arguments and q/q/@ explicit argument types. The existing _canShowWhileLocked donor used by the working basic rotation code must disassemble as a constant-return leaf before it is accepted: optional BTI c, optional matching PACIASP/RETAA or PACIBSP/RETAB, MOV W0 or X0,#1, and return. It reads no receiver/argument memory. The orientation method expects void, so the returned register is ignored. Unsupported instructions fail before the orientation override is installed.

An Island-specific alias retains the original native handler. Only SBSystemApertureController's orientation handler is temporarily replaced with the verified no-op, preventing subsequent global orientation events from applying a second native flip. The saved handler is invoked on the main thread with native portrait layout, previous upside-down orientation and nil animation settings. This private invocation and its nil settings are untested on iOS 18.4. The controller still performs its other layout/content methods normally. The override applies to that Island controller class; external/continuity Islands and landscape use are not supported by this prototype.

The old large window translation is cleared and the full native window frame is restored and read back while the visual transform is identity. The whole window is then rotated visually by pi radians. Its native portrait expansion direction therefore points into the display at the opposite end. A 64-point compact band is an inferred calibration from native height 844 and the user's working offset 780; it is not a measured container height. The correction is edge - (native window height - 64). On an 844-point window, edge 780 gives correction zero. Precise compact alignment may require adjustment.

Restore puts back the original orientation implementation, zeroes this prototype's visual rotation/translation, restores the captured window frame, then invokes the saved handler with the current system orientation. Implementation ownership is checked before overwriting an existing hook. Failed visual/native setup attempts Restore if RemoteCall remains usable. A failed transport or main-thread timeout can prevent complete rollback; a respring clears the runtime override and transforms.

## Install and use

1. Build this full ZIP through the existing GitHub Actions workflow and sideload. Confirm Lara Island 12.1.
2. Respring once to clear the old 12.0 shifted window, then initialize Lara and apply the working 11.3 controls as usual. A fresh 12.1 session refuses to treat a large existing 12.0 offset as the original window frame.
3. With music/timer active and the phone held upside down, open Dynamic Island — v12.1 (Manual), leave Island edge at 780, and tap Place Island + Fix Expansion.
4. Check compact text, expanded music growth, long press/tap, collapse/reopen and position. Restore Dynamic Island removes the override while this session remains active. Respring also clears it. Reinitializing/reinstalling the app while the override is active may require a respring because this prototype keeps restore state locally.

## Validation and limits

No Xcode compiler or connected device is available here. This is an uncompiled, device-untested orientation/expansion revision. 12.0 movement is user-confirmed; 12.1 controller access, native orientation invocation, expansion behavior and touch conversion are not. The new mode is for manual portrait-upside-down use, not an automatic orientation-follow mode.

Checks completed: exact preservation of 87,598 original 11.3 rc.m bytes and all 12.0 rc.m bytes, five-file baseline change scope, version/plist/UI checks, original helper reuse and hook restore/ownership paths, and ZIP byte verification. The actual constant-leaf verifier was compiled as host C with warnings as errors and tested against six accepted and nine unsafe/unsupported sequences. LLVM ARM64 with Apple A14/pointer-authentication features independently decoded every accepted instruction encoding. These tests do not constitute an iOS build or a device test.

## Key results

- -10: old large Island offset detected; respring before setup.
- -12: system orientation was not portrait upside down.
- -20: override/alias belongs to an earlier session; respring to clear it.
- -21: a native Island controller was not resolved.
- -22: orientation implementation ownership/replacement failed.
- -23: visual transform/frame setup failed.
- -24: native orientation invocation failed.
- -25: method/alias signature unsupported.
- -26: the donor's constant-leaf instructions could not be verified.

## Primary reference

https://gist.github.com/khanhduytran0/e5fedf77c970464faff4660164518dba separates native aperture orientation and visual/window orientation. This revision independently adapts that separation to Lara's existing RemoteCall and runtime APIs; it does not inject that jailbreak tweak or a new dylib.
