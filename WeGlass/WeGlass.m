/**
 * WeGlass v10 — Safe, minimal approach for iPhone 7 (A10), iOS 14.0+
 *
 * v9→v10 fix: removed _nameHas (string matching crashed during
 * willMoveToSuperview: on some WeChat internal classes).
 * Switched hook to willMoveToWindow: (less frequent, not hot during startup).
 * Deferred processing via dispatch_async with __weak reference.
 * UIVisualEffectView subview insertion for actual blur, not just properties.
 * No _Thread_local — plain static, since UIKit runs on main thread.
 *
 * CompatBridge does NOT hook willMoveToWindow: — zero conflict.
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define CELL_ALPHA 0.35
#define MAX_DEPTH 30

static const void *kDoneKey = &kDoneKey;
static void (*_orig)(id, SEL, UIWindow *);
static int _depth = 0;

static BOOL _done(id v) {
    return objc_getAssociatedObject(v, kDoneKey) != nil;
}

static void _mark(id v) {
    objc_setAssociatedObject(v, kDoneKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void _insertBlur(UIView *v, UIBlurEffectStyle style) {
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:style]];
    blur.frame = v.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [v insertSubview:blur atIndex:0];
}

static void _glassify(UIView *v) {
    if (_done(v)) return;
    if (!v.window) return;
    if (v.bounds.size.width <= 0 && v.bounds.size.height <= 0) return;

    _depth++;
    if (_depth > MAX_DEPTH) { _depth--; return; }

    if ([v isKindOfClass:[UINavigationBar class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _insertBlur(v, UIBlurEffectStyleLight);
        _depth--;
        return;
    }

    if ([v isKindOfClass:[UITabBar class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _insertBlur(v, UIBlurEffectStyleLight);
        _depth--;
        return;
    }

    if ([v isKindOfClass:[UISearchBar class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _depth--;
        return;
    }

    if ([v isKindOfClass:[UIToolbar class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _insertBlur(v, UIBlurEffectStyleLight);
        _depth--;
        return;
    }

    if ([v isKindOfClass:[UITableView class]]
     || [v isKindOfClass:[UICollectionView class]]) {
        _mark(v);
        v.backgroundColor = [UIColor clearColor];
        _depth--;
        return;
    }

    if ([v isKindOfClass:[UITableViewCell class]]
     || [v isKindOfClass:[UICollectionViewCell class]]) {
        _mark(v);
        if (v.backgroundColor && CGColorGetAlpha(v.backgroundColor.CGColor) > 0.5)
            v.backgroundColor = [v.backgroundColor colorWithAlphaComponent:CELL_ALPHA];
        _depth--;
        return;
    }

    _depth--;
}

static void _hook(id self, SEL _cmd, UIWindow *newWindow) {
    if (_orig) _orig(self, _cmd, newWindow);
    if (!newWindow) return;
    if (_done(self)) return;

    __weak UIView *wv = (UIView *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *v = wv;
        if (v) _glassify(v);
    });
}

__attribute__((constructor))
static void init(void) {
    Method m = class_getInstanceMethod([UIView class], @selector(willMoveToWindow:));
    if (m) _orig = (void *)method_setImplementation(m, (IMP)_hook);
    NSLog(@"[WeGlass] v10 — willMoveToWindow: + dispatch_async + UIVisualEffectView");
}
