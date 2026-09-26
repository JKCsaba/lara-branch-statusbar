# Lara 0.2 — Status Bar V3 Restored

This revision starts from the exact Async V3 source, not V3.1/V4.

## Preserved from the working V3

- `enable_upside_down()` is unchanged.
- status-bar rotation is still `transform.rotation.z = pi`.
- opposite-edge placement still uses the status-bar's real parent geometry.
- all status-bar property writes are queued asynchronously on SpringBoard's main run loop with `waitUntilDone = NO`.
- there is no synchronous SpringBoard-main-thread takeover.
- none of the V3.1 status-bar orientation/native-follow swizzles are present.

## New combined control

`V3 RESTORED: Apply Everything` does the three operations that produced the good real-device result in one action:

1. enable portrait-upside-down for SpringBoard Home/Lock;
2. rotate the status-bar layer by 180 degrees;
3. move the status-bar layer to the opposite edge.

For the already verified 440x956 parent and 61pt bar, the translation remains +895pt.

The combined path computes +895 from the stable `bounds` sizes instead of an already transformed `frame`. This prevents repeated taps from compounding the translation, which the captured V3 log showed could otherwise become 2685, -4475, and so on.

## Current-orientation sync

`V3 RESTORED: Sync Status Bar Now` reads SpringBoard's current `activeInterfaceOrientation` (falling back to `statusBarOrientation`):

- portrait (`1`) -> rotation 0, translation 0
- portrait-upside-down (`2`) -> rotation pi, opposite-edge translation

This button is intentionally manual in this revision. It proves the two exact visual states without introducing another speculative automatic orientation hook. Once both states are confirmed correct on-device, an automatic trigger can be added around this already-proven state setter rather than replacing the V3 geometry again.

## Test order

1. Start from a clean SpringBoard.
2. Initialize SpringBoard RemoteCall.
3. Hold the phone upside-down and press `V3 RESTORED: Apply Everything`.
4. Confirm the Home Screen and status bar match the successful V3 result.
5. Rotate to normal portrait and press `V3 RESTORED: Sync Status Bar Now`; the bar should return to the normal top edge/upright state.
6. Rotate upside-down and press `Sync Status Bar Now` again; it should return to the proven V3 +pi/+offset state.

Expected log for the upside-down state is approximately:

```
(rc) async-main[v3r-rotation-pi]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) async-main[v3r-translation-opposite]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) V3-restored absolute: queued state=upside-down rotation=pi translationY=895.00
```

This environment does not contain Apple's iPhoneOS SDK, so the source was reviewed and packaged but not compiled locally.
