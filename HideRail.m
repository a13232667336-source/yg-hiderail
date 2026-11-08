// HideRail v2 - hide the left rail in Telegram iOS (TrollFools / TrollStore injection).
//
// v2 changes:
//   * deep recursive image counting (cells live 3-4 levels down, v1 only saw 2)
//   * also treats any UIScrollView/UITableView/UICollectionView as a rail signal
//   * wider width window (<= 150pt) and looser left tolerance
//   * shifts the rail off-screen as well as hiding it (non-stack layouts keep space)
//   * on-screen debug HUD: tells you what got hidden (screenshot it if it fails)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdarg.h>

/* ---- tunables ---------------------------------------------------------- */
#define RAIL_MIN_WIDTH      20.0
#define RAIL_MAX_WIDTH      150.0
#define RAIL_MIN_HEIGHT     180.0
#define RAIL_LEFT_TOLERANCE 40.0
#define RAIL_MIN_IMAGES     2
#define SCAN_DURATION       90.0
#define SCAN_INTERVAL       0.5
#define HR_LOG              1
#define HR_HUD              1

static BOOL gHRDisabled = NO;
static NSMutableArray *gHREvents = nil;
static UIView *gHRHud = nil;

static void HRLog(NSString *fmt, ...) {
#if HR_LOG
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[HideRail] %@", msg);
    if (!gHREvents) gHREvents = [NSMutableArray array];
    [gHREvents addObject:msg];
    if (gHREvents.count > 14) [gHREvents removeObjectAtIndex:0];
#else
    (void)fmt;
#endif
}

/* Recursive image-like count, depth-limited. */
static NSInteger HRCountImagesDeep(UIView *root, int depth) {
    if (depth > 6) return 0;
    NSInteger n = 0;
    for (UIView *sub in root.subviews) {
        NSString *cn = NSStringFromClass([sub class]);
        if ([sub isKindOfClass:[UIImageView class]]) n++;
        else if ([cn containsString:@"ImageView"]) n++;
        else if (sub.layer.contents != nil) n++;
        else if (sub.layer.cornerRadius > 6.0 && sub.bounds.size.width > 12.0 && sub.bounds.size.width < 90.0) n++;
        n += HRCountImagesDeep(sub, depth + 1);
        if (n >= 8) return n;
    }
    return n;
}

static BOOL HRContainsScrollable(UIView *root, int depth) {
    if (depth > 6) return NO;
    if ([root isKindOfClass:[UIScrollView class]]) return YES;   /* covers UITableView/collection */
    for (UIView *sub in root.subviews) {
        if (HRContainsScrollable(sub, depth + 1)) return YES;
    }
    return NO;
}

static void HRHudUpdate(NSString *line) {
#if HR_HUD
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
        if (!win) win = [UIApplication sharedApplication].windows.firstObject;
        if (!win) return;
        if (!gHRHud) {
            UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(8, 90, win.bounds.size.width - 16, 260)];
            tv.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.72];
            tv.textColor = [UIColor greenColor];
            tv.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
            tv.editable = NO;
            tv.scrollEnabled = YES;
            tv.layer.cornerRadius = 8.0;
            tv.textContainerInset = UIEdgeInsetsMake(6, 6, 6, 6);
            tv.userInteractionEnabled = YES;
            gHRHud = tv;
            [win addSubview:tv];
        }
        UITextView *tv = (UITextView *)gHRHud;
        tv.text = line;
        [win bringSubviewToFront:tv];
    });
#endif
}

/* Hide one candidate: hidden + alpha 0 + shift left off-screen. */
static void HRHideView(UIView *v) {
    CGRect f = v.frame;
    v.hidden = YES;
    v.alpha = 0.0;
    v.userInteractionEnabled = NO;
    v.frame = CGRectMake(-MAX(f.size.width, 400.0), f.origin.y, f.size.width, f.size.height);
}

static NSInteger HRScan(UIView *root, NSMutableArray *hits) {
    if (!root || gHRDisabled) return 0;
    NSInteger hidden = 0;

    CGRect f = [root convertRect:root.bounds toView:nil];
    CGFloat winW = root.window ? CGRectGetWidth(root.window.bounds) : 0.0;

    BOOL leftFlush = f.origin.x <= RAIL_LEFT_TOLERANCE;
    BOOL narrow = f.size.width >= RAIL_MIN_WIDTH && f.size.width <= RAIL_MAX_WIDTH;
    BOOL tall = f.size.height >= RAIL_MIN_HEIGHT;
    BOOL notFullWide = (winW <= 0.0) || (f.size.width < winW * 0.5);

    if (leftFlush && narrow && tall && notFullWide) {
        NSInteger imgs = HRCountImagesDeep(root, 0);
        BOOL scrollable = HRContainsScrollable(root, 0);
        if (imgs >= RAIL_MIN_IMAGES || scrollable) {
            NSString *desc = [NSString stringWithFormat:@"%@ w=%.0f h=%.0f img=%ld scroll=%d",
                              NSStringFromClass([root class]), f.size.width, f.size.height,
                              (long)imgs, scrollable ? 1 : 0];
            HRLog(@"hide %@", desc);
            if (hits) [hits addObject:desc];
            HRHideView(root);
            return 1;
        }
    }

    for (UIView *sub in [root.subviews copy]) {
        hidden += HRScan(sub, hits);
    }
    return hidden;
}

static void HRScanAllWindows(void) {
    if (gHRDisabled) return;
    NSMutableArray *hits = [NSMutableArray array];
    NSInteger total = 0;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        total += HRScan(w, hits);
    }
    if (total > 0) {
        HRLog(@"pass hidden=%ld", (long)total);
    }
    NSMutableString *hud = [NSMutableString stringWithString:@"HideRail\n"];
    if (gHREvents.count == 0) [hud appendString:@"(no events yet)\n"];
    for (NSString *e in gHREvents) { [hud appendFormat:@"%@\n", e]; }
    [hud appendFormat:@"\nwindows=%lu", (unsigned long)[UIApplication sharedApplication].windows.count];
    HRHudUpdate(hud);
}

__attribute__((constructor))
static void HideRailInit(void) {
    HRLog(@"loaded v2");

    NSString *flag = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hiderail.off"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:flag]) {
        gHRDisabled = YES;
        HRLog(@"disabled by flag file");
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ HRScanAllWindows(); });

    __block double elapsed = 0.0;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:SCAN_INTERVAL
                                                     repeats:YES
                                                       block:^(NSTimer *t) {
        HRScanAllWindows();
        elapsed += SCAN_INTERVAL;
        if (elapsed >= SCAN_DURATION) {
            [t invalidate];
            HRLog(@"scan finished");
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        HRScanAllWindows();
    }];
}
