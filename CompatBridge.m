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
 * Strategy: Per-method TLS flags for precise recursion detection.
 * Each guard sets its own _in_xxx flag before calling original UIKit.
 * If the SAME guard is entered while its flag is still set, that's
 * true infinite recursion → call original UIKit directly to break the cycle.
 * A depth counter (threshold 10) serves as a safety net for edge cases.
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
#define DEPTH_LIMIT 10

// ── Per-method TLS flags ───────────────────────────────────────

static _Thread_local BOOL _in_setFrame = NO;
static _Thread_local BOOL _in_layoutSubviews = NO;
static _Thread_local BOOL _in_setBackgroundColor = NO;
static _Thread_local BOOL _in_addSubview = NO;
static _Thread_local BOOL _in_didAddSubview = NO;
static _Thread_local BOOL _in_didMoveToSuperview = NO;
static _Thread_local BOOL _in_didMoveToWindow = NO;
static _Thread_local BOOL _in_setHidden = NO;

static _Thread_local BOOL _in_viewWillAppear = NO;
static _Thread_local BOOL _in_viewDidAppear = NO;
static _Thread_local BOOL _in_viewDidLoad = NO;
static _Thread_local BOOL _in_viewDidLayoutSubviews = NO;
static _Thread_local BOOL _in_viewWillLayoutSubviews = NO;

static _Thread_local BOOL _in_setContentOffset = NO;
static _Thread_local BOOL _in_setContentInset = NO;

static _Thread_local BOOL _in_navbar_setBgImage = NO;
static _Thread_local BOOL _in_tabbar_setBgImage = NO;

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

#define GUARD_BEGIN(flag, orig_call)  \
    _depth++;                          \
    if (flag || _depth > DEPTH_LIMIT) {\
        orig_call;                     \
        _depth--;                      \
        return;                        \
    }                                  \
    flag = YES;

#define GUARD_END(flag) \
    flag = NO;           \
    _depth--;

// ── UIView guards ──────────────────────────────────────────────

static void _guard_view_setFrame(id self, SEL _cmd, CGRect frame) {
    GUARD_BEGIN(_in_setFrame, _orig_view_setFrame(self, _cmd, frame));
    _orig_view_setFrame(self, _cmd, frame);
    GUARD_END(_in_setFrame);
}

static void _guard_view_layoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_in_layoutSubviews, _orig_view_layoutSubviews(self, _cmd));
    _orig_view_layoutSubviews(self, _cmd);
    GUARD_END(_in_layoutSubviews);
}

static void _guard_view_setBackgroundColor(id self, SEL _cmd, id color) {
    GUARD_BEGIN(_in_setBackgroundColor, _orig_view_setBackgroundColor(self, _cmd, color));
    _orig_view_setBackgroundColor(self, _cmd, color);
    GUARD_END(_in_setBackgroundColor);
}

static void _guard_view_addSubview(id self, SEL _cmd, id view) {
    GUARD_BEGIN(_in_addSubview, _orig_view_addSubview(self, _cmd, view));
    _orig_view_addSubview(self, _cmd, view);
    GUARD_END(_in_addSubview);
}

static void _guard_view_didAddSubview(id self, SEL _cmd, id view) {
    GUARD_BEGIN(_in_didAddSubview, _orig_view_didAddSubview(self, _cmd, view));
    _orig_view_didAddSubview(self, _cmd, view);
    GUARD_END(_in_didAddSubview);
}

static void _guard_view_didMoveToSuperview(id self, SEL _cmd) {
    GUARD_BEGIN(_in_didMoveToSuperview, _orig_view_didMoveToSuperview(self, _cmd));
    _orig_view_didMoveToSuperview(self, _cmd);
    GUARD_END(_in_didMoveToSuperview);
}

static void _guard_view_didMoveToWindow(id self, SEL _cmd) {
    GUARD_BEGIN(_in_didMoveToWindow, _orig_view_didMoveToWindow(self, _cmd));
    _orig_view_didMoveToWindow(self, _cmd);
    GUARD_END(_in_didMoveToWindow);
}

static void _guard_view_setHidden(id self, SEL _cmd, BOOL hidden) {
    GUARD_BEGIN(_in_setHidden, _orig_view_setHidden(self, _cmd, hidden));
    _orig_view_setHidden(self, _cmd, hidden);
    GUARD_END(_in_setHidden);
}

// ── UIViewController guards ────────────────────────────────────

static void _guard_vc_viewWillAppear(id self, SEL _cmd, BOOL animated) {
    GUARD_BEGIN(_in_viewWillAppear, _orig_vc_viewWillAppear(self, _cmd, animated));
    _orig_vc_viewWillAppear(self, _cmd, animated);
    GUARD_END(_in_viewWillAppear);
}

static void _guard_vc_viewDidAppear(id self, SEL _cmd, BOOL animated) {
    GUARD_BEGIN(_in_viewDidAppear, _orig_vc_viewDidAppear(self, _cmd, animated));
    _orig_vc_viewDidAppear(self, _cmd, animated);
    GUARD_END(_in_viewDidAppear);
}

static void _guard_vc_viewDidLoad(id self, SEL _cmd) {
    GUARD_BEGIN(_in_viewDidLoad, _orig_vc_viewDidLoad(self, _cmd));
    _orig_vc_viewDidLoad(self, _cmd);
    GUARD_END(_in_viewDidLoad);
}

static void _guard_vc_viewDidLayoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_in_viewDidLayoutSubviews, _orig_vc_viewDidLayoutSubviews(self, _cmd));
    _orig_vc_viewDidLayoutSubviews(self, _cmd);
    GUARD_END(_in_viewDidLayoutSubviews);
}

static void _guard_vc_viewWillLayoutSubviews(id self, SEL _cmd) {
    GUARD_BEGIN(_in_viewWillLayoutSubviews, _orig_vc_viewWillLayoutSubviews(self, _cmd));
    _orig_vc_viewWillLayoutSubviews(self, _cmd);
    GUARD_END(_in_viewWillLayoutSubviews);
}

// ── UIScrollView guards ────────────────────────────────────────

static void _guard_scroll_setContentOffset(id self, SEL _cmd, CGPoint offset) {
    GUARD_BEGIN(_in_setContentOffset, _orig_scroll_setContentOffset(self, _cmd, offset));
    _orig_scroll_setContentOffset(self, _cmd, offset);
    GUARD_END(_in_setContentOffset);
}

static void _guard_scroll_setContentInset(id self, SEL _cmd, UIEdgeInsets insets) {
    GUARD_BEGIN(_in_setContentInset, _orig_scroll_setContentInset(self, _cmd, insets));
    _orig_scroll_setContentInset(self, _cmd, insets);
    GUARD_END(_in_setContentInset);
}

// ── UINavigationBar guard (setFrame:/layoutSubviews inherited from UIView) ──

static void _guard_navbar_setBackgroundImage(id self, SEL _cmd, id image, NSInteger metrics) {
    GUARD_BEGIN(_in_navbar_setBgImage, _orig_navbar_setBackgroundImage(self, _cmd, image, metrics));
    _orig_navbar_setBackgroundImage(self, _cmd, image, metrics);
    GUARD_END(_in_navbar_setBgImage);
}

// ── UITabBar guard (setFrame:/layoutSubviews inherited from UIView) ──

static void _guard_tabbar_setBackgroundImage(id self, SEL _cmd, id image) {
    GUARD_BEGIN(_in_tabbar_setBgImage, _orig_tabbar_setBackgroundImage(self, _cmd, image));
    _orig_tabbar_setBackgroundImage(self, _cmd, image);
    GUARD_END(_in_tabbar_setBgImage);
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
