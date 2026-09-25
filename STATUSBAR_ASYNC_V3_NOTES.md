# Lara 0.2 — Status Bar Async V3

## Why this revision exists

V2 successfully proved that SpringBoard exposes a useful narrow status-bar object on the test device:

- device: `iPhone13,2` (iPhone 12)
- status-bar frame: `440 x 61`
- status-bar bounds: `440 x 61`
- parent/screen bounds observed by SpringBoard: `440 x 956`
- status bar origin: `y = 0`
- mirrored opposite-edge origin: `956 - 61 = 895`

V2 then froze SpringBoard while using Lara's synchronous `doRemoteCallSyncOnMainThread` path. The captured failure sequence was:

- Lara called `dispatch_async_and_wait_f` for SpringBoard's main queue.
- Lara did not receive the expected main-thread exception handshake.
- `debug_status_bar_geometry() -> -3` / `restore_status_bar() -> -7` followed.
- subsequent RemoteCalls reported `Don't receive first exception on new thread`.
- SpringBoard eventually respawned/resprung.

The phone/kernel itself remained alive, which is consistent with a SpringBoard/userspace RemoteCall deadlock rather than a kernel panic.

## V3 design

V3 removes the synchronous main-thread takeover from all three status-bar test operations.

Instead it:

1. Uses Lara's normal dedicated RemoteCall thread to resolve the live SpringBoard status-bar layer.
2. Builds an `NSInvocation` targeting `-[CALayer setValue:forKeyPath:]`.
3. Copies/retains the Objective-C arguments in the invocation.
4. Queues `-[NSInvocation invoke]` onto SpringBoard's normal main run loop via:
   `performSelectorOnMainThread:withObject:waitUntilDone:` with `waitUntilDone = NO`.
5. Returns to Lara immediately. Lara never owns/waits on SpringBoard's main thread for these operations.

A tiny deliberate process-local invocation retain is used to remove lifetime ambiguity between the RemoteCall thread and the main run loop. A SpringBoard restart clears it; the amount is negligible for testing.

## Staged test controls

### Stage 1 — `V3 Async: Rotate Status Bar 180°`

Queues only:

- `transform.rotation.z = pi`

It does **not** translate the status bar. This is the safest first test and proves whether the asynchronous scheduling mechanism and target layer are correct.

Expected successful Lara log:

```
(rc) async-main[statusbar-rotate-pi]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) status bar async: 180-degree rotation queued; no translation requested
reverse_status_bar() -> 0
```

Expected visual result for Stage 1: status-bar contents rotate 180 degrees but remain on the same edge.

### Stage 2 — `V3 Stage 2: Move to Opposite Edge`

Use this **only if Stage 1 works and SpringBoard remains fully responsive**.

V3 reads the current status-bar frame and its parent bounds, mirrors its Y origin, and queues:

- `transform.translation.y = mirroredY - currentY`

For the already observed geometry, this should be:

- parent height = 956
- bar height = 61
- current Y = 0
- target Y = 895
- translation Y = +895

Expected successful log is approximately:

```
(rc) async-main[statusbar-translate-opposite-edge]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) status bar async move: queued translationY=895.00 (targetY=895.00 parentHeight=956.00)
move_status_bar_to_opposite_edge() -> 0
```

### Restore — `V3 Async: Restore Transform`

Queues both components back to zero:

- `transform.rotation.z = 0`
- `transform.translation.y = 0`

Expected log:

```
(rc) async-main[statusbar-restore-rotation]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) async-main[statusbar-restore-translation]: queued NSInvocation on SpringBoard main thread (no wait)
(rc) status bar async: queued restore for rotation and translation
restore_status_bar() -> 0
```

### Read-only geometry probe

`V3 Read-Only Geometry Probe` no longer uses `doRemoteCallSyncOnMainThread`. It reads the status-bar geometry from Lara's ordinary RemoteCall thread and logs it as `STATUS BAR DEBUG V3-OFFMAIN`.

The previous device run already gave us the important geometry, so this button is optional.

## Exact recommended test order

1. Start from a clean SpringBoard (respring/reboot already done after the V2 freeze).
2. Open Lara and initialize the exploit / SpringBoard RemoteCall normally.
3. Run `Enable Upside Down` if the upside-down SpringBoard patch is not already active in this SpringBoard process.
4. Tap **V3 Async: Rotate Status Bar 180°** exactly once.
5. Verify all of these still respond before doing anything else:
   - Home gesture
   - Side button / lock UI
   - rotation
   - app launching / returning Home
6. Check whether the status-bar contents rotated 180 degrees.
7. If Stage 1 failed or anything became unresponsive: do not press Stage 2. Capture logs and force-restart/respring if needed.
8. If Stage 1 works normally, tap **V3 Stage 2: Move to Opposite Edge** once.
9. Capture a screenshot and the Lara lines beginning with `async-main[statusbar-` and `status bar async`.
10. If placement is wrong but SpringBoard remains responsive, tap **V3 Async: Restore Transform** once.

## What V3 intentionally does NOT change

- no changes to the exploit
- no kernel offsets changed
- no entitlements changed
- no persistence changes
- no changes to `RemoteCall.m` / the core RemoteCall mechanism
- no CATransaction takeover / synchronous main-thread wait for the status-bar test
- no hardcoded 895-point translation; Stage 2 recomputes the mirror from live geometry
- no automatic status-bar persistence across SpringBoard restart

The existing `doRemoteCallSyncOnMainThread` function remains in Lara because unrelated original Lara features use it, but the V3 status-bar buttons do not call it.

## Build

The existing `.github/workflows/build.yml` is included. Push this source to a GitHub repository and let GitHub Actions build `build/lara.ipa` on macOS/Xcode, then download the `release-ipa` artifact.

This environment does not contain the Apple iPhoneOS SDK, so the source was reviewed and packaged here but not compiled locally.
