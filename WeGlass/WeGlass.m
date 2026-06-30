/**
 * WeGlass v3 — Native frosted glass effect for WeChat
 *
 * Strategy: Hook UIView layoutSubviews (with per-instance TLS guard).
 * Apply glass ONLY to views that match specific class patterns AND pass
 * size/position heuristics — never glassify full-screen container views.
 * Hook willMoveToSuperview: for class name discovery via NSLog.
 *
 * Compat: ThemePro (libPineappleDylib) — per-instance recursion guard
 * Device:  iPhone 7 (A10), iOS 14.0+
 * Build:   clang -dynamiclib for TrollStore IPA injection
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Configuration ──────────────────────────────────────────────

#define BLUR_STYLE UIBlurEffectStyleLight
#define BLUR_ALPHA 0.85
#define RECURSION_DEPTH_LIMIT 15
#define MAX_SCREEN_COVERAGE 0.70  // skip views covering >70% of screen

// WeChat internal class name patterns to glassify.
static NSSet *_targetPatterns = nil;

// ── Associated object keys ─────────────────────────────────────

static const void *kGlassAppliedKey = &kGlassAppliedKey;
static const void *kGlassViewKey    = &kGlassViewKey;
static const void *kClassLoggedKey  = &kClassLoggedKey;

// ── Original IMPs ──────────────────────────────────────────────

static void (*_orig_layoutSubviews)(id, SEL);
static void (*_orig_willMoveToSuperview)(id, SEL, UIView *);

// ── Per-instance TLS recursion guards ──────────────────────────

static _Thread_local __unsafe_unretained id _layoutSubviews_target = nil;
static _Thread_local int _layoutSubviews_depth = 0;

// ── Screen size (cached) ───────────────────────────────────────

static CGFloat _screenArea = 0;

// ── View eligibility check ─────────────────────────────────────

static BOOL _shouldGlassify(UIView *view) {
    // Must have valid size
    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;
    if (w <= 0 || h <= 0) return NO;

    // Skip full-screen containers: view covers >70% of screen area
    if (_screenArea > 0 && (w * h) > _screenArea * MAX_SCREEN_COVERAGE) return NO;

    // Skip system classes
    NSString *name = NSStringFromClass([view class]);
    if ([name hasPrefix:@"UI"] && ![name containsString:@"Bar"]) return NO;
    if ([name hasPrefix:@"_UI"]) return NO;

    // Match against target patterns
    for (NSString *pattern in _targetPatterns) {
        if ([name containsString:pattern]) return YES;
    }
    return NO;
}

// ── Debug: log each class once ─────────────────────────────────

static void _logClassOnce(UIView *view) {
    if (objc_getAssociatedObject(view, kClassLoggedKey)) return;
    objc_setAssociatedObject(view, kClassLoggedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSString *name = NSStringFromClass([view class]);
    NSLog(@"[WeGlass] [%@] frame=%@ bounds=%@ area=%.0f screenPct=%.1f%%",
          name,
          NSStringFromCGRect(view.frame),
          NSStringFromCGRect(view.bounds),
          view.bounds.size.width * view.bounds.size.height,
          _screenArea > 0 ? (view.bounds.size.width * view.bounds.size.height / _screenArea * 100) : 0);
}

// ── Glass effect application ───────────────────────────────────

static void _applyGlass(UIView *view) {
    if (objc_getAssociatedObject(view, kGlassAppliedKey)) return;
    objc_setAssociatedObject(view, kGlassAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    view.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C;

    [view insertSubview:blurView atIndex:0];

    objc_setAssociatedObject(view, kGlassViewKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLog(@"[WeGlass] Glass applied: %@ (%.0fx%.0f)",
          NSStringFromClass([view class]),
          view.bounds.size.width, view.bounds.size.height);
}

// ── Hook: layoutSubviews ───────────────────────────────────────

static void _hook_layoutSubviews(id self, SEL _cmd) {
    _layoutSubviews_depth++;
    if (_layoutSubviews_target == self || _layoutSubviews_depth > RECURSION_DEPTH_LIMIT) {
        if (_orig_layoutSubviews) _orig_layoutSubviews(self, _cmd);
        _layoutSubviews_depth--;
        return;
    }
    id _prev = _layoutSubviews_target;
    _layoutSubviews_target = self;

    if (_orig_layoutSubviews) _orig_layoutSubviews(self, _cmd);

    UIView *view = (UIView *)self;
    if (_shouldGlassify(view)) {
        _applyGlass(view);
    }

    _layoutSubviews_target = _prev;
    _layoutSubviews_depth--;
}

// ── Hook: willMoveToSuperview: (discovery only, no glass here) ─

static void _hook_willMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig_willMoveToSuperview) _orig_willMoveToSuperview(self, _cmd, newSuperview);
    if (!newSuperview) return;
    _logClassOnce((UIView *)self);
}

// ── Constructor ────────────────────────────────────────────────

__attribute__((constructor))
static void WeGlass_init(void) {
    CGSize screen = [UIScreen mainScreen].bounds.size;
    _screenArea = screen.width * screen.height;

    _targetPatterns = [NSSet setWithObjects:
        // Navigation bars — small height, full width
        @"NavigationBar",
        @"NavBar",
        @"MMUINavigationBar",
        // Tab bars — small height, full width
        @"TabBar",
        @"TabView",
        @"MMTabBarView",
        @"MMTabView",
        // Search bars
        @"SearchBar",
        @"MMSearchBar",
        // Table/collection views — large but not full screen
        @"TableView",
        @"MMTableView",
        @"WCTableView",
        @"CollectionView",
        // Cells — small individual items
        @"TableViewCell",
        @"MMTableViewCell",
        @"BaseMsgContentCell",
        @"MessageCell",
        @"WCCell",
        // Chat content area — typically middle portion
        @"MsgContent",
        @"ChatContent",
        nil];

    Method m1 = class_getInstanceMethod([UIView class],
                                        @selector(layoutSubviews));
    if (m1) {
        _orig_layoutSubviews = (void *)method_setImplementation(
            m1, (IMP)_hook_layoutSubviews);
    }

    Method m2 = class_getInstanceMethod([UIView class],
                                        @selector(willMoveToSuperview:));
    if (m2) {
        _orig_willMoveToSuperview = (void *)method_setImplementation(
            m2, (IMP)_hook_willMoveToSuperview);
    }

    NSLog(@"[WeGlass] Initialized v3 — screen=%.0fx%.0f, safe glass filter active",
          screen.width, screen.height);
}