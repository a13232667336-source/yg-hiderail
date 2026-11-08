// HideRail - hidethe left chat/channel rail in Telegram iOS 13.x group & topic screens.
//
// Strategy: no Telegram-private class names. After injection (TrollFools / ElleKit),
// the constructor runs at app launch and repeatedly walks the key window hierarchy
// looking for a left-flush, narrow, tall container that holds several image views.
//
// Debug: Console.app filter "HideRail".

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdarg.h>

/* ---- tunables ---------------------------------------------------------- */
#define RAIL_MAX_WIDTH      90.0   /* max rail width in pt */
#define RAIL_MIN_HEIGHT     200.0  /* min rail height in pt */
#define RAIL_LEFT_TOLERANCE 8.0    /* allowed origin.x drift */
#define RAIL_MIN_IMAGES     2      /* min image-like subviews */
#define SCAN_DURATION       20.0   /* seconds of repeated scanning after launch */
#define SCAN_INTERVAL       0.35   /* seconds between scans */
#define HR_LOG              1

static BOOL gHRDisabled = NO;

static void HRLog(NSString *fmt, ...) {
#if HR_LOG
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[HideRail] %@", msg);
#else
    (void)fmt;
#endif
}

/* A subview that plausibly renders an avatar. */
static BOOL HRIsImageLike(UIView *v) {
    if ([v isKindOfClass:[UIImageView class]]) return YES;
    if ([v isKindOfClass:NSClassFromString(@"TGImageView")]) return YES;
    if ([v isKindOfClass:NSClassFromString(@"YYAnimatedImageView")]) return YES;
    CALayer *l = v.layer;
    if (l.contents != nil) return YES;
    if (l.cornerRadius > 6.0 && v.bounds.size.width > 12.0 && v.bounds.size.width < 80.0) return YES;
    return NO;
}

/* Count image-like views in two levels of the subtree. */
static NSInteger HRCountImages(UIView *root) {
    NSInteger n = 0;
    for (UIView *sub in root.subviews) {
        if (HRIsImageLike(sub)) n++;
        for (UIView *sub2 in sub.subviews) {
            if (HRIsImageLike(sub2)) n++;
        }
    }
    return n;
}

/* Hide every view that looks like the rail. Returns how many got hidden. */
static NSInteger HRScan(UIView *root) {
    if (!root || root.hidden || gHRDisabled) return 0;
    NSInteger hidden = 0;

    CGRect f = [root convertRect:root.bounds toView:nil];
    BOOL leftFlush = f.origin.x <= RAIL_LEFT_TOLERANCE;
    BOOL narrow = f.size.width >= 20.0 && f.size.width <= RAIL_MAX_WIDTH;
    BOOL tall = f.size.height >= RAIL_MIN_HEIGHT;
    CGFloat winW = root.window ? CGRectGetWidth(root.window.bounds) : 0.0;
    BOOL notFullWide = (winW <= 0.0) || (f.size.width < winW * 0.45);

    if (leftFlush && narrow && tall && notFullWide) {
        NSInteger imgs = HRCountImages(root);
        if (imgs >= RAIL_MIN_IMAGES) {
            HRLog(@"hide %@ frame=%@ images=%ld", NSStringFromClass([root class]),
                  NSStringFromCGRect(f), (long)imgs);
            root.hidden = YES;
            root.alpha = 0.0;
            root.userInteractionEnabled = NO;
            return 1;
        }
    }

    for (UIView *sub in [root.subviews copy]) {
        hidden += HRScan(sub);
    }
    return hidden;
}

static void HRScanAllWindows(void) {
    if (gHRDisabled) return;
    NSInteger total = 0;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        total += HRScan(w);
    }
    if (total > 0) {
        HRLog(@"hidden %ld candidate view(s)", (long)total);
    }
}

__attribute__((constructor))
static void HideRailInit(void) {
    HRLog(@"loaded");

    NSString *flag = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hiderail.off"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:flag]) {
        gHRDisabled = YES;
        HRLog(@"disabled by flag file");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ HRScanAllWindows(); });

    __block int ticks = 0;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:SCAN_INTERVAL
                                                     repeats:YES
                                                       block:^(NSTimer *t) {
        HRScanAllWindows();
        ticks++;
        if (ticks * SCAN_INTERVAL >= SCAN_DURATION) {
            [t invalidate];
            HRLog(@"scan window finished");
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ HRScanAllWindows(); });
    }];
}
