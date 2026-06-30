/**
 * WeGlass v7 — Minimal crash-safe frosted glass
 *
 * Strategy: Use iOS native bar translucency (built-in UIVisualEffectView blur).
 * DO NOT insert any subviews — only set existing bar properties.
 * This avoids all view-hierarchy manipulation during setup.
 *
 * Hook:      willMoveToSuperview: (not hooked by ThemePro)
 * Detection: isKindOfClass: only — no string alloc, no screen access
 *
 * Compat: ThemePro — zero overlap
 * Device:  iPhone 7 (A10), iOS 14.0+
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define CELL_ALPHA 0.35

static const void *kDoneKey = &kDoneKey;
static void (*_orig)(id, SEL, UIView *);
static _Thread_local int _depth = 0;

static BOOL _done(id v) { return objc_getAssociatedObject(v, kDoneKey) != nil; }
static void _mark(id v) { objc_setAssociatedObject(v, kDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

static void _glassify(id self) {
    UIView *v = (UIView *)self;
    if (_done(v)) return;
    if (v.bounds.size.width <= 0 && v.bounds.size.height <= 0) return;

    _depth++;
    if (_depth > 30) { _depth--; return; }

    // ── UINavigationBar / subclasses (e.g. MMUINavigationBar) ──
    if ([v isKindOfClass:[UINavigationBar class]]) {
        _mark(v);
        UINavigationBar *nb = (UINavigationBar *)v;
        nb.translucent = YES;
        nb.backgroundColor = [UIColor clearColor];
        [nb setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [nb setShadowImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    // ── UITabBar / subclasses ──────────────────────────────────
    if ([v isKindOfClass:[UITabBar class]]) {
        _mark(v);
        UITabBar *tb = (UITabBar *)v;
        tb.translucent = YES;
        tb.backgroundColor = [UIColor clearColor];
        [tb setBackgroundImage:[[UIImage alloc] init]];
        [tb setShadowImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    // ── UISearchBar / subclasses ───────────────────────────────
    if ([v isKindOfClass:[UISearchBar class]]) {
        _mark(v);
        UISearchBar *sb = (UISearchBar *)v;
        sb.translucent = YES;
        sb.backgroundColor = [UIColor clearColor];
        [sb setBackgroundImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    // ── UIToolbar / subclasses ─────────────────────────────────
    if ([v isKindOfClass:[UIToolbar class]]) {
        _mark(v);
        UIToolbar *tb = (UIToolbar *)v;
        tb.translucent = YES;
        tb.backgroundColor = [UIColor clearColor];
        [tb setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
        _depth--;
        return;
    }

    // ── UITableView / UICollectionView ─────────────────────────
    if ([v isKindOfClass:[UITableView class]] || [v isKindOfClass:[UICollectionView class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _depth--;
        return;
    }

    // ── UITableViewCell / UICollectionViewCell ──────────────────
    if ([v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UICollectionViewCell class]]) {
        _mark(v);
        if (v.backgroundColor && CGColorGetAlpha(v.backgroundColor.CGColor) > 0.5)
            v.backgroundColor = [v.backgroundColor colorWithAlphaComponent:CELL_ALPHA];
        if ([v respondsToSelector:@selector(contentView)]) {
            UIView *cv = [(UITableViewCell *)v contentView];
            if (cv.backgroundColor && CGColorGetAlpha(cv.backgroundColor.CGColor) > 0.5)
                cv.backgroundColor = [cv.backgroundColor colorWithAlphaComponent:CELL_ALPHA];
        }
        _depth--;
        return;
    }

    _depth--;
}

static void _hook(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig) _orig(self, _cmd, newSuperview);
    if (!newSuperview) return;
    _glassify(self);
}

__attribute__((constructor))
static void init(void) {
    Method m = class_getInstanceMethod([UIView class], @selector(willMoveToSuperview:));
    if (m) _orig = (void *)method_setImplementation(m, (IMP)_hook);
    NSLog(@"[WeGlass] v7 — native translucency, no subview insertion");
}
