/**
 * WeGlass v8 — Add class name detection to v7's safe foundation
 *
 * Detection: isKindOfClass: + class name substring match
 * Action:    Set native bar translucency + clear backgrounds only
 *            ZERO subview insertion (v7 proved this is crash-safe)
 *
 * Hook:      willMoveToSuperview: (not hooked by ThemePro)
 * Compat:    ThemePro — zero overlap
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

    BOOL isNav  = [v isKindOfClass:[UINavigationBar class]] || _nameHas(v, @"NavigationBar") || _nameHas(v, @"MMNav");
    BOOL isTab  = [v isKindOfClass:[UITabBar class]]       || _nameHas(v, @"TabBar")       || _nameHas(v, @"MMTab");
    BOOL isSrch = [v isKindOfClass:[UISearchBar class]]    || _nameHas(v, @"SearchBar")    || _nameHas(v, @"MMSearch");
    BOOL isTool = [v isKindOfClass:[UIToolbar class]]      || _nameHas(v, @"Toolbar");
    BOOL isList = [v isKindOfClass:[UITableView class]]    || [v isKindOfClass:[UICollectionView class]]
                                                           || _nameHas(v, @"TableView")
                                                           || _nameHas(v, @"CollectionView")
                                                           || _nameHas(v, @"ListView");
    BOOL isCell = [v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UICollectionViewCell class]]
                                                           || _nameHas(v, @"Cell");

    if (isNav) {
        _mark(v);
        UINavigationBar *nb = (UINavigationBar *)v;
        nb.translucent = YES;
        nb.backgroundColor = [UIColor clearColor];
        [nb setBackgroundImage:[[UIImage alloc] init] forBarMetrics:UIBarMetricsDefault];
        [nb setShadowImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    if (isTab) {
        _mark(v);
        UITabBar *tb = (UITabBar *)v;
        tb.translucent = YES;
        tb.backgroundColor = [UIColor clearColor];
        [tb setBackgroundImage:[[UIImage alloc] init]];
        [tb setShadowImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    if (isSrch) {
        _mark(v);
        UISearchBar *sb = (UISearchBar *)v;
        sb.translucent = YES;
        sb.backgroundColor = [UIColor clearColor];
        [sb setBackgroundImage:[[UIImage alloc] init]];
        _depth--;
        return;
    }

    if (isTool) {
        _mark(v);
        UIToolbar *tb = (UIToolbar *)v;
        tb.translucent = YES;
        tb.backgroundColor = [UIColor clearColor];
        [tb setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
        _depth--;
        return;
    }

    if (isList) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _depth--;
        return;
    }

    if (isCell) {
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
    NSLog(@"[WeGlass] v8 — class name + isKindOfClass detection, native translucency");
}
