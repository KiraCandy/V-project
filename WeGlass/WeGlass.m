/**
 * WeGlass v5 — Native frosted glass effect for WeChat
 *
 * Three-layer detection strategy:
 *   1. isKindOfClass: on UIKit types (catches MMUINavigationBar, etc.)
 *   2. Class name substring match for WeChat custom bars
 *   3. Position-based heuristic (top area = nav bar, bottom = tab bar)
 *
 * Hook: willMoveToSuperview: (NOT hooked by ThemePro — zero conflict)
 * Glass: UIVisualEffectView + semi-transparent tint layer
 *
 * Compat: ThemePro (libPineappleDylib) — separate hook points, no recursion
 * Device:  iPhone 7 (A10), iOS 14.0+
 * Build:   clang -dynamiclib for TrollStore IPA injection
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Configuration ──────────────────────────────────────────────

#define BLUR_STYLE      UIBlurEffectStyleLight
#define TINT_ALPHA      0.45
#define BLUR_ALPHA      0.72
#define CELL_ALPHA      0.35

// ── Associated object keys ─────────────────────────────────────

static const void *kGlassKey   = &kGlassKey;
static const void *kGlassBlurKey = &kGlassBlurKey;
static const void *kGlassTintKey = &kGlassTintKey;

// ── Original IMP ───────────────────────────────────────────────

static void (*_orig_willMoveToSuperview)(id, SEL, UIView *);

// ── Helpers ────────────────────────────────────────────────────

static UIColor *_tintColor(void) {
    return [UIColor colorWithWhite:0.97 alpha:TINT_ALPHA];
}

static NSString *_className(id obj) {
    return NSStringFromClass([obj class]);
}

// ── Three-tier detection ───────────────────────────────────────

typedef NS_ENUM(NSInteger, GlassTarget) {
    GlassTargetNone = 0,
    GlassTargetNavBar,
    GlassTargetTabBar,
    GlassTargetSearchBar,
    GlassTargetTableList,
    GlassTargetCell,
};

static GlassTarget _detectByClass(UIView *view) {
    if ([view isKindOfClass:[UINavigationBar class]]) return GlassTargetNavBar;
    if ([view isKindOfClass:[UITabBar class]])       return GlassTargetTabBar;
    if ([view isKindOfClass:[UISearchBar class]])    return GlassTargetSearchBar;
    if ([view isKindOfClass:[UIToolbar class]])      return GlassTargetNavBar;
    if ([view isKindOfClass:[UITableView class]])    return GlassTargetTableList;
    if ([view isKindOfClass:[UICollectionView class]]) return GlassTargetTableList;
    if ([view isKindOfClass:[UITableViewCell class]]) return GlassTargetCell;
    if ([view isKindOfClass:[UICollectionViewCell class]]) return GlassTargetCell;
    return GlassTargetNone;
}

static BOOL _strContains(NSString *s, NSString *sub) {
    if (!s || !sub) return NO;
    return [s rangeOfString:sub].location != NSNotFound;
}

static GlassTarget _detectByName(UIView *view) {
    NSString *name = _className(view);
    if (!name) return GlassTargetNone;

    // Navigation / title bars
    if (_strContains(name, @"NavigationBar")
     || _strContains(name, @"TitleBar")
     || _strContains(name, @"MMNav")) {
        return GlassTargetNavBar;
    }

    // Tab bars
    if (_strContains(name, @"TabBar")
     || _strContains(name, @"TabView")
     || _strContains(name, @"MMTab")) {
        return GlassTargetTabBar;
    }

    // Search bars
    if (_strContains(name, @"SearchBar")
     || _strContains(name, @"MMSearch")) {
        return GlassTargetSearchBar;
    }

    // Tables / lists
    if (_strContains(name, @"TableView")
     || _strContains(name, @"CollectionView")
     || _strContains(name, @"ListView")) {
        return GlassTargetTableList;
    }

    // Cells
    if (_strContains(name, @"Cell")
     || _strContains(name, @"TableCell")) {
        return GlassTargetCell;
    }

    return GlassTargetNone;
}

static GlassTarget _detectByPosition(UIView *view) {
    CGRect f = view.frame;
    if (f.size.width < 50 || f.size.height < 30) return GlassTargetNone;

    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    // Only consider full-width views
    if (f.size.width < sw * 0.85) return GlassTargetNone;

    // Top area: nav bar height range (44-140pt)
    if (f.origin.y <= 0 && f.size.height >= 40 && f.size.height <= 140) {
        return GlassTargetNavBar;
    }

    // Bottom area: tab bar height range (40-100pt)
    UIWindow *win = view.window;
    if (win) {
        CGFloat sh = win.bounds.size.height;
        CGRect absFrame = [view convertRect:view.bounds toView:win];
        CGFloat botEdge = absFrame.origin.y + absFrame.size.height;
        if (botEdge >= sh - 5 && f.size.height >= 40 && f.size.height <= 100) {
            return GlassTargetTabBar;
        }
    }

    return GlassTargetNone;
}

static GlassTarget _classifyView(UIView *view) {
    // Tier 1: UIKit class hierarchy
    GlassTarget t = _detectByClass(view);
    if (t != GlassTargetNone) return t;

    // Tier 2: Class name pattern
    t = _detectByName(view);
    if (t != GlassTargetNone) return t;

    // Tier 3: Position heuristic
    return _detectByPosition(view);
}

// ── Glass application ──────────────────────────────────────────

static BOOL _hasGlass(UIView *view) {
    return objc_getAssociatedObject(view, kGlassKey) != nil;
}

static void _markGlass(UIView *view) {
    objc_setAssociatedObject(view, kGlassKey, @YES,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _applyBarGlass(UIView *bar) {
    if (_hasGlass(bar)) return;
    _markGlass(bar);

    // Strip solid backgrounds
    bar.backgroundColor = [UIColor clearColor];
    if ([bar respondsToSelector:@selector(setTranslucent:)]) {
        [(UINavigationBar *)bar setTranslucent:YES];
    }

    // Remove bar background image & shadow
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        UINavigationBar *nb = (UINavigationBar *)bar;
        [nb setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [nb setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsCompact];
    }
    if ([bar respondsToSelector:@selector(setShadowImage:)]) {
        [(UINavigationBar *)bar setShadowImage:[[UIImage alloc] init]];
    }
    if ([bar respondsToSelector:@selector(setBackgroundImage:)]) {
        [(UITabBar *)bar setBackgroundImage:[[UIImage alloc] init]];
    }
    if ([bar respondsToSelector:@selector(setBarTintColor:)]) {
        [bar performSelector:@selector(setBarTintColor:) withObject:[UIColor clearColor]];
    }

    // Tint layer for visible frosted-opacity
    UIView *tint = [[UIView alloc] initWithFrame:bar.bounds];
    tint.backgroundColor = _tintColor();
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth
                          | UIViewAutoresizingFlexibleHeight;
    tint.userInteractionEnabled = NO;
    tint.tag = 0x5765476C;
    [bar insertSubview:tint atIndex:0];
    objc_setAssociatedObject(bar, kGlassTintKey, tint,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Blur layer
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = bar.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C;
    [bar insertSubview:blurView atIndex:0];
    objc_setAssociatedObject(bar, kGlassBlurKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _applyListGlass(UIView *list) {
    if (_hasGlass(list)) return;
    _markGlass(list);

    list.backgroundColor = [UIColor clearColor];

    // Tint + blur background
    UIView *tint = [[UIView alloc] initWithFrame:list.bounds];
    tint.backgroundColor = _tintColor();
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth
                          | UIViewAutoresizingFlexibleHeight;
    tint.userInteractionEnabled = NO;
    tint.tag = 0x5765476C;
    [list insertSubview:tint atIndex:0];
    objc_setAssociatedObject(list, kGlassTintKey, tint,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:BLUR_STYLE];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = list.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth
                              | UIViewAutoresizingFlexibleHeight;
    blurView.alpha = BLUR_ALPHA;
    blurView.tag = 0x5765476C;
    [list insertSubview:blurView atIndex:0];
    objc_setAssociatedObject(list, kGlassBlurKey, blurView,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _applyCellGlass(UIView *cell) {
    if (_hasGlass(cell)) return;
    _markGlass(cell);

    // Make cell background semi-transparent
    if (cell.backgroundColor) {
        CGColorRef cg = cell.backgroundColor.CGColor;
        if (CGColorGetAlpha(cg) > 0.5) {
            cell.backgroundColor = [cell.backgroundColor
                colorWithAlphaComponent:CELL_ALPHA];
        }
    }

    // Also transparentize contentView
    UIView *cv = nil;
    if ([cell respondsToSelector:@selector(contentView)]) {
        cv = [(UITableViewCell *)cell contentView];
    }
    if (cv && cv.backgroundColor) {
        CGColorRef cvcg = cv.backgroundColor.CGColor;
        if (CGColorGetAlpha(cvcg) > 0.5) {
            cv.backgroundColor = [cv.backgroundColor
                colorWithAlphaComponent:CELL_ALPHA];
        }
    }

    // Handle selected background
    if ([cell respondsToSelector:@selector(selectedBackgroundView)]) {
        UIView *sb = [(UITableViewCell *)cell selectedBackgroundView];
        if (sb) sb.alpha = 0.5;
    }
}

// ── Deferred glass application ────────────────────────────────
// willMoveToSuperview fires before frame is final.
// Dispatch to next runloop iteration so bounds are set.

static void _scheduleGlass(UIView *view, GlassTarget target) {
    // Only schedule if view has non-zero bounds or we expect it will soon
    // Use CFTypeRef to capture view weakly (no retain cycle risk since
    // it's just deferred by one runloop)
    __unsafe_unretained UIView *weakView = view;
    dispatch_async(dispatch_get_main_queue(), ^{
        // Re-check bounds — one runloop later they should be set
        if (weakView.bounds.size.width <= 0 && weakView.bounds.size.height <= 0) {
            // Still zero — try once more with a longer delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                          dispatch_get_main_queue(), ^{
                if (weakView.bounds.size.width > 0 || weakView.bounds.size.height > 0) {
                    switch (target) {
                        case GlassTargetNavBar:
                        case GlassTargetTabBar:
                        case GlassTargetSearchBar:
                            _applyBarGlass(weakView);
                            break;
                        case GlassTargetTableList:
                            _applyListGlass(weakView);
                            break;
                        case GlassTargetCell:
                            _applyCellGlass(weakView);
                            break;
                        default: break;
                    }
                }
            });
            return;
        }
        switch (target) {
            case GlassTargetNavBar:
            case GlassTargetTabBar:
            case GlassTargetSearchBar:
                _applyBarGlass(weakView);
                break;
            case GlassTargetTableList:
                _applyListGlass(weakView);
                break;
            case GlassTargetCell:
                _applyCellGlass(weakView);
                break;
            default: break;
        }
    });
}

// ── Hook ───────────────────────────────────────────────────────

static void _hook_willMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig_willMoveToSuperview) _orig_willMoveToSuperview(self, _cmd, newSuperview);
    if (!newSuperview) return;

    UIView *view = (UIView *)self;
    GlassTarget target = _classifyView(view);

    if (target != GlassTargetNone) {
        _scheduleGlass(view, target);
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

    NSLog(@"[WeGlass] v5 initialized — 3-tier detection + deferred glass for "
          "UINavigationBar/UITabBar/UISearchBar/table/cell + WeChat custom classes");
}
