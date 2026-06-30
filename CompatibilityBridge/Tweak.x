/*
 * AACompat — WeChat LiquidGlass & ThemePro compatibility bridge
 *
 * Problem: Both plugins hook UIView/UIViewController lifecycle methods
 * (setFrame:, layoutSubviews, addSubview:, viewWillAppear:, etc.),
 * each modifying views inside their hooks, triggering mutual infinite
 * recursion → stack overflow crash.
 *
 * Solution: Per-instance TLS tracking. Each guard tracks which `self`
 * is currently being processed. If the same (self, method) pair re-enters,
 * that's true infinite recursion → bail out to original UIKit via %orig.
 * Different views calling the same method simultaneously do NOT false-trigger.
 * A depth counter (threshold 15) serves as a safety net.
 *
 * Build: theos, placed in /var/jb/usr/lib/TweakInject/
 * Filename must sort before libPineappleDylib and WeChatLiquidGlass.
 *
 * NOTE: %orig must appear on its own line, not inside #define macros,
 * because Logos preprocessor runs before C preprocessor.
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define DEPTH_LIMIT 15
static _Thread_local int _depth = 0;

// Per-instance TLS tracking (id instead of BOOL)
// nil = not inside this guard; non-nil = inside for the specified instance
static _Thread_local __unsafe_unretained id _setFrame_target = nil;
static _Thread_local __unsafe_unretained id _layoutSubviews_target = nil;
static _Thread_local __unsafe_unretained id _setBackgroundColor_target = nil;
static _Thread_local __unsafe_unretained id _addSubview_target = nil;
static _Thread_local __unsafe_unretained id _didAddSubview_target = nil;
static _Thread_local __unsafe_unretained id _didMoveToSuperview_target = nil;
static _Thread_local __unsafe_unretained id _didMoveToWindow_target = nil;
static _Thread_local __unsafe_unretained id _setHidden_target = nil;

static _Thread_local __unsafe_unretained id _viewWillAppear_target = nil;
static _Thread_local __unsafe_unretained id _viewDidAppear_target = nil;
static _Thread_local __unsafe_unretained id _viewDidLoad_target = nil;
static _Thread_local __unsafe_unretained id _viewDidLayoutSubviews_target = nil;
static _Thread_local __unsafe_unretained id _viewWillLayoutSubviews_target = nil;

static _Thread_local __unsafe_unretained id _setContentOffset_target = nil;
static _Thread_local __unsafe_unretained id _setContentInset_target = nil;

static _Thread_local __unsafe_unretained id _navbar_setBgImage_target = nil;
static _Thread_local __unsafe_unretained id _tabbar_setBgImage_target = nil;

// ============================================================================
// UIView
// ============================================================================

%hook UIView

- (void)setFrame:(CGRect)frame {
    _depth++;
    if (_setFrame_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _setFrame_target;
    _setFrame_target = self;
    %orig;
    _setFrame_target = _prev;
    _depth--;
}

- (void)layoutSubviews {
    _depth++;
    if (_layoutSubviews_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _layoutSubviews_target;
    _layoutSubviews_target = self;
    %orig;
    _layoutSubviews_target = _prev;
    _depth--;
}

- (void)setBackgroundColor:(UIColor *)color {
    _depth++;
    if (_setBackgroundColor_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _setBackgroundColor_target;
    _setBackgroundColor_target = self;
    %orig;
    _setBackgroundColor_target = _prev;
    _depth--;
}

- (void)addSubview:(UIView *)view {
    _depth++;
    if (_addSubview_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _addSubview_target;
    _addSubview_target = self;
    %orig;
    _addSubview_target = _prev;
    _depth--;
}

- (void)didAddSubview:(UIView *)subview {
    _depth++;
    if (_didAddSubview_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _didAddSubview_target;
    _didAddSubview_target = self;
    %orig;
    _didAddSubview_target = _prev;
    _depth--;
}

- (void)didMoveToSuperview {
    _depth++;
    if (_didMoveToSuperview_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _didMoveToSuperview_target;
    _didMoveToSuperview_target = self;
    %orig;
    _didMoveToSuperview_target = _prev;
    _depth--;
}

- (void)didMoveToWindow {
    _depth++;
    if (_didMoveToWindow_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _didMoveToWindow_target;
    _didMoveToWindow_target = self;
    %orig;
    _didMoveToWindow_target = _prev;
    _depth--;
}

- (void)setHidden:(BOOL)hidden {
    _depth++;
    if (_setHidden_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _setHidden_target;
    _setHidden_target = self;
    %orig;
    _setHidden_target = _prev;
    _depth--;
}

%end // UIView

// ============================================================================
// UIViewController
// ============================================================================

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    _depth++;
    if (_viewWillAppear_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _viewWillAppear_target;
    _viewWillAppear_target = self;
    %orig;
    _viewWillAppear_target = _prev;
    _depth--;
}

- (void)viewDidAppear:(BOOL)animated {
    _depth++;
    if (_viewDidAppear_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _viewDidAppear_target;
    _viewDidAppear_target = self;
    %orig;
    _viewDidAppear_target = _prev;
    _depth--;
}

- (void)viewDidLoad {
    _depth++;
    if (_viewDidLoad_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _viewDidLoad_target;
    _viewDidLoad_target = self;
    %orig;
    _viewDidLoad_target = _prev;
    _depth--;
}

- (void)viewDidLayoutSubviews {
    _depth++;
    if (_viewDidLayoutSubviews_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _viewDidLayoutSubviews_target;
    _viewDidLayoutSubviews_target = self;
    %orig;
    _viewDidLayoutSubviews_target = _prev;
    _depth--;
}

- (void)viewWillLayoutSubviews {
    _depth++;
    if (_viewWillLayoutSubviews_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _viewWillLayoutSubviews_target;
    _viewWillLayoutSubviews_target = self;
    %orig;
    _viewWillLayoutSubviews_target = _prev;
    _depth--;
}

%end // UIViewController

// ============================================================================
// UIScrollView
// ============================================================================

%hook UIScrollView

- (void)setContentOffset:(CGPoint)contentOffset {
    _depth++;
    if (_setContentOffset_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _setContentOffset_target;
    _setContentOffset_target = self;
    %orig;
    _setContentOffset_target = _prev;
    _depth--;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _depth++;
    if (_setContentInset_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _setContentInset_target;
    _setContentInset_target = self;
    %orig;
    _setContentInset_target = _prev;
    _depth--;
}

%end // UIScrollView

// ============================================================================
// UINavigationBar — setFrame:/layoutSubviews inherited from UIView
// ============================================================================

%hook UINavigationBar

- (void)setBackgroundImage:(UIImage *)backgroundImage forBarMetrics:(NSInteger)barMetrics {
    _depth++;
    if (_navbar_setBgImage_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _navbar_setBgImage_target;
    _navbar_setBgImage_target = self;
    %orig;
    _navbar_setBgImage_target = _prev;
    _depth--;
}

%end // UINavigationBar

// ============================================================================
// UITabBar — setFrame:/layoutSubviews inherited from UIView
// ============================================================================

%hook UITabBar

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    _depth++;
    if (_tabbar_setBgImage_target == self || _depth > DEPTH_LIMIT) {
        %orig;
        _depth--;
        return;
    }
    id _prev = _tabbar_setBgImage_target;
    _tabbar_setBgImage_target = self;
    %orig;
    _tabbar_setBgImage_target = _prev;
    _depth--;
}

%end // UITabBar

// ============================================================================
// %ctor
// ============================================================================

%ctor {
    %init;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[AACompat] Compatibility bridge initialized — "
              "per-instance reentry guard active for UIView/UIViewController");
    });
}
