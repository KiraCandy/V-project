/**
 * WeGlass — Native frosted glass effect for WeChat
 *
 * Strategy: Hook ONLY UIView willMoveToWindow: (not hooked by ThemePro).
 * When a target WeChat view enters the window, insert a UIVisualEffectView
 * as the background layer. Uses iOS native GPU-accelerated blur.
 *
 * Compat: ThemePro (libPineappleDylib) — zero hook conflicts
 * Device:  iPhone 7 (A10), iOS 14.0+
 * Build:   clang -dynamiclib for TrollStore IPA injection
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Configuration ──────────────────────────────────────────────

#define BLUR_STYLE UIBlurEffectStyleLight
#define BLUR_ALPHA 0.95

// WeChat internal class name patterns to glassify.
// Expand this list based on NSLog output after testing.
static NSSet *_targetPatterns = nil;

// ── Associated object keys ─────────────────────────────────────

static const void *kGlassAppliedKey = &kGlassAppliedKey;
static const void *kGlassViewKey    = &kGlassViewKey;

// ── Original IMP ───────────────────────────────────────────────

static void (*_orig_willMoveToWindow)(id, SEL, UIWindow *);

// ── Class name matching ────────────────────────────────────────

static BOOL _isTargetView(UIView *view) {
    NSString *name = NSStringFromClass([view class]);
    for (NSString *pattern in _targetPatterns) {
        if ([name containsString:pattern]) return YES;
    }
    return NO;
}

// ── Glass effect application ───────────────────────────────────

static void _applyGlass(UIView *view) {
    if (objc_getAssociatedObject(view, kGlassAppliedKey)) return;
    objc_setAssociatedObject(view, kGlassAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Make the view's own background transparent so blur shows through
    view.backgroundColor = [UIColor clearColor];

    // Create native blur effect view
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C; // "WeGl" in hex

    // Insert as the bottom-most subview so content stays on top
    [view insertSubview:blurView atIndex:0];

    // Store reference for potential future cleanup
    objc_setAssociatedObject(view, kGlassViewKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ── Hook function ──────────────────────────────────────────────

static void _hook_willMoveToWindow(id self, SEL _cmd, UIWindow *window) {
    // Call original implementation first
    if (_orig_willMoveToWindow) {
        _orig_willMoveToWindow(self, _cmd, window);
    }

    if (!window) return; // Moving OUT of window — skip

    UIView *view = (UIView *)self;
    if (_isTargetView(view)) {
        _applyGlass(view);
    }
}

// ── Constructor — install hook ─────────────────────────────────

__attribute__((constructor))
static void WeGlass_init(void) {
    // Known WeChat UI class name patterns.
    // MM = MicroMessage (WeChat internal prefix).
    _targetPatterns = [NSSet setWithObjects:
        @"TabBar",
        @"NavBar",
        @"NavigationBar",
        @"MMUINavigationBar",
        @"MMTabBarView",
        @"MMTabView",
        @"MainFrameTabBar",
        nil];

    Method m = class_getInstanceMethod([UIView class],
                                       @selector(willMoveToWindow:));
    if (m) {
        _orig_willMoveToWindow = (void *)method_setImplementation(
            m, (IMP)_hook_willMoveToWindow);
    }
}