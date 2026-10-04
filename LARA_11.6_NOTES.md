# Lara 11.6 — Search Pill Lift

This source tree is reconstructed from the last full 11.3 source state, with the user-supplied working 11.3 `rc.m` restored exactly before the 11.6 addition.

## Preserved from 11.3
- Original Lara upside-down rotation patch.
- `Flip Status Bar + Lift Dock` / restore behavior.
- `Add Gradient` / `Remove Gradient` Home Screen + Cover Sheet gradient behavior.
- Existing Dock lift amount and status-bar transform logic.

## Added in 11.6
- Runtime resolution of `SBHSearchPillView`.
- Search only inside the validated Home Screen hierarchy derived from the stock Dock.
- Layer translation on SpringBoard's main thread.
- Adjustable 0–140 pt lift; default 60 pt.
- Separate `Lift Home Search Pill` and `Restore Home Search Pill` controls.

## Not included
- The later Dynamic Island experiment was removed from this branch.
- Orientation-lock behavior is unchanged from 11.3.
