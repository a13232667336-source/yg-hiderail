// HideRail v4 - tap-to-target picker (debug).
//
// A small red "HR" button floats on screen. While the rail is visible, tap it:
//   1. hit-tests a few points just inside the left edge
//   2. walks up the ancestor chain, hides the first narrow & tall ancestor
//   3. prints the whole chain (class + frame) into the green read-only HUD
// Screenshot the HUD, and the rail is gone -> we know exactly what to hide.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdarg.h>

static NSMutableArray *gLog = nil;
static UITextView *gHud = nil;
static BOOL gDidInit = NO;

static void HRLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[HideRail] %@", msg);
    if (!gLog) gLog = [NSMutableArray array];
    [gLog addObject:msg];
    if (gLog.count > 42) [gLog removeObjectAtIndex:0];
}

static void HRRender(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!gHud) return;
        NSMutableString *s = [NSMutableString stringWithString:@"HideRail v4\n"];
        for (NSString *l in gLog) [s appendFormat:@"%@\n", l];
        gHud.text = s;
    });
}

static UIWindow *HRKeyWindow(void) {
    UIWindow *kw = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { kw = w; break; }
    }
    return kw ? kw : [UIApplication sharedApplication].windows.firstObject;
}

static NSString *HRFmt(UIView *v) {
    CGRect f = [v convertRect:v.bounds toView:nil];
    return [NSString stringWithFormat:@"%@ x=%.0f y=%.0f w=%.0f h=%.0f",
            NSStringFromClass([v class]), f.origin.x, f.origin.y, f.size.width, f.size.height];
}

static void HRHide(UIView *v) {
    CGRect f = v.frame;
    v.hidden = YES;
    v.alpha = 0.0;
    v.userInteractionEnabled = NO;
    v.frame = CGRectMake(-MAX(f.size.width, 500.0), f.origin.y, f.size.width, f.size.height);
}

@interface HRPicker : NSObject
+ (instancetype)shared;
- (void)tap:(id)sender;
@end

@implementation HRPicker
+ (instancetype)shared {
    static HRPicker *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[HRPicker alloc] init]; });
    return s;
}
- (void)tap:(id)sender {
    UIWindow *win = HRKeyWindow();
    if (!win) { HRLog(@"no window"); HRRender(); return; }
    CGFloat H = win.bounds.size.height;
    NSArray *probes = @[ @[@6, @(H * 0.5)], @[@6, @(H * 0.35)], @[@6, @(H * 0.65)],
                         @[@24, @(H * 0.5)], @[@60, @(H * 0.5)] ];
    UIView *target = nil;
    for (NSArray *p in probes) {
        CGPoint pt = CGPointMake([p[0] doubleValue], [p[1] doubleValue]);
        UIView *hit = [win hitTest:pt withEvent:nil];
        if (!hit) continue;
        HRLog(@"hit(%.0f,%.0f)=%@", pt.x, pt.y, NSStringFromClass([hit class]));
        UIView *cur = hit;
        int depth = 0;
        while (cur && depth < 12) {
            CGRect f = [cur convertRect:cur.bounds toView:nil];
            HRLog(@"d%d %@", depth, HRFmt(cur));
            BOOL narrow = (f.size.width > 6.0 && f.size.width <= 200.0);
            BOOL tall = (f.size.height >= 180.0);
            if (!target && narrow && tall) {
                target = cur;
                HRLog(@"=> pick d%d %@", depth, NSStringFromClass([cur class]));
            }
            cur = cur.superview;
            depth++;
        }
        if (target) break;
    }
    if (target) {
        HRHide(target);
        HRLog(@"done: hid %@", NSStringFromClass([target class]));
    } else {
        HRLog(@"nothing narrow+tall at the probe points");
    }
    HRRender();
}
@end

static void HRInstallUI(void) {
    if (gDidInit) return;
    UIWindow *win = HRKeyWindow();
    if (!win) return;
    gDidInit = YES;

    CGFloat W = win.bounds.size.width, H = win.bounds.size.height;
    gHud = [[UITextView alloc] initWithFrame:CGRectMake(4, 64, W - 8, 260)];
    gHud.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    gHud.textColor = [UIColor greenColor];
    gHud.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
    gHud.editable = NO;
    gHud.userInteractionEnabled = NO;   /* never intercept the probe points */
    gHud.layer.cornerRadius = 8.0;
    gHud.textContainerInset = UIEdgeInsetsMake(4, 4, 4, 4);
    [win addSubview:gHud];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(W - 72, H - 210, 62, 62);
    [btn setTitle:@"HR" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.95];
    btn.layer.cornerRadius = 31.0;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [btn addTarget:[HRPicker shared] action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
    [win addSubview:btn];

    HRLog(@"ready - open the group, then tap the red HR button");
    HRRender();
}

__attribute__((constructor))
static void HideRailInit(void) {
    NSLog(@"[HideRail] loaded v4");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ HRInstallUI(); });
}
