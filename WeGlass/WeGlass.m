/**
 * WeGlass v4 — Native frosted glass effect for WeChat
 *
 * Strategy: Use isKindOfClass: on known UIKit component types instead of
 * guessing WeChat internal class names. WeChat's custom subclasses
 * (e.g. MMUINavigationBar : UINavigationBar) are auto-detected.
 *
 * Hook willMoveToSuperview: (NOT hooked by ThemePro — zero conflict).
 * On first layoutSubviews pass (frame final), apply UIVisualEffectView.
 *
 * Compat: ThemePro (libPineappleDylib) — separate hook points, no recursion
 * Device:  iPhone 7 (A10), iOS 14.0+
 * Build:   clang -dynamiclib for TrollStore IPA injection
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Configuration ──────────────────────────────────────────────

#define BLUR_STYLE UIBlurEffectStyleLight
#define BLUR_ALPHA 0.60

// ── Associated object keys ─────────────────────────────────────

static const void *kGlassAppliedKey = &kGlassAppliedKey;
static const void *kGlassViewKey    = &kGlassViewKey;
static const void *kGlassedSuperviewKey = &kGlassedSuperviewKey;

// ── Original IMP ───────────────────────────────────────────────

static void (*_orig_willMoveToSuperview)(id, SEL, UIView *);

// ── Determine what kind of view this is ────────────────────────

typedef NS_ENUM(NSInteger, GlassTarget) {
    GlassTargetNone = 0,
    GlassTargetNavBar,
    GlassTargetTabBar,
    GlassTargetSearchBar,
    GlassTargetToolbar,
    GlassTargetTableView,
    GlassTargetCell,
};

static GlassTarget _classifyView(UIView *view) {
    // Bars
    if ([view isKindOfClass:[UINavigationBar class]]) return GlassTargetNavBar;
    if ([view isKindOfClass:[UITabBar class]])       return GlassTargetTabBar;
    if ([view isKindOfClass:[UISearchBar class]])    return GlassTargetSearchBar;
    if ([view isKindOfClass:[UIToolbar class]])      return GlassTargetToolbar;

    // Table/collection views
    if ([view isKindOfClass:[UITableView class]])    return GlassTargetTableView;

    // Cells
    if ([view isKindOfClass:[UITableViewCell class]]) return GlassTargetCell;
    if ([view isKindOfClass:[UICollectionViewCell class]]) return GlassTargetCell;

    return GlassTargetNone;
}

// ── Apply glass effect ─────────────────────────────────────────

static void _glassifyBar(UIView *bar) {
    if (objc_getAssociatedObject(bar, kGlassAppliedKey)) return;
    objc_setAssociatedObject(bar, kGlassAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Remove solid background
    bar.backgroundColor = [UIColor clearColor];

    // Remove background image (UINavigationBar / UITabBar)
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        [(UINavigationBar *)bar setBackgroundImage:[[UIImage alloc] init]
                                     forBarMetrics:UIBarMetricsDefault];
    }
    if ([bar respondsToSelector:@selector(setShadowImage:)]) {
        [(UINavigationBar *)bar setShadowImage:[[UIImage alloc] init]];
    }

    // Insert blur
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = bar.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C;

    [bar insertSubview:blurView atIndex:0];
    objc_setAssociatedObject(bar, kGlassViewKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _glassifyTable(UIView *table) {
    if (objc_getAssociatedObject(table, kGlassAppliedKey)) return;
    objc_setAssociatedObject(table, kGlassAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    table.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = table.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C;

    // Insert below all subviews (cells)
    [table insertSubview:blurView atIndex:0];
    objc_setAssociatedObject(table, kGlassViewKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _glassifyCell(UIView *cell) {
    if (objc_getAssociatedObject(cell, kGlassAppliedKey)) return;
    objc_setAssociatedObject(cell, kGlassAppliedKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Make cell background semi-transparent so table blur shows through
    UIColor *bg = cell.backgroundColor;
    if (bg) {
        CGColorRef cg = bg.CGColor;
        if (!CGColorEqualToColor(cg, [UIColor clearColor].CGColor)) {
            CGFloat a = CGColorGetAlpha(cg);
            if (a > 0.5) {
                cell.backgroundColor = [bg colorWithAlphaComponent:0.40];
            }
        }
    }

    // Also handle contentView
    if ([cell respondsToSelector:@selector(contentView)]) {
        UIView *cv = [(UITableViewCell *)cell contentView];
        UIColor *cvbg = cv.backgroundColor;
        if (cvbg) {
            CGColorRef cvcg = cvbg.CGColor;
            if (!CGColorEqualToColor(cvcg, [UIColor clearColor].CGColor)) {
                CGFloat a = CGColorGetAlpha(cvcg);
                if (a > 0.5) {
                    cv.backgroundColor = [cvbg colorWithAlphaComponent:0.40];
                }
            }
        }
    }
}

// ── Hook: willMoveToSuperview: (no ThemePro conflict) ──────────

static void _hook_willMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig_willMoveToSuperview) _orig_willMoveToSuperview(self, _cmd, newSuperview);
    if (!newSuperview) return;

    UIView *view = (UIView *)self;
    GlassTarget target = _classifyView(view);

    switch (target) {
        case GlassTargetNavBar:
        case GlassTargetTabBar:
        case GlassTargetSearchBar:
        case GlassTargetToolbar:
            _glassifyBar(view);
            break;
        case GlassTargetTableView:
            _glassifyTable(view);
            break;
        case GlassTargetCell:
            _glassifyCell(view);
            break;
        case GlassTargetNone:
            break;
    }
}

// ── Constructor ────────────────────────────────────────────────

__attribute__((constructor))
static void WeGlass_init(void) {
    Method m = class_getInstanceMethod([UIView class],
                                       @selector(willMoveToSuperview:));
    if (m) {
        _orig_willMoveToSuperview = (void *)method_setImplementation(
            m, (IMP)_hook_willMoveToSuperview);
    }

    NSLog(@"[WeGlass] v4 initialized — isKindOfClass: based glass for "
          "UINavigationBar/UITabBar/UISearchBar/UITableView/UITableViewCell");
}