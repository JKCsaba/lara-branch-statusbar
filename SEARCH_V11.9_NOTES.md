# v11.9 — Direct Home Search control, no recursive scan

Build the full repository with the existing GitHub Actions workflow. The
installed icon is **Lara Search 11.9**; version 0.2.119, build 119. Initialize
RemoteCall, then use **Lift Home Search Pill** (default 60 pt). Restore is also
available. The bundle identifier remains the supplied baseline identifier.

## Evidence from the 11.8 failure

The supplied log records the unexpected trap inside rc_search118_find +336,
with two recursive callers at +612 and rc_search118_control +812. Inspection
of the uploaded 11.8 Mach-O executable identifies the instruction before +336
as the remote_msg call for selector `subviews`. The +812 control call is the
first descendant verification on the directly obtained pageControl, before
any fallback hierarchy search. Thus the root folder pageControl getter and its
SBIconListPageControl class validation succeeded on the user's phone. The
failure happens in descendant enumeration before transform capture or movement.

This establishes the failing call site, not the underlying SpringBoard
exception or why that receiver trapped. The repeated waits after the trap are
RemoteCall cleanup requests, not a successful Search movement.

## Change

Remove rc_search118_find and every Home/Dock hierarchy fallback from Search.
Only use the root folder controller's `pageControl` accessor, guarded with
respondsToSelector and runtime SBIconListPageControl class validation. No
subviews, count, objectAtIndex, recursiveDescription or ancestor-walking calls
are made by the new Search resolver. It either returns the named control or
stops without queuing a move.

Move that container with UIView.setTransform on SpringBoard's main thread,
using the same retained asynchronous NSInvocation scheduling pattern as the
working 11.3 gradient setters. Preserve its original transform as an associated
NSValue; repeated applications calculate from the original, and Restore puts
it back. This is intended to carry the contents, background and UIKit touch
geometry together. The dots sharing the same page control move too. SpringBoard
can replace/reset views during layout; this remains a manual application.

Search-only wrappers stop subsequent requests after RemoteCall records an
error; they do not alter the shared RemoteCall transport or its cleanup.
Stage messages distinguish direct resolution, original-transform capture and
setter queuing. No diagnostic button is installed.

## Baseline preservation and validation

The full original 11.3 rc.m remains byte-for-byte intact as the prefix; only the
new Search block is appended. All original files are identical except rc.m,
rc.h, RemoteView.swift, Info.plist (visible app name) and project.pbxproj (version
and build numbers). Home/Lock gradients, status/navigation behavior, Dock lift,
upside-down rotation, Gestalt, RotationHook and build workflows are unchanged.
No 11.7 diagnostic is included. Patch and per-file SHA-256 comparisons are
included, and the final ZIP is checked against every source file.

There is no Xcode/iPhoneOS compiler or target phone in this environment.
The removal of the observed crashing Search scan is verified in source;
compilation and the remaining transform-setter path still need Actions/device
validation. This is not a claim that the physical-device fix has passed.
