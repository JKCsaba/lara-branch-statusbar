# Lara V6.2 Low-Churn Auto-Follow

This revision is based directly on V6.1 Locked after physical-device testing on iPhone 12 / iOS 18.4.

## Locked / unchanged

The proven V6 status-bar geometry is unchanged byte-for-byte in these functions:

- `set_status_bar_v6_absolute_transform_safe`
- `sync_v6_status_bar_to_active_orientation`
- `enable_v6_safe_status_bar_autofollow_base`

Normal portrait still maps to identity and portrait-upside-down still maps to +pi rotation plus the live-calculated opposite-edge Y translation.

## Stability change

The auto-follow watchdog is reduced from 400 ms to 30 seconds.

- V6.1: ~9,000 RemoteCall orientation probes/hour.
- V6.2: ~120 probes/hour.
- The transform/accessory code still runs only when the portrait orientation actually changes.
- A `V6.2: Sync Now` button gives an immediate manual update without waiting for the next 30-second watchdog tick.

The queue QoS is lowered from `.userInteractive` to `.utility` because the 30-second watchdog is no longer latency-critical.

## Dock + Search lift

Default lift is now 23 pt.

The already-proven dock lift code remains the base. V6.2 additionally moves the Home Screen `pageControl` / Search pill by the exact same Y translation so it keeps its spacing relative to the dock.

Resolution order:

1. Ask the live root-folder controller for `pageControl` when available.
2. Fallback to a bounded search for `SBIconListPageControl` in the live root-folder view tree.

If the Search control cannot be found, the dock lift still applies and the function logs the miss rather than failing the dock change.

## Gradient fix

The V6.1 gradient inserted a `CAGradientLayer` at index 0 of the root-folder layer. On the test device this produced no visible result, consistent with the layer being behind other SpringBoard content.

V6.2 instead creates a transparent noninteractive `UIView`, inserts it at subview index 0 of the dock container's parent (fallback: root-folder view), and places the clear-to-black `CAGradientLayer` inside that view. This positions it above the parent background while keeping it below the dock/Search subviews.

The overlay is only shown in portrait-upside-down and is hidden again in normal portrait.

## Shortcuts

The V6.1 BulletinBoard Shortcuts-notification controls remain present and unchanged in this stability-focused revision. Test them separately after confirming status-bar + dock stability; do not enable every experimental control at once while diagnosing SpringBoard resprings.

## Recommended test order

1. Clean respring.
2. Initialize SpringBoard RemoteCall.
3. Press `V6.2: Low-Churn Auto-Follow — One Tap` only.
4. Use the phone for at least 30–60 minutes.
5. Rotate normal/upside-down and either wait up to 30 seconds or press `V6.2: Sync Now`.
6. Enable Dock + Search Lift at 23 pt and test another 30–60 minutes.
7. Only then enable the gradient and verify visibility/stability.
8. Test Shortcuts blocking separately.

If V6.2 still causes delayed resprings with only Auto-Follow enabled, the remaining continuous RemoteCall watchdog should be removed entirely and the phone should use static upside-down state plus explicit Sync actions instead.
