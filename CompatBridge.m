/**
 * CompatBridge — Combined SubstrateShim + Re-entry Guard
 *
 * Two-in-one dylib for TrollStore WeChat injection:
 *   1. Exports _MSHookMessageEx (replaces CydiaSubstrate.framework)
 *   2. Installs re-entry guards on UIView/UIViewController to prevent
 *      infinite recursion between LiquidGlass and ThemePro hooks.
 *
 * Load order: CompatBridge → WeChatLiquidGlass → libPineappleDylib
 *
 * Strategy: Per-instance TLS tracking. Each guard tracks which `self`
 * is currently being processed. If the same (self, method) pair re-enters,
 * that's true infinite recursion → bail out to original UIKit.
 * Different views calling the same method simultaneously do NOT false-trigger.
 * A depth counter (threshold 15) serves as a safety net.
 */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// ─── Part 1: CydiaSubstrate API shim ───────────────────────────

void MSHookMessageEx(Class cls, SEL sel, IMP imp, IMP *result) {
    Method method = class_getInstanceMethod(cls, sel);
    if (method) {
        if (result) *result = method_setImplementation(method, imp);
    }
}

// ─── Part 2: Re-entry guard ────────────────────────────────────

static _Thread_local int _depth = 0;
#define DEPTH_LIMIT 15

// ── Per-instance TLS tracking (id instead of BOOL) ─────────────
// nil means "not currently inside this guard for any instance".
// Non-nil means "currently inside this guard for the specified instance".
// Re-entry on the SAME instance is true recursion.

static _Thread_local id _setFrame_target = nil;
static _Thread_local id _layoutSubviews_target = nil;
static _Thread_local id _setBackgroundColor_target = nil;
static _Thread_local id _addSubview_target = nil;
static _Thread_local id _didAddSubview_target = nil;
static _Thread_local id _didMoveToSuperview_target = nil;
static _Thread_local id _didMoveToWindow_target = nil;
static _Thread_local id _setHidden_target = nil;

static _Thread_local id _viewWillAppear_target = nil;
static _Thread_local id _viewDidAppear_target = nil;
static _Thread_local id _viewDidLoad_target = nil;
static _Thread_local id _viewDidLayoutSubviews_target = nil;
static _Thread_local id _viewWillLayoutSubviews_target = nil;

static _Thread_local id _setContentOffset_target = nil;
static _Thread_local id _setContentInset_target = nil;

static _Thread_local id _navbar_setBgImage_target = nil;
static _Thread_local id _tabbar_setBgImage_target = nil;

// ── Original IMP storage ───────────────────────────────────────

static void (*_orig_view_setFrame)(id, SEL, CGRect);
static void (*_orig_view_layoutSubviews)(id, SEL);
static void (*_orig_view_setBackgroundColor)(id, SEL, id);
static void (*_orig_view_addSubview)(id, SEL, id);
static void (*_orig_view_didAddSubview)(id, SEL, id);
static void (*_orig_view_didMoveToSuperview)(id, SEL);
static void (*_orig_view_didMoveToWindow)(id, SEL);
static void (*_orig_view_setHidden)(id, SEL, BOOL);

static void (*_orig_vc_viewWillAppear)(id, SEL, BOOL);
static void (*_orig_vc_viewDidAppear)(id, SEL, BOOL);
static void (*_orig_vc_viewDidLoad)(id, SEL);
static void (*_orig_vc_viewDidLayoutSubviews)(id, SEL);
static void (*_orig_vc_viewWillLayoutSubviews)(id, SEL);

static void (*_orig_scroll_setContentOffset)(id, SEL, CGPoint);
static void (*_orig_scroll_setContentInset)(id, SEL, UIEdgeInsets);

static void (*_orig_navbar_setBackgroundImage)(id, SEL, id, NSInteger);
static void (*_orig_tabbar_setBackgroundImage)(id, SEL, id);

// ── Guard macros ───────────────────────────────────────────────
// target == self  → same instance re-entered = true recursion
// _depth > limit  → cross-method chain too deep = safety bailout

#define GUARD_BEGIN(target, orig_call)      \
    _depth++;                                \
    if (target == self || _depth > DEPTH_LIMIT) { \
        orig_call;                           \
        _depth--;                            \
        return;                              \
    }                                        \
    id _prev = target;                       \
    target = self;

#define GUARD_END(target) \
    target = _prev;        \
    _depth--;

// ── UIView guards ──────────────────────────────────────────────

static void _guard_view_setFrame(id self, SEL _cmd, CGRect frame) {
    GUARD_BEGIN(_setFrame_target, _orig_view_setFrame(self, _cmd, frame));
    _orig_view_setFrame(self, _cmd, frame);
    GUARD_END(_setFrame_target);
}

static void _guard_view_layoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_layoutSubviews_target, _orig_view_layoutSubviews(self, _cmd));
    _orig_view_layoutSubviews(self, _cmd);
    GUARD_END(_layoutSubviews_target);
}

static void _guard_view_setBackgroundColor(id self, SEL _cmd, id color) {
    GUARD_BEGIN(_setBackgroundColor_target, _orig_view_setBackgroundColor(self, _cmd, color));
    _orig_view_setBackgroundColor(self, _cmd, color);
    GUARD_END(_setBackgroundColor_target);
}

static void _guard_view_addSubview(id self, SEL _cmd, id view) {
    GUARD_BEGIN(_addSubview_target, _orig_view_addSubview(self, _cmd, view));
    _orig_view_addSubview(self, _cmd, view);
    GUARD_END(_addSubview_target);
}

static void _guard_view_didAddSubview(id self, SEL _cmd, id view) {
    GUARD_BEGIN(_didAddSubview_target, _orig_view_didAddSubview(self, _cmd, view));
    _orig_view_didAddSubview(self, _cmd, view);
    GUARD_END(_didAddSubview_target);
}

static void _guard_view_didMoveToSuperview(id self, SEL _cmd) {
    GUARD_BEGIN(_didMoveToSuperview_target, _orig_view_didMoveToSuperview(self, _cmd));
    _orig_view_didMoveToSuperview(self, _cmd);
    GUARD_END(_didMoveToSuperview_target);
}

static void _guard_view_didMoveToWindow(id self, SEL _cmd) {
    GUARD_BEGIN(_didMoveToWindow_target, _orig_view_didMoveToWindow(self, _cmd));
    _orig_view_didMoveToWindow(self, _cmd);
    GUARD_END(_didMoveToWindow_target);
}

static void _guard_view_setHidden(id self, SEL _cmd, BOOL hidden) {
    GUARD_BEGIN(_setHidden_target, _orig_view_setHidden(self, _cmd, hidden));
    _orig_view_setHidden(self, _cmd, hidden);
    GUARD_END(_setHidden_target);
}

// ── UIViewController guards ────────────────────────────────────

static void _guard_vc_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    GUARD_BEGIN(_viewWillAppear_target, _orig_vc_viewWillAppear(self, _cmd, animated));
    _orig_vc_viewWillAppear(self, _cmd, animated);
    GUARD_END(_viewWillAppear_target);
}

static void _guard_vc_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    GUARD_BEGIN(_viewDidAppear_target, _orig_vc_viewDidAppear(self, _cmd, animated));
    _orig_vc_viewDidAppear(self, _cmd, animated);
    GUARD_END(_viewDidAppear_target);
}

static void _guard_vc_viewDidLoad(id self, SEL _cmd) {
    GUARD_BEGIN(_viewDidLoad_target, _orig_vc_viewDidLoad(self, _cmd));
    _orig_vc_viewDidLoad(self, _cmd);
    GUARD_END(_viewDidLoad_target);
}

static void _guard_vc_viewDidLayoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_viewDidLayoutSubviews_target, _orig_vc_viewDidLayoutSubviews(self, _cmd));
    _orig_vc_viewDidLayoutSubviews(self, _cmd);
    GUARD_END(_viewDidLayoutSubviews_target);
}

static void _guard_vc_viewWillLayoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_viewWillLayoutSubviews_target, _orig_vc_viewWillLayoutSubviews(self, _cmd));
    _orig_vc_viewWillLayoutSubviews(self, _cmd);
    GUARD_END(_viewWillLayoutSubviews_target);
}

// ── UIScrollView guards ────────────────────────────────────────

static void _guard_scroll_setContentOffset(id self, SEL _cmd, CGPoint offset) {
    GUARD_BEGIN(_setContentOffset_target, _orig_scroll_setContentOffset(self, _cmd, offset));
    _orig_scroll_setContentOffset(self, _cmd, offset);
    GUARD_END(_setContentOffset_target);
}

static void _guard_scroll_setContentInset(id self, SEL _cmd, UIEdgeInsets insets) {
    GUARD_BEGIN(_setContentInset_target, _orig_scroll_setContentInset(self, _cmd, insets));
    _orig_scroll_setContentInset(self, _cmd, insets);
    GUARD_END(_setContentInset_target);
}

// ── UINavigationBar guard (setFrame:/layoutSubviews inherited from UIView) ──

static void _guard_navbar_setBackgroundImage(id self, SEL _cmd, id image, NSInteger metrics) {
    GUARD_BEGIN(_navbar_setBgImage_target, _orig_navbar_setBackgroundImage(self, _cmd, image, metrics));
    _orig_navbar_setBackgroundImage(self, _cmd, image, metrics);
    GUARD_END(_navbar_setBgImage_target);
}

// ── UITabBar guard (setFrame:/layoutSubviews inherited from UIView) ──

static void _guard_tabbar_setBackgroundImage(id self, SEL _cmd, id image) {
    GUARD_BEGIN(_tabbar_setBgImage_target, _orig_tabbar_setBackgroundImage(self, _cmd, image));
    _orig_tabbar_setBackgroundImage(self, _cmd, image);
    GUARD_END(_tabbar_setBgImage_target);
}

// ── Installation ───────────────────────────────────────────────

#define SWIZZLE(cls, sel, orig_ptr, guard_fn)                           \
    do {                                                                \
        Method _m = class_getInstanceMethod([cls class], @selector(sel));\
        if (_m) {                                                       \
            orig_ptr = (void *)method_setImplementation(_m, (IMP)guard_fn);\
        }                                                               \
    } while (0)

__attribute__((constructor))
static void CompatBridge_init(void) {
    SWIZZLE(UIView, setFrame:, _orig_view_setFrame, _guard_view_setFrame);
    SWIZZLE(UIView, layoutSubviews, _orig_view_layoutSubviews, _guard_view_layoutSubviews);
    SWIZZLE(UIView, setBackgroundColor:, _orig_view_setBackgroundColor, _guard_view_setBackgroundColor);
    SWIZZLE(UIView, addSubview:, _orig_view_addSubview, _guard_view_addSubview);
    SWIZZLE(UIView, didAddSubview:, _orig_view_didAddSubview, _guard_view_didAddSubview);
    SWIZZLE(UIView, didMoveToSuperview, _orig_view_didMoveToSuperview, _guard_view_didMoveToSuperview);
    SWIZZLE(UIView, didMoveToWindow, _orig_view_didMoveToWindow, _guard_view_didMoveToWindow);
    SWIZZLE(UIView, setHidden:, _orig_view_setHidden, _guard_view_setHidden);

    SWIZZLE(UIViewController, viewWillAppear:, _orig_vc_viewWillAppear, _guard_vc_viewWillAppear);
    SWIZZLE(UIViewController, viewDidAppear:, _orig_vc_viewDidAppear, _guard_vc_viewDidAppear);
    SWIZZLE(UIViewController, viewDidLoad, _orig_vc_viewDidLoad, _guard_vc_viewDidLoad);
    SWIZZLE(UIViewController, viewDidLayoutSubviews, _orig_vc_viewDidLayoutSubviews, _guard_vc_viewDidLayoutSubviews);
    SWIZZLE(UIViewController, viewWillLayoutSubviews, _orig_vc_viewWillLayoutSubviews, _guard_vc_viewWillLayoutSubviews);

    SWIZZLE(UIScrollView, setContentOffset:, _orig_scroll_setContentOffset, _guard_scroll_setContentOffset);
    SWIZZLE(UIScrollView, setContentInset:, _orig_scroll_setContentInset, _guard_scroll_setContentInset);

    SWIZZLE(UINavigationBar, setBackgroundImage:forBarMetrics:, _orig_navbar_setBackgroundImage, _guard_navbar_setBackgroundImage);

    SWIZZLE(UITabBar, setBackgroundImage:, _orig_tabbar_setBackgroundImage, _guard_tabbar_setBackgroundImage);
}