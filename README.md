# Lara status-bar / floating dock V5

Baseline: user-supplied V3-restored source.

This revision keeps the known-good V3 180-degree status-bar rotation + opposite-edge placement and exposes it as a single button together with the existing upside-down SpringBoard patch. It also adds a separate dynamic status-bar-window autorotation experiment and rewrites the floating-dock creation path so it no longer uses `doRemoteCallSyncOnMainThread`.

See `STATUSBAR_V5_COMBINED_NOTES.md` for the exact changes and test order.
