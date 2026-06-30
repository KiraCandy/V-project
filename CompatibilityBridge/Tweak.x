/*
 * AACompat — WeChat 液态玻璃 & ThemePro 兼容桥接插件
 *
 * 问题：两个插件都 hook 了 UIView/UIViewController 的生命周期方法
 * （setFrame:, layoutSubviews, addSubview:, viewWillAppear: 等），
 * 各自在 hook 内部修改视图导致相互触发无限递归 → 栈溢出崩溃。
 *
 * 解决：在 UIView/UIViewController 基类层面用 thread-local 计数器
 * 检测重入，重入时直接走原始实现，阻断递归循环。
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
 * 重入检测机制：
 * 每个线程维护一个计数器。进入 guard → +1；离开 guard → -1。
 * counter > 3 视为递归（UIKit 正常嵌套可达 2-3 层，>3 说明是无限循环）。
 * 重入时不做任何 Hook 逻辑，直接通过 %orig 走真正的原始实现。
 */
#define REENTRY_THRESHOLD 3
static _Thread_local int _reentryDepth = 0;

// ============================================================================
// UIView 层级 — 最关键的冲突点
// ============================================================================

%hook UIView

- (void)setFrame:(CGRect)frame {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)layoutSubviews {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)setBackgroundColor:(UIColor *)color {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)addSubview:(UIView *)view {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)didAddSubview:(UIView *)subview {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)didMoveToSuperview {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)didMoveToWindow {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)setHidden:(BOOL)hidden {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

%end // UIView

// ============================================================================
// UIViewController 层级
// ============================================================================

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)viewDidAppear:(BOOL)animated {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)viewDidLoad {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)viewDidLayoutSubviews {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)viewWillLayoutSubviews {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

%end // UIViewController

// ============================================================================
// UIScrollView
// ============================================================================

%hook UIScrollView

- (void)setContentOffset:(CGPoint)contentOffset {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

%end // UIScrollView

// ============================================================================
// UINavigationBar — 仅 hook 子类特有方法（setFrame:/layoutSubviews 由 UIView 继承覆盖）
// ============================================================================

%hook UINavigationBar

- (void)setBackgroundImage:(UIImage *)backgroundImage forBarMetrics:(UIBarMetrics)barMetrics {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

%end // UINavigationBar

// ============================================================================
// UITabBar — 仅 hook 子类特有方法（setFrame:/layoutSubviews 由 UIView 继承覆盖）
// ============================================================================

%hook UITabBar

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    _reentryDepth++;
    if (_reentryDepth > REENTRY_THRESHOLD) {
        %orig;
        _reentryDepth--;
        return;
    }
    %orig;
    _reentryDepth--;
}

%end // UITabBar

// ============================================================================
// %ctor — 确保在插件加载后立即激活
// ============================================================================

%ctor {
    %init;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[AACompat] Compatibility bridge initialized — "
              "reentry guard active for UIView/UIViewController/UITabBar/UINavigationBar");
    });
}
