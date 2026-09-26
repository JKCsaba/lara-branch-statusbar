# Lara V6.1 — Locked V6 geometry + lower-churn auto-follow

## What is locked

The working V6 status-bar geometry is intentionally unchanged:

- Portrait: rotation = 0, translation.y = 0.
- Portrait Upside Down: rotation = pi, translation.y = live opposite-edge offset.
- The first button remains `V6: Safe Auto-Follow — One Tap` and still calls the proven `enable_v6_safe_status_bar_autofollow_base()` path.
- The old V5 UIWindow/native-autorotation experiment is not used by the V6 button.

## Why V6.1 exists

A spontaneous SpringBoard respring after several minutes means V6 cannot yet be called proven-stable. There is no crash log in this build, so the exact cause is not proven. The main avoidable risk in V6 was repeated exception-based RemoteCall work every 300 ms while Lara remained alive in the background.

V6.1 keeps the same visible behavior but reduces steady-state work:

- Caches the SpringBoard `UIApplication` remote object and the orientation selectors for the current RemoteCall session.
- Polls at 400 ms instead of 300 ms.
- A steady-state tick performs only the cached orientation message send.
- The status-bar layer is resolved and the proven transform is applied only after the orientation actually changes.
- Lara's existing external-action gate still prevents the timer from racing another RemoteCall tweak button.

This is a hardening step, not a guarantee that SpringBoard cannot crash. RemoteCall is still a private/exception-based mechanism and Lara deliberately keeps that session alive in the background while auto-follow is enabled.

## Optional upside-down Home Screen controls

These are deliberately separate from the V6 one-tap button.

### Dock lift

`Enable Upside-Down Dock Lift` moves the existing stock dock host upward only while `activeInterfaceOrientation == 2`. Normal portrait restores translation.y = 0 automatically.

Default: 22 pt. This is intended as the first-pass equivalent of roughly 3–4 mm on the target iPhone 12. The UI exposes 12–30 pt so the physical placement can be tuned on-device.

The dock is translated only; it is not resized or converted to the old iPad/floating-dock implementation.

### Bottom gradient

`Enable Upside-Down Black Gradient` creates one noninteractive `CAGradientLayer` under the root Home Screen view, clear at its top and black at its bottom. It is shown only in portrait-upside-down and hidden in normal portrait.

Default height: 100 pt. This is a first-pass visual implementation and needs on-device verification for exact z-order relative to wallpaper/dock.

## Shortcuts notifications

`Block Shortcuts Notifications` is a best-effort BulletinBoard settings approach, not the unsafe global notification-hook approach.

It looks up `com.apple.shortcuts` in `+[BBServer savedSectionInfo]`, tries the notification settings setters available on the current runtime, writes the modified dictionary with `+[BBServer writeSectionInfo:]`, and asks for a respring so BulletinBoard reloads its saved state.

Return values:

- 0: mutation/write path completed; respring and test.
- -2/-3: BBServer or savedSectionInfo unavailable.
- -4: Shortcuts section not present in saved section data.
- -5: no compatible writable settings selectors were found.
- -6: writeSectionInfo selector unavailable.

This may still fail to suppress the special Shortcuts bulletins on iOS 18.4. A true conditional dispatcher hook like the jailbreak tweak StopShortcutsNotifications requires code executing inside SpringBoard/notification dispatch and is not emulated here with a blind method replacement.

## Recommended test order

1. Fresh respring/reboot.
2. Initialize RemoteCall on SpringBoard.
3. Press only `V6: Safe Auto-Follow — One Tap`.
4. Rotate normal <-> upside-down several times, then leave it running for at least 10–15 minutes. Do not enable the new accessories yet. If SpringBoard resprings, collect the crash/panic log before adding anything else.
5. If stable, enable Dock Lift at 22 pt and test both orientations.
6. If stable, enable the Bottom Gradient and verify z-order/placement.
7. Test `Block Shortcuts Notifications` last, respring once if it returns 0, then run an automation with notifications enabled and test the post-reboot bulletin.

This order isolates regressions and preserves V6's already-proven visual geometry.
