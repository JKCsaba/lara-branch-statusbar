#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>
#import <string.h>

// Loaded on demand by Lara into SpringBoard. No constructor performs mutations.
// This binary must be built for the device and accepted by SpringBoard's loader.
static IMP originalTransition;
static Class hookedClass;
static BOOL installed;

static id CallObject(id target, const char *name) {
    SEL selector = sel_registerName(name);
    return target && [target respondsToSelector:selector]
        ? ((id (*)(id, SEL))objc_msgSend)(target, selector) : nil;
}

static NSInteger CommittedOrientation(void) {
    id app = [UIApplication sharedApplication];
    SEL selector = sel_registerName("activeInterfaceOrientation");
    if (![app respondsToSelector:selector]) return 0;
    return ((NSInteger (*)(id, SEL))objc_msgSend)(app, selector);
}

static void ApplyVisuals(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ ApplyVisuals(); });
        return;
    }
    NSInteger orientation = CommittedOrientation();
    if (orientation != UIInterfaceOrientationPortrait &&
        orientation != UIInterfaceOrientationPortraitUpsideDown) return;

    BOOL inverted = orientation == UIInterfaceOrientationPortraitUpsideDown;
    id app = [UIApplication sharedApplication];
    UIView *bar = CallObject(app, "statusBarForEmbeddedDisplay");
    UIView *parent = bar.superview;
    CGRect placement = parent ? parent.bounds : [UIScreen mainScreen].bounds;
    if (bar && (!inverted || (bar.bounds.size.height > 0 && placement.size.height > 1))) {
        // Same absolute KVC components as V3-restored; bounds, never frame.
        CGFloat y = inverted ? CGRectGetHeight(placement) - CGRectGetHeight(bar.bounds) : 0;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [bar.layer setValue:@(inverted ? M_PI : 0) forKeyPath:@"transform.rotation.z"];
        [bar.layer setValue:@(y) forKeyPath:@"transform.translation.y"];
        [CATransaction commit];
    }

    id icon = CallObject(NSClassFromString(@"SBIconController"), "sharedInstance");
    id manager = CallObject(icon, "iconManager");
    UIView *dockList = CallObject(manager, "dockListView");
    if (!dockList) dockList = CallObject(icon, "dockListView");
    UIView *dock = dockList.superview ?: dockList;
    if (dock) {
        // Same host and calibrated lift as V6.1; never accumulate a delta.
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [dock.layer setValue:@(inverted ? -23.0 : 0.0)
                 forKeyPath:@"transform.translation.y"];
        [CATransaction commit];
    }
}

static void Transition(id self, SEL command, CGSize size,
                       id<UIViewControllerTransitionCoordinator> coordinator) {
    ((void (*)(id, SEL, CGSize, id))originalTransition)(self, command, size, coordinator);
    if (coordinator) {
        [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
            ApplyVisuals();
        }];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ ApplyVisuals(); });
    }
}

// Return negative values on unsupported hierarchy. Never replace an inherited
// method: the target device proved a concrete root-folder override exists.
static int InstallOnMain(void) {
    if (installed) { ApplyVisuals(); return 0; }
    id icon = CallObject(NSClassFromString(@"SBIconController"), "sharedInstance");
    id root = CallObject(CallObject(icon, "iconManager"), "rootFolderController");
    if (!root) return -2;
    Class cls = object_getClass(root);
    SEL selector = @selector(viewWillTransitionToSize:withTransitionCoordinator:);
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || class_getInstanceMethod(class_getSuperclass(cls), selector) == method) return -3;
    if (method_getNumberOfArguments(method) != 4) return -4;
    NSMethodSignature *signature = [root methodSignatureForSelector:selector];
    if (!signature || signature.numberOfArguments != 4 ||
        signature.methodReturnType[0] != 'v' ||
        strncmp([signature getArgumentTypeAtIndex:2], "{CGSize=", 8) != 0 ||
        [signature getArgumentTypeAtIndex:3][0] != '@') return -4;
    IMP previous = method_setImplementation(method, (IMP)Transition);
    if (!previous || previous == (IMP)Transition) return -5;
    originalTransition = previous;
    hookedClass = cls;
    installed = YES;
    ApplyVisuals();
    return 0;
}

__attribute__((visibility("default"))) int LaraRotationHookInstall(void) {
    if ([NSThread isMainThread]) return InstallOnMain();
    __block int result = -1;
    dispatch_sync(dispatch_get_main_queue(), ^{ result = InstallOnMain(); });
    return result;
}

static int RemoveOnMain(void) {
    if (!installed) return 0;
    Method method = class_getInstanceMethod(hookedClass,
        @selector(viewWillTransitionToSize:withTransitionCoordinator:));
    if (!method || method_getImplementation(method) != (IMP)Transition) return -2;
    method_setImplementation(method, originalTransition);
    installed = NO;
    ApplyVisuals();
    return 0;
}

__attribute__((visibility("default"))) int LaraRotationHookRemove(void) {
    if ([NSThread isMainThread]) return RemoveOnMain();
    __block int result = -1;
    dispatch_sync(dispatch_get_main_queue(), ^{ result = RemoveOnMain(); });
    return result;
}
