/*
 * AACompat — WeChat 液态玻璃 & ThemePro 兼容桥接插件
 *
 * 问题：两个插件都 hook 了 UIView/UIViewController 的生命周期方法
 * （setFrame:, layoutSubviews, addSubview:, viewWillAppear: 等），
 * 各自在 hook 内部修改视图导致相互触发无限递归 → 栈溢出崩溃。
 *
 * 解决：per-method TLS 标志位精确检测递归。每个 guard 函数有独立的
 * _in_xxx 标志。如果同一个 guard 被重入（标志位已置位），说明发生了
 * 真递归 → 直接 %orig 走原始实现，打断循环。
 * 深度计数器（阈值 10）作为兜底保护。
 *
 * 编译：theos 或装有 theos 的环境，放到 /var/jb/usr/lib/TweakInject/
 * 文件名必须保证按字母顺序在 libPineappleDylib 和 WeChatLiquidGlass 之前加载。
 *
 * 注意：%orig 必须在方法体内直接使用，不能放在 #define 宏中，
 * 因为 Logos 预处理器先于 C 预处理器运行，会报错。
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

/*
 * 递归检测策略：
 * 1. Per-method 标志位：同一方法被重入 = 真递归 → %orig 打断
 * 2. 全局深度计数器（阈值 10）：兜底检测跨方法循环
 */
#define DEPTH_LIMIT 10
static _Thread_local int _reentryDepth = 0;

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

// ============================================================================
// UIView 层级 — 最关键的冲突点
// ============================================================================

%hook UIView

- (void)setFrame:(CGRect)frame {
    _reentryDepth++;
    if (_in_setFrame || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_setFrame = YES;
    %orig;
    _in_setFrame = NO;
    _reentryDepth--;
}

- (void)layoutSubviews {
    _reentryDepth++;
    if (_in_layoutSubviews || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_layoutSubviews = YES;
    %orig;
    _in_layoutSubviews = NO;
    _reentryDepth--;
}

- (void)setBackgroundColor:(UIColor *)color {
    _reentryDepth++;
    if (_in_setBackgroundColor || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_setBackgroundColor = YES;
    %orig;
    _in_setBackgroundColor = NO;
    _reentryDepth--;
}

- (void)addSubview:(UIView *)view {
    _reentryDepth++;
    if (_in_addSubview || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_addSubview = YES;
    %orig;
    _in_addSubview = NO;
    _reentryDepth--;
}

- (void)didAddSubview:(UIView *)subview {
    _reentryDepth++;
    if (_in_didAddSubview || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_didAddSubview = YES;
    %orig;
    _in_didAddSubview = NO;
    _reentryDepth--;
}

- (void)didMoveToSuperview {
    _reentryDepth++;
    if (_in_didMoveToSuperview || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_didMoveToSuperview = YES;
    %orig;
    _in_didMoveToSuperview = NO;
    _reentryDepth--;
}

- (void)didMoveToWindow {
    _reentryDepth++;
    if (_in_didMoveToWindow || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_didMoveToWindow = YES;
    %orig;
    _in_didMoveToWindow = NO;
    _reentryDepth--;
}

- (void)setHidden:(BOOL)hidden {
    _reentryDepth++;
    if (_in_setHidden || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_setHidden = YES;
    %orig;
    _in_setHidden = NO;
    _reentryDepth--;
}

%end // UIView

// ============================================================================
// UIViewController 层级
// ============================================================================

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    _reentryDepth++;
    if (_in_viewWillAppear || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_viewWillAppear = YES;
    %orig;
    _in_viewWillAppear = NO;
    _reentryDepth--;
}

- (void)viewDidAppear:(BOOL)animated {
    _reentryDepth++;
    if (_in_viewDidAppear || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_viewDidAppear = YES;
    %orig;
    _in_viewDidAppear = NO;
    _reentryDepth--;
}

- (void)viewDidLoad {
    _reentryDepth++;
    if (_in_viewDidLoad || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_viewDidLoad = YES;
    %orig;
    _in_viewDidLoad = NO;
    _reentryDepth--;
}

- (void)viewDidLayoutSubviews {
    _reentryDepth++;
    if (_in_viewDidLayoutSubviews || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_viewDidLayoutSubviews = YES;
    %orig;
    _in_viewDidLayoutSubviews = NO;
    _reentryDepth--;
}

- (void)viewWillLayoutSubviews {
    _reentryDepth++;
    if (_in_viewWillLayoutSubviews || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_viewWillLayoutSubviews = YES;
    %orig;
    _in_viewWillLayoutSubviews = NO;
    _reentryDepth--;
}

%end // UIViewController

// ============================================================================
// UIScrollView
// ============================================================================

%hook UIScrollView

- (void)setContentOffset:(CGPoint)contentOffset {
    _reentryDepth++;
    if (_in_setContentOffset || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_setContentOffset = YES;
    %orig;
    _in_setContentOffset = NO;
    _reentryDepth--;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _reentryDepth++;
    if (_in_setContentInset || _reentryDepth > DEPTH_LIMIT) {
        %orig;
        _reentryDepth--;
        return;
    }
    _in_setContentInset = YES;
    %orig;
    _in_setContentInset = NO;
    _reentryDepth--;
}

%end // UIScrollView

// ============================================================================
// %ctor — 确保在插件加载后立即激活
// ============================================================================

%ctor {
    %init;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[AACompat] Compatibility bridge initialized — "
              "per-method reentry guard active for UIView/UIViewController");
    });
}
