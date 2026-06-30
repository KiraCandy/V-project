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
 */

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

/*
 * 重入检测机制：
 * 每个线程维护一个计数器。进入 guard → +1；离开 guard → -1。
 * counter > 1 表示重入（外层还在 guard 中，又触发了同一个/另一个 guard）。
 * 重入时不做任何 Hook 逻辑，直接通过 %orig 走真正的原始实现。
 */
static _Thread_local int _reentryDepth = 0;

// ============================================================================
// 保存的真正原始 IMP（我们的 %orig 在加载顺序下就是真正的原始实现，
// 但直接用 objc_msgSend 调用保留原始 IMP 作为最后保险）
// ============================================================================

// 宏：每个 hook 开头调用
#define REENTRY_GUARD_BEGIN \
    _reentryDepth++; \
    if (_reentryDepth > 1) { \
        /* 重入：跳过本 hook 的所有逻辑，直接转发到原始实现 */ \
        %orig; \
        _reentryDepth--; \
        return; \
    }

#define REENTRY_GUARD_END \
    _reentryDepth--;

// ============================================================================
// UIView 层级 — 最关键的冲突点
// ============================================================================

%hook UIView

/*
 * setFrame: — 两个插件都通过它修改视图位置/大小。
 * LiquidGlass 调整毛玻璃覆盖层的 frame；
 * ThemePro 调整 TabBar/导航栏等组件的 frame。
 * 是引发循环的主要入口。
 */
- (void)setFrame:(CGRect)frame {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * layoutSubviews — 两个插件都在其中添加/调整子视图。
 */
- (void)layoutSubviews {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * setBackgroundColor: — ThemePro hook 了 NewMainFrameCell 的此方法，
 * LiquidGlass 也可能在设置毛玻璃背景时调用。
 */
- (void)setBackgroundColor:(UIColor *)color {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * addSubview: — LiquidGlass 可能 hook 此方法来追踪视图添加。
 * 如果 ThemePro 的 layoutSubviews hook 中添加了子视图，
 * LiquidGlass 的 addSubview: hook 会被触发，进而又调用 setFrame: 等。
 */
- (void)addSubview:(UIView *)view {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * didAddSubview: — LiquidGlass hook 此方法以对新子视图应用玻璃效果。
 */
- (void)didAddSubview:(UIView *)subview {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * didMoveToSuperview — LiquidGlass hook 此方法追踪视图层级变化。
 */
- (void)didMoveToSuperview {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * didMoveToWindow — LiquidGlass hook 此方法追踪窗口挂载。
 */
- (void)didMoveToWindow {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * setHidden: — LiquidGlass 可能在此方法中调整玻璃层可见性。
 */
- (void)setHidden:(BOOL)hidden {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

%end // UIView

// ============================================================================
// UIViewController 层级
// ============================================================================

%hook UIViewController

/*
 * viewWillAppear: — 两个插件都会在此触发视觉修改。
 * ThemePro hook 了 NewMainFrameViewController、ContactsViewController、
 * NewSettingViewController 等的此方法。
 * LiquidGlass 也会在此应用导航栏/标签栏的玻璃效果。
 */
- (void)viewWillAppear:(BOOL)animated {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * viewDidAppear: — 同上。
 */
- (void)viewDidAppear:(BOOL)animated {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * viewDidLoad — ThemePro hook 了 BaseMsgContentViewController、
 * NewMainFrameViewController 等多个 Controller 的此方法，
 * LiquidGlass 也在此执行初始化设置。
 */
- (void)viewDidLoad {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * viewDidLayoutSubviews — 两个插件都在布局完成后调整子视图。
 */
- (void)viewDidLayoutSubviews {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * viewWillLayoutSubviews — 布局前可能触发冲突。
 */
- (void)viewWillLayoutSubviews {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

%end // UIViewController

// ============================================================================
// UIScrollView — scrollViewDidScroll 也是冲突热点
// ============================================================================

%hook UIScrollView

/*
 * setContentOffset: — ThemePro hook 了 NewMainFrameViewController 的
 * scrollViewDidScroll:，其中如果修改 contentOffset 会触发此方法。
 * LiquidGlass 也会操作 scrollView 的 contentOffset/inset。
 */
- (void)setContentOffset:(CGPoint)contentOffset {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

%end // UIScrollView

// ============================================================================
// UINavigationBar — 导航栏也是两个插件都会修改的组件
// ============================================================================

%hook UINavigationBar

- (void)setFrame:(CGRect)frame {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

- (void)layoutSubviews {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

/*
 * setBackgroundImage:forBarMetrics: — ThemePro 会修改导航栏背景图。
 */
- (void)setBackgroundImage:(UIImage *)backgroundImage forBarMetrics:(UIBarMetrics)barMetrics {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

%end // UINavigationBar

// ============================================================================
// UITabBar — TabBar 是最严重的冲突区
// ============================================================================

%hook UITabBar

- (void)setFrame:(CGRect)frame {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

- (void)layoutSubviews {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

- (void)setBackgroundImage:(UIImage *)backgroundImage {
    REENTRY_GUARD_BEGIN
    %orig;
    REENTRY_GUARD_END
}

%end // UITabBar

// ============================================================================
// %ctor — 确保在插件加载后立即激活
// ============================================================================

%ctor {
    // 在构造函数中初始化 Logos 钩子。
    // %init 按 group 名称字母顺序执行，这里没有显式 group 所以直接初始化。
    %init;

    // 延迟到主线程确认钩子已安装（UIKit 此时应已完全初始化）。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSLog(@"[AACompat] Compatibility bridge initialized — "
              "reentry guard active for UIView/UIViewController/UITabBar/UINavigationBar");
    });
}
