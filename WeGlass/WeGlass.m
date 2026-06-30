/**
 * WeGlass v6 — Native frosted glass effect for WeChat
 *
 * Detection: isKindOfClass: + class name + position (3 tiers)
 * Hook:      willMoveToSuperview: only (NOT hooked by ThemePro)
 * Safety:    sync only — no dispatch_async, no __unsafe_unretained
 *            Size check before applying — skip if bounds are zero
 *
 * Compat: ThemePro — zero hook overlap, zero conflict
 * Device:  iPhone 7 (A10), iOS 14.0+
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ── Configuration ──────────────────────────────────────────────

#define BLUR_STYLE  UIBlurEffectStyleLight
#define TINT_ALPHA  0.40
#define BLUR_ALPHA  0.70
#define CELL_ALPHA  0.35

// ── Associated object keys ─────────────────────────────────────

static const void *kGlassKey    = &kGlassKey;
static const void *kBlurViewKey = &kBlurViewKey;
static const void *kTintViewKey = &kTintViewKey;

// ── Original IMP ───────────────────────────────────────────────

static void (*_orig_willMoveToSuperview)(id, SEL, UIView *);

// ── Detection ──────────────────────────────────────────────────

typedef NS_ENUM(NSInteger, GlassTarget) {
    GlassTargetNone = 0,
    GlassTargetNavBar,
    GlassTargetTabBar,
    GlassTargetSearchBar,
    GlassTargetTableList,
    GlassTargetCell,
};

static BOOL _nameHas(UIView *view, NSString *s) {
    NSString *name = NSStringFromClass([view class]);
    return name && [name rangeOfString:s].location != NSNotFound;
}

static GlassTarget _classify(UIView *view) {
    CGRect b = view.bounds;
    if (b.size.width < 40 || b.size.height < 20) return GlassTargetNone;

    // Tier 1: UIKit class hierarchy
    if ([view isKindOfClass:[UINavigationBar class]]) return GlassTargetNavBar;
    if ([view isKindOfClass:[UITabBar class]])       return GlassTargetTabBar;
    if ([view isKindOfClass:[UISearchBar class]])    return GlassTargetSearchBar;
    if ([view isKindOfClass:[UIToolbar class]])      return GlassTargetNavBar;
    if ([view isKindOfClass:[UITableView class]])    return GlassTargetTableList;
    if ([view isKindOfClass:[UICollectionView class]]) return GlassTargetTableList;
    if ([view isKindOfClass:[UITableViewCell class]]) return GlassTargetCell;
    if ([view isKindOfClass:[UICollectionViewCell class]]) return GlassTargetCell;

    // Tier 2: Class name patterns
    if (_nameHas(view, @"NavigationBar") || _nameHas(view, @"MMNav"))   return GlassTargetNavBar;
    if (_nameHas(view, @"TabBar")        || _nameHas(view, @"MMTab"))   return GlassTargetTabBar;
    if (_nameHas(view, @"SearchBar")     || _nameHas(view, @"MMSearch")) return GlassTargetSearchBar;
    if (_nameHas(view, @"TableView")     || _nameHas(view, @"CollectionView")
                                        || _nameHas(view, @"ListView")) return GlassTargetTableList;
    if (_nameHas(view, @"Cell"))                                         return GlassTargetCell;

    // Tier 3: Position heuristic
    CGFloat sw = [UIScreen mainScreen].bounds.size.width;
    if (b.size.width < sw * 0.85) return GlassTargetNone;

    if (view.frame.origin.y <= 0 && b.size.height >= 40 && b.size.height <= 140)
        return GlassTargetNavBar;

    UIWindow *win = view.window;
    if (win) {
        CGRect abs = [view convertRect:b toView:win];
        CGFloat bot = abs.origin.y + abs.size.height;
        if (bot >= win.bounds.size.height - 5 && b.size.height >= 40 && b.size.height <= 100)
            return GlassTargetTabBar;
    }

    return GlassTargetNone;
}

// ── Glass application (sync, bounds must be non-zero) ──────────

static BOOL _done(UIView *v) { return objc_getAssociatedObject(v, kGlassKey) != nil; }
static void _mark(UIView *v) { objc_setAssociatedObject(v, kGlassKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static UIColor *_tint(void) { return [UIColor colorWithWhite:0.97 alpha:TINT_ALPHA]; }

static void _glassBar(UIView *bar) {
    if (_done(bar)) return;
    _mark(bar);

    bar.backgroundColor = [UIColor clearColor];

    if ([bar respondsToSelector:@selector(setTranslucent:)])
        [(UINavigationBar *)bar setTranslucent:YES];
    if ([bar respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)])
        [(UINavigationBar *)bar setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
    if ([bar respondsToSelector:@selector(setShadowImage:)])
        [(UINavigationBar *)bar setShadowImage:[[UIImage alloc] init]];
    if ([bar respondsToSelector:@selector(setBarTintColor:)])
        [bar performSelector:@selector(setBarTintColor:) withObject:[UIColor clearColor]];

    UIView *tint = [[UIView alloc] initWithFrame:bar.bounds];
    tint.backgroundColor = _tint();
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.userInteractionEnabled = NO;
    tint.tag = 0x5765476C;
    [bar insertSubview:tint atIndex:0];
    objc_setAssociatedObject(bar, kTintViewKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:BLUR_STYLE]];
    blur.frame = bar.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.alpha = BLUR_ALPHA;
    blur.tag = 0x5765476C;
    [bar insertSubview:blur atIndex:0];
    objc_setAssociatedObject(bar, kBlurViewKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _glassList(UIView *list) {
    if (_done(list)) return;
    _mark(list);
    list.backgroundColor = [UIColor clearColor];

    UIView *tint = [[UIView alloc] initWithFrame:list.bounds];
    tint.backgroundColor = _tint();
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.userInteractionEnabled = NO;
    tint.tag = 0x5765476C;
    [list insertSubview:tint atIndex:0];
    objc_setAssociatedObject(list, kTintViewKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:BLUR_STYLE]];
    blur.frame = list.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blur.alpha = BLUR_ALPHA;
    blur.tag = 0x5765476C;
    [list insertSubview:blur atIndex:0];
    objc_setAssociatedObject(list, kBlurViewKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _glassCell(UIView *cell) {
    if (_done(cell)) return;
    _mark(cell);

    if (cell.backgroundColor && CGColorGetAlpha(cell.backgroundColor.CGColor) > 0.5)
        cell.backgroundColor = [cell.backgroundColor colorWithAlphaComponent:CELL_ALPHA];

    if ([cell respondsToSelector:@selector(contentView)]) {
        UIView *cv = [(UITableViewCell *)cell contentView];
        if (cv.backgroundColor && CGColorGetAlpha(cv.backgroundColor.CGColor) > 0.5)
            cv.backgroundColor = [cv.backgroundColor colorWithAlphaComponent:CELL_ALPHA];
    }
}

static void _tryGlass(UIView *view) {
    // Bounds must be set — skip otherwise (view will re-trigger when sized)
    if (view.bounds.size.width <= 0 && view.bounds.size.height <= 0) return;

    switch (_classify(view)) {
        case GlassTargetNavBar:
        case GlassTargetTabBar:
        case GlassTargetSearchBar:
            _glassBar(view);
            break;
        case GlassTargetTableList:
            _glassList(view);
            break;
        case GlassTargetCell:
            _glassCell(view);
            break;
        default: break;
    }
}

// ── Hook ───────────────────────────────────────────────────────

static void _hook_willMoveToSuperview(id self, SEL _cmd, UIView *newSuperview) {
    if (_orig_willMoveToSuperview) _orig_willMoveToSuperview(self, _cmd, newSuperview);
    if (!newSuperview) return;
    _tryGlass((UIView *)self);
}

// ── Constructor ────────────────────────────────────────────────

__attribute__((constructor))
static void WeGlass_init(void) {
    Method m = class_getInstanceMethod([UIView class], @selector(willMoveToSuperview:));
    if (m) {
        _orig_willMoveToSuperview = (void *)method_setImplementation(
            m, (IMP)_hook_willMoveToSuperview);
    }
    NSLog(@"[WeGlass] v6 — sync only, 3-tier detection, zero async");
}
