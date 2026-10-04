# Lara Search 11.10

This revision starts from the supplied working 11.3 full repository. All original rc.m bytes remain unchanged; Search code is appended. Existing Dock, rotation, status/navigation, gradients, Gestalt and RotationHook implementations are unchanged.

Search now uses the same numeric CALayer transform.translation.y setter and existing rc_invoke_objc_on_main_poll helper used by set_v61_dock_vertical_lift. It applies an absolute negative offset to the directly obtained SBIconListPageControl layer; Restore sets that property to zero. No recursive view discovery or new UIView transform/associated-object machinery is present.

Evidence: the supplied 11.8 IPA and crash trace resolve the root-folder pageControl and pass its SBIconListPageControl class check. The recorded failing remote call is subviews in rc_search118_find, before movement. That trace does not establish the underlying SpringBoard exception cause. The later reported 11.9 crash has not been traced here; this revision is not a proven device fix.

Build this ZIP with the existing GitHub Actions workflow. The installed app display name is Lara Search 11.10; the section is Home Search — v11.10. Tap Lift Home Search Pill with the desired offset (default 60 pt). Restore Home Search Pill sets the offset to 0.

Validation: checked original-byte preservation, five-file change scope, exact Dock property setup and helper reuse, UI/version strings, and ZIP contents. No Xcode compiler or connected iOS device is available here. iOS compilation, respring behavior, full-pill movement, touch alignment and persistence require device verification.
