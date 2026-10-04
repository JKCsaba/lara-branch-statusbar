# v11.8 — Move the Home Search/page control

Full source repository, based only on the uploaded working full 11.3 commit
7dc38f17ed80a9f97767c62e7e78baf351eda67b.

Build using the unchanged GitHub Actions workflow and sideload the resulting
IPA. Initialize RemoteCall as usual, then tap **Lift Home Search Pill** once.
Default lift is 60 pt. A 0–140 pt stepper and **Restore Home Search Pill** are
included. No diagnostic button or diagnostic run is required.

## Change

Resolve the Home root folder controller through 11.3's existing access path,
and use its pageControl getter only when it responds to that selector. Validate
that the result is an SBIconListPageControl and contains an SBHSearchPillView.
If the getter is unavailable, locate the named SBRootFolderView on the existing
stock Dock ancestor chain and perform a bounded view search within it.

The target is the named Search/page container, not SBHSearchPillView's layer.
Set the container's UIKit UIView transform on SpringBoard's main thread using
the same retained, asynchronous NSInvocation scheduling pattern as 11.3's
working gradient setters. This is intended to carry the Search contents,
background and UIKit touch geometry together. Preserve the original transform
as an associated NSValue; repeated presses calculate from that original, and
Restore puts it back. No guessed parent index or coordinate-based identification.
If the runtime classes or required containment cannot be validated, return -2
without scheduling a move.

This is a manual application to the current view, not a permanent layout hook.
If SpringBoard replaces the view or resets its transform, reapply the button.
The page dots that share the Search container move with it.

The 11.7 diagnostic implementation is entirely absent: no diagnostic
NSInvocationOperation/polling getter, no recursiveDescription, no broad
Home hierarchy dump or gesture description calls. The exact cause of the
reported 11.7 respring has not been established; this revision removes that
entire code path rather than claiming a particular call was the cause.

## Preserved

Every original byte of rc.m is unchanged; the Search addition is appended.
Only rc.h declarations, the new Search controls/state in RemoteView.swift and
that appended block differ from original source files. Home and Lock gradients,
status/navigation flip, stock Dock lift, upside-down rotation, Gestalt,
RotationHook, project settings and workflows are unchanged. No 11.6/11.7 code
is used as the base. UI and log labels identify v11.8; marketing version stays
as it was in the supplied baseline.

## Validation and limits

Exact source comparisons and whitespace checks pass. Patch and per-file
SHA-256 comparisons are included. The complete output ZIP is verified against
all source files. There is no Xcode/iPhoneOS compiler or target iPhone here:
this is not a device-tested fix, and it does not prove the owning container's
background/hit-testing behavior on iOS 18.4. GitHub Actions is still required
for actual compilation, followed by device testing.

## Sources used

A published implementation declares the pageControl accessor on
SBFolderController and the named SBIconListPageControl view:
https://github.com/Lizynz/FolderX/blob/main/launcher.xm
The runtime containment checks, rather than this cross-version source alone,
gate the move on the phone.

UIKit UIView.transform:
https://developer.apple.com/documentation/uikit/uiview/transform

Foundation KVC struct boxing into NSValue:
https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/DataTypes.html
