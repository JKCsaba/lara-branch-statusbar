# Lara Island 12.0 — manual position prototype

This full repository starts from the supplied working 11.3 baseline. Original rc.m bytes, including Dock, status/navigation and Home/Lock gradients, are preserved exactly. Gestalt, RotationHook, RemoteCall transport and build workflows are unchanged. Search experiments are absent.

## Behavior

Adds Dynamic Island — v12.0 (Manual), an adjustable signed offset, Move Dynamic Island and Restore Dynamic Island. The resolver snapshots UIApplication.connectedScenes and reads windows only from SBSystemApertureWindowScene instances. It accepts one SBSystemApertureWindow, rejects ambiguous matches, and performs no subview traversal. Discovery still uses remote UIKit getters on Lara's existing call thread; this has not been tested on the device.

The original window frame is saved for that RemoteCall/window pair. Move sets an absolute Y offset from that original, preserving X, size and existing rotation. Restore restores the captured frame during the same app/RemoteCall session. This uses the baseline's main-thread CGRect invocation helper. Frame origin is read back after 250 ms; code 0 means the requested origin was observed within 1 pt, not that visual placement or interaction is verified. No rotation hooks, automatic follow mode, or timer are installed.

## Use

Build via the existing GitHub Actions workflow, sideload, and confirm Lara Island 12.0. Initialize Lara normally and use existing 11.3 controls as before. Have a timer or music active, hold the phone upside down, open Dynamic Island — v12.0 (Manual) and tap Move Dynamic Island. The initial offset is the Lara screen height minus 104 pt, bounded to 0...900; this is an uncalibrated starting value, not a measured Island placement. Positive offsets aim toward the charging-port end. Adjust by 10 pt if needed. Restore is available within the same session.

## Limits and verification

Not compiled with Xcode and not device-tested here. The reference implementations are older iOS code; iOS 18.4 runtime target availability is checked when the action runs but not confirmed in advance. No guarantee of crash-free remote getter calls is made. Window repositioning can be overwritten by SpringBoard layout and can clip expanded content near a display edge. Visibility, current text orientation, touch alignment, expanded activities, landscape behavior and persistence require device validation. This is a manual positioning prototype, not a completed automatic opposite-edge Island feature.

Validation: five-file baseline change scope, full original rc.m byte preservation and preservation of all other original files, version/plist/UI checks, no recursive views or rotation hook mutation, and ZIP byte checks.

## Result codes

- -1: invalid input or existing RemoteCall error.
- -2: a unique Island window was unavailable, or discovery failed.
- -3: original frame read was invalid.
- -4: Restore had no matching saved frame for this session/window.
- -5: frame setter preparation/scheduling failed.
- -6: readback failed.
- -7: requested Y was not observed; it may have been rejected or reset.

## Primary implementation references

- https://github.com/ethxnn88/VisibleIsland/blob/main/Tweak.xm — positions SBSystemApertureWindow during layout.
- https://gist.github.com/khanhduytran0/e5fedf77c970464faff4660164518dba — separates aperture window rotation and content orientation.

The new code is an independent manual implementation; it does not include or install these jailbreak hooks.
