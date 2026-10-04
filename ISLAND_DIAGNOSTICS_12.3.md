# Lara Island Diagnostics 12.3

This full repository builds with the existing GitHub Actions workflow. Its app
display name is **Lara Island Diag 12.3**, with internal version **0.2.124 / 123**.
It is based on the user-confirmed 12.0 build and retains the original 11.3
rotation, status bar, Dock, gradients, and remaining tweaks. The 12.0 movement
implementation is byte-for-byte preserved; its UI default is calibrated to 780.
No 12.1 orientation override is included.

## Capture procedure

1. Respring once to clear any earlier Island hook. Start playing music so the
   Island is present. Do not use Move Dynamic Island.
2. Open Lara, run the exploit, initialize RemoteCall, and enable your usual
   upside-down tweaks. Keep Lara open.
3. For each state, set the phone to that state **before** tapping **Capture
   current state**: upright and collapsed; upside down and collapsed; upside down
   with music expanded. The button captures immediately and may briefly leave Lara
   busy. Wait for its result message before changing state. Do not leave Lara while
   the capture is running.
4. Use **Save what I saw** to record whether the upside-down Island text was
   upright or inverted and whether expansion grew into the display or clipped.
5. After all captures finish, tap **Share Island Diagnostics Report** and send the
   text file here. No RemoteCall is needed for sharing.

If Lara resprings or closes during a capture, reopen it and share whatever report
file exists. Do not initialize RemoteCall again just to export it.

## What it reads

- The same scene/window identification used by the working 12.0 movement code.
- Island scene interface orientation, window frame/bounds, window layer rotation
  and vertical translation, root controller/view class names, and the already
  loaded root view's frame/bounds and corresponding layer values.
- On the upright capture only: Objective-C class method metadata, type encodings,
  implementation addresses, and the first eight instruction words for the
  aperture window's autorotation accessors, aperture controllers' supported
  orientation methods, and the private native orientation application method.

The private orientation application method is **never called or replaced**.
There is no controller ivar lookup, recursive view/controller walk, UI setter,
automatic rotation listener, or orientation-forcing action in the collector.
It uses the baseline's existing floating-register spill technique to read CGRect
and scalar returns. Scratch allocations and transport operations remain part of
RemoteCall; observational does not mean the transport has zero side effects.

## Persistence and bounds

The dedicated `island-diagnostics-v12.3.txt` is appended, flushed, and fsynced
before each instrumented getter/runtime operation. It survives the normal
Logger reset on subsequent launches. A snapshot has an 18-second cooperative
deadline and a 160-step ceiling; neither can interrupt an already-running
RemoteCall. The familiar 12.0 resolver is bracketed by report checkpoints and
remains unchanged. Individual operations inside that resolver are not separately
instrumented. A background task keeps the delayed capture eligible to run while
Lara is away; iOS can still expire or terminate it, leaving an ARMED or BEFORE
checkpoint rather than a completed capture. The capture stops after reported
transport errors and does not retry automatically.

Lara normally destroys RemoteCall when becoming inactive/backgrounded. A
main-thread capture lease postpones that cleanup only for the duration of one
capture. Once its result is recorded, normal cleanup runs if Lara is still in
the background. Reinitialize RemoteCall before the next capture; you do not need
to reapply the Island movement or any 12.1 changes. If Lara has already returned
to the foreground, cleanup resumes on the next normal background transition.

Before its usual startup log reset, Logger copies the previous `lara.log` to
`lara-before-island-diag.log` once, if the source exists and the destination does
not. This cannot recover a log already overwritten by a prior app relaunch,
and it cannot guarantee the preserved log contains the 12.1 crash.

## Limits and verification

The snapshots reveal the observed window/root-layer state and native method
metadata. They do not establish every internal aperture view's orientation or
prove which expansion animation is drawn. Visual observations supplement them.
This is a diagnostic build, not an expansion fix. RemoteCall and UIKit inspection
can still fail on-device; no crash-free guarantee is made.

Host verification checks baseline/source preservation, absence of the failed 12.1 override,
bounded traversal and operations, journaling before observations, UI/version
consistency, workflow and script retention, and archive integrity. No iOS SDK,
Xcode compilation, or iPhone execution is available in the build environment.
