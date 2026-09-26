## V6.2 Low-Churn status-bar branch

See `STATUSBAR_V6_2_LOW_CHURN_NOTES.md` for the locked V6 geometry, 30-second watchdog, 23 pt Dock + Search lift, and revised gradient overlay.

# Lara status-bar / floating dock V5

Baseline: user-supplied V3-restored source.

This revision keeps the known-good V3 180-degree status-bar rotation + opposite-edge placement and exposes it as a single button together with the existing upside-down SpringBoard patch. It also adds a separate dynamic status-bar-window autorotation experiment and rewrites the floating-dock creation path so it no longer uses `doRemoteCallSyncOnMainThread`.

See `STATUSBAR_V5_COMBINED_NOTES.md` for the exact changes and test order.
