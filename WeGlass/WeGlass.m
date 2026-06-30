/**
 * WeGlass v2 — Native frosted glass effect for WeChat
 *
 * Strategy: Hook UIView layoutSubviews (with per-instance TLS guard for
 * ThemePro coexistence). When a target WeChat view lays out, insert a
 * UIVisualEffectView as the background layer if not already done.
 * Hook willMoveToSuperview: as secondary trigger (not hooked by ThemePro).
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

// ── Class name matching ────────────────────────────────────────

static BOOL _isTargetView(UIView *view) {
    NSString *name = NSStringFromClass([view class]);
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
    NSLog(@"[WeGlass] Discovered class: %@", name);
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

    objc_setAssociatedObject(view, kGlassViewKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// ── Hook: layoutSubviews (ThemePro also hooks this) ────────────

static void _hook_layoutSubviews(id self, SEL _cmd) {
    _layoutSubviews_depth++;
    if (_layoutSubviews_target == self || _layoutSubviews_depth > RECURSION_DEPTH_LIMIT) {
        // True recursion or too deep — bail out to original
        if (_orig_layoutSubviews) _orig_layoutSubviews(self, _cmd);
        _layoutSubviews_depth--;
        return;
    }
    id _prev = _layoutSubviews_target;
    _layoutSubviews_target = self;

    // Call original (chain through ThemePro's hook)
    if (_orig_layoutSubviews) _orig_layoutSubviews(self, _cmd);

    // Apply glass if this is a target view and frame is valid
    UIView *view = (UIView *)self;
    if (view.bounds.size.width > 0 && view.bounds.size.height > 0
        && _isTargetView(view)) {
        _applyGlass(view);
    }

    _layoutSubviews_target = _prev;
    _layoutSubviews_depth--;
}

// ── Hook: willMoveToSuperview: (ThemePro does NOT hook this) ───

static void _hook_willMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig_willMoveToSuperview) _orig_willMoveToSuperview(self, _cmd, newSuperview);

    if (!newSuperview) return;

    UIView *view = (UIView *)self;
    _logClassOnce(view);

    if (_isTargetView(view)) {
        _applyGlass(view);
    }
}

// ── Constructor ────────────────────────────────────────────────

__attribute__((constructor))
static void WeGlass_init(void) {
    _targetPatterns = [NSSet setWithObjects:
        // Navigation bars
        @"NavigationBar",
        @"NavBar",
        @"UINavigationBar",
        @"MMUINavigationBar",
        // Tab bars
        @"TabBar",
        @"TabView",
        @"MainFrame",
        @"MMTabBarView",
        @"MMTabView",
        // Table views (chat list, contacts, discover, settings)
        @"TableView",
        @"MMTableView",
        @"WCTableView",
        // Search bars
        @"SearchBar",
        @"UISearchBar",
        @"MMSearchBar",
        // Cells (chat bubbles, list cells)
        @"TableViewCell",
        @"MMTableViewCell",
        @"BaseMsgContentCell",
        @"MessageCell",
        @"WCCell",
        // Common WeChat prefixes
        @"MMUI",
        @"MMWeb",
        @"WCUI",
        @"WXUI",
        nil];

    // Swizzle layoutSubviews (with recursion guard)
    Method m1 = class_getInstanceMethod([UIView class],
                                        @selector(layoutSubviews));
    if (m1) {
        _orig_layoutSubviews = (void *)method_setImplementation(
            m1, (IMP)_hook_layoutSubviews);
    }

    // Swizzle willMoveToSuperview: (no conflict with ThemePro)
    Method m2 = class_getInstanceMethod([UIView class],
                                        @selector(willMoveToSuperview:));
    if (m2) {
        _orig_willMoveToSuperview = (void *)method_setImplementation(
            m2, (IMP)_hook_willMoveToSuperview);
    }

    NSLog(@"[WeGlass] Initialized — layoutSubviews + willMoveToSuperview: hooks active");
}