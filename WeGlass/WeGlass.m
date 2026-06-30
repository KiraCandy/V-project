/**
 * WeGlass v9 — Safe class-name detection: only call bar APIs on confirmed bar classes
 *
 * Key fix (v8→v9): If a view matches by NAME but NOT by isKindOfClass,
 * only set UIView-generic properties (backgroundColor).
 * Bar-specific API (setBackgroundImage:, translucent, etc.) is ONLY
 * called when isKindOfClass: confirms the view IS that bar type.
 *
 * Hook:      willMoveToSuperview: (not hooked by ThemePro)
 * Device:    iPhone 7 (A10), iOS 14.0+
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define CELL_ALPHA 0.35

static const void *kDoneKey = &kDoneKey;
static void (*_orig)(id, SEL, UIView *);
static _Thread_local int _depth = 0;

static BOOL _done(id v) { return objc_getAssociatedObject(v, kDoneKey) != nil; }
static void _mark(id v) { objc_setAssociatedObject(v, kDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

static BOOL _nameHas(UIView *v, NSString *s) {
    NSString *name = NSStringFromClass([v class]);
    return name ? ([name rangeOfString:s].location != NSNotFound) : NO;
}

static void _glassify(id self) {
    UIView *v = (UIView *)self;
    if (_done(v)) return;
    if (v.bounds.size.width <= 0 && v.bounds.size.height <= 0) return;

    _depth++;
    if (_depth > 30) { _depth--; return; }

    // ── Check what this view is ─────────────────────────────
    BOOL isUINav  = [v isKindOfClass:[UINavigationBar class]];
    BOOL isUITab  = [v isKindOfClass:[UITabBar class]];
    BOOL isUISrch = [v isKindOfClass:[UISearchBar class]];
    BOOL isUITool = [v isKindOfClass:[UIToolbar class]];
    BOOL isUIList = [v isKindOfClass:[UITableView class]]
                 || [v isKindOfClass:[UICollectionView class]];
    BOOL isUICell = [v isKindOfClass:[UITableViewCell class]]
                 || [v isKindOfClass:[UICollectionViewCell class]];

    BOOL nameNav  = _nameHas(v, @"NavigationBar") || _nameHas(v, @"MMNav");
    BOOL nameTab  = _nameHas(v, @"TabBar")        || _nameHas(v, @"MMTab");
    BOOL nameSrch = _nameHas(v, @"SearchBar")     || _nameHas(v, @"MMSearch");
    BOOL nameTool = _nameHas(v, @"Toolbar");
    BOOL nameList = _nameHas(v, @"TableView")     || _nameHas(v, @"CollectionView")
                                                  || _nameHas(v, @"ListView");
    BOOL nameCell = _nameHas(v, @"Cell");

    // ── Navigation bar ─────────────────────────────────────
    if (isUINav || nameNav) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        if (isUINav) {
            UINavigationBar *nb = (UINavigationBar *)v;
            nb.translucent = YES;
            [nb setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
            [nb setShadowImage:[[UIImage alloc] init]];
        }
        _depth--;
        return;
    }

    // ── Tab bar ────────────────────────────────────────────
    if (isUITab || nameTab) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        if (isUITab) {
            UITabBar *tb = (UITabBar *)v;
            tb.translucent = YES;
            [tb setBackgroundImage:[[UIImage alloc] init]];
            [tb setShadowImage:[[UIImage alloc] init]];
        }
        _depth--;
        return;
    }

    // ── Search bar ─────────────────────────────────────────
    if (isUISrch || nameSrch) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        if (isUISrch) {
            UISearchBar *sb = (UISearchBar *)v;
            sb.translucent = YES;
            [sb setBackgroundImage:[[UIImage alloc] init]];
        }
        _depth--;
        return;
    }

    // ── Toolbar ────────────────────────────────────────────
    if (isUITool || nameTool) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        if (isUITool) {
            UIToolbar *tb = (UIToolbar *)v;
            tb.translucent = YES;
            [tb setBackgroundImage:[[UIImage alloc] init]
                forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
        }
        _depth--;
        return;
    }

    // ── Table / collection view ────────────────────────────
    if (isUIList || nameList) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _depth--;
        return;
    }

    // ── Cell ───────────────────────────────────────────────
    if (isUICell || nameCell) {
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
    NSLog(@"[WeGlass] v9 — name detection + safe call (bar APIs only on confirmed bar classes)");
}
