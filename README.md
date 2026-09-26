## V6.3.4 callback-capture branch

V6.3.3 confirmed that SpringBoard's native `activeInterfaceOrientation` changes from `1` to `2` when the iPhone 12 rotates upside-down, while Candidate C is absent. V6.3.4 replaces the one-candidate-per-build loop with one bounded callback map, a temporary one-rotation firing detector for the best concrete callback override, a native refresh pack, and a control that applies the known-good status-bar + Dock/Search geometry from the current orientation. See `STATUSBAR_V6_3_4_CALLBACK_CAPTURE_NOTES.md`.

## V6.3.3 Candidate C branch

Physical-device V6.3.1/V6.3.2 testing found Candidates A and B absent on the target iPhone 12 / iOS 18.4 runtime. V6.3.3 keeps the crash-hardened no-polling/no-bulk-scan design and tests only `-[SBIconController setNeedsUpdateOfSupportedInterfaceOrientations]`. See `STATUSBAR_V6_3_3_CANDIDATE_C_NOTES.md`.

## V6.3.2 Candidate B branch

Candidate A was absent on the target iPhone 12 / iOS 18.4 runtime. V6.3.2 keeps the crash-hardened no-polling/no-bulk-scan design and tests only `-[SBIconController _updateContentViewOrientationAndLayoutIfNeeded]`. See `STATUSBAR_V6_3_2_CANDIDATE_B_NOTES.md`.

## V6.3 foreground event-discovery branch

This source disables the V6.2 background RemoteCall watchdog/keepalive and adds bounded SpringBoard orientation-method discovery plus guarded manual candidate invocation. See `STATUSBAR_V6_3_EVENT_DISCOVERY_NOTES.md`.

## V6.2 Low-Churn status-bar branch

See `STATUSBAR_V6_2_LOW_CHURN_NOTES.md` for the locked V6 geometry, 30-second watchdog, 23 pt Dock + Search lift, and revised gradient overlay.

# Lara status-bar / floating dock V5

Baseline: user-supplied V3-restored source.

This revision keeps the known-good V3 180-degree status-bar rotation + opposite-edge placement and exposes it as a single button together with the existing upside-down SpringBoard patch. It also adds a separate dynamic status-bar-window autorotation experiment and rewrites the floating-dock creation path so it no longer uses `doRemoteCallSyncOnMainThread`.

See `STATUSBAR_V5_COMBINED_NOTES.md` for the exact changes and test order.
