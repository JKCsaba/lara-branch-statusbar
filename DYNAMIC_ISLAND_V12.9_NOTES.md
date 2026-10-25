# Lara Island 12.9 Debug — inspect the actual orientation methods

Full source project based directly on the working v12.0 source, with its
original movement and other controls preserved. This version adds metadata
diagnostics; it does not add a rotation lock. The failed v12.8 lock is absent.

## Build and use

1. Build the project with the included GitHub Actions workflow, as for the
   earlier versions. It produces lara.ipa. Alternatively use the existing
   scripts/build_ipa.sh on a Mac with the required Xcode/build dependencies.
2. Sideload the resulting IPA with your working installer. Confirm the app
   name is **Lara Island 12.9 Debug** (bundle version 130).
3. Initialize Lara's SpringBoard RemoteCall as usual. Start music or a timer
   so the Island is loaded. There is no upright/lock/rotate sequence for this
   test; either portrait orientation is fine.
4. In **Island Diagnostics — v12.9**, tap **Inspect Island Orientation** once.
   Keep Lara open and leave its other controls alone until the status changes.
   It uses a 45-second soft inspection
   budget, but an in-flight call or cleanup can take longer.
5. Tap **Share Island Report** and send the generated text file back. If it
   reports an error, also share the usual Lara log. A partial report is useful;
   do not repeat the scan just because it reached its limit.

No new orientation patch is installed, so there is no diagnostic setting to
undo. Existing v12.0 controls remain available and keep their old behavior.
This package is source code, not a compiled IPA. It has not been built with
Xcode or run on an iPhone in this environment.

## Why this is needed

The October 22 log confirms that the v12.8 controller class lookup succeeded
but its _applyOrientation:withPreviousOrientation:animationSettings: lookup
returned NULL. The orientation lock therefore never reached installation.
Window movement to Y=780 succeeded independently.

A newer iOS 18.2 protocol dump contains:

- SBSystemApertureHostOrientationObserving:
  hostOrientationDidChangeTo:withPreviousOrientation:context:
- SBSystemApertureElementOrientationAuthority:
  activeElementInterfaceOrientationForSystemApertureElementOrientationObserver:
- SBSystemApertureElementOrientationObserving:
  elementOrientationDidChangeWithTransitionCoordinator:

Those declarations are leads, not proof that a particular class implements
them or that a replacement will work on iOS 18.4. The report checks the actual
runtime instead of treating a nearby iOS version as compatibility evidence.

## What the report contains

- Presence of six named Island classes.
- Nineteen targeted instance-method lookups, including the old handler, new
  host callback, content-orientation query and related content callbacks.
- For methods found: the requested class, declaring class when resolved within
  twelve superclass steps, argument count including self/_cmd, and the runtime
  type encoding. No implementation pointer is called.
- A focused list of directly declared methods whose names contain orient,
  rotat, transform or trait, from the main controller, view controller and
  container view. Targeted lookups search inheritance; this list does not.
- Explicit COMPLETE, PARTIAL_LIMIT or INCOMPLETE_ERROR status, call count and
  elapsed time. Method presence does not prove the method runs during rotation.

Search limits are six named classes, 800 inspection calls, 512 directly
declared methods per scanned class, a twelve-level owner lookup and a
45-second soft budget. This is not an exhaustive scan of every loaded class.
Cleanup and underlying RemoteCall memory transport operations are outside the
inspection-call counter. Any truncated/error result must be read as partial.

## Remote behavior and scope

The added diagnostic invokes Objective-C runtime metadata functions plus
malloc/free for its own temporary buffers. It interns candidate selector names
and copies runtime method lists. It writes only its own scratch buffers and
the local report file; it does not replace methods, execute inspected methods,
send private UIKit messages, traverse views, read object ivars, set transforms,
change window frames, register callbacks, or run a recurring poller.

The existing RemoteCall transport is unchanged and still uses the exploit's
remote-call machinery; metadata-only inspection is not a guarantee against a
transport failure or SpringBoard crash. On a transport error, new inspection
calls stop. Small remote allocations that cannot safely be freed then remain
until SpringBoard exits. Report lines are flushed after each entry.

The original v12.0 rc.m remains a byte-for-byte prefix. Baseline changes are
limited to the appended diagnostic code, its rc.h declaration, a separate SwiftUI
section, and app display/version metadata. RotationHook, the RemoteCall
implementation, build scripts, entitlements and workflows retain their v12.0
bytes.

## Sources

The protocol files below were read from the published firmware-header dump;
they are iOS 18.2 declarations, not an exact iPhone 12/iOS 18.4 dump:

- https://github.com/lechium/iPhone_OS_18.2_22C150/blob/master/System/Library/PrivateFrameworks/SpringBoard/SBSystemApertureHostOrientationObserving-Protocol.h
- https://github.com/lechium/iPhone_OS_18.2_22C150/blob/master/System/Library/PrivateFrameworks/SpringBoard/SBSystemApertureElementOrientationAuthority-Protocol.h
- https://github.com/lechium/iPhone_OS_18.2_22C150/blob/master/System/Library/PrivateFrameworks/SpringBoard/SBSystemApertureElementOrientationObserving-Protocol.h

Runtime metadata API behavior:

- https://developer.apple.com/documentation/objectivec/class_copymethodlist(_:_:)
- https://developer.apple.com/documentation/objectivec/class_getinstancemethod(_:_:)
- https://developer.apple.com/documentation/objectivec/method_gettypeencoding(_:)

## Local validation limits

Local checks passed for baseline preservation, change scope, the diagnostic
call allowlist, plist/version consistency and Swift/C entry points. The actual
C string-reading and name-filter helpers passed a simulated-memory harness
with AddressSanitizer and UndefinedBehaviorSanitizer, including page-boundary,
exact-capacity terminator, truncation, read-error, stop and overflow cases.
Leak collection was disabled because this host cannot inspect /proc; these
helpers do not allocate. The packaged ZIP is checked against every source file.

An Xcode build, report export on the phone and runtime results still require
device-side validation. There is no new rotation fix in this version and no
claim that any candidate hook has been verified.
