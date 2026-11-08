// HideRail v3 - DIAGNOSTIC build. Hides nothing.
//
// Purpose: dump the geometry of every narrow/tall view so we can identify the real
// left rail (class name + x + width + height) from a single screenshot.
//
// Install via TrollFools, open Telegram, go to the group where the rail is visible,
// wait ~3s, then screenshot the green overlay.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdarg.h>

static NSMutableArray<NSString *> *gLines = nil;
static UIView *gHud = nil;
static BOOL gDumped = NO;

static void HRCollect(UIView *root, int depth, CGFloat winW, CGFloat winH, NSMutableArray *out) {
    if (depth > 40 || out.count > 400) return;
    CGRect f = [root convertRect:root.bounds toView:nil];
    CGFloat w = f.size.width, h = f.size.height;
    BOOL interesting = (w >= 8.0 && w <= 260.0 && h >= 120.0)
                    || (f.origin.x <= 60.0 && h >= 120.0);
    if (interesting) {
        NSString *cls = NSStringFromClass([root class]);
        [out addObject:[NSString stringWithFormat:@"d%d x=%.0f y=%.0f w=%.0f h=%.0f %@",
                        depth, f.origin.x, f.origin.y, w, h, cls]];
    }
    for (UIView *sub in root.subviews) {
        HRCollect(sub, depth + 1, winW, winH, out);
    }
}

static void HRShowHud(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
        if (!win) win = [UIApplication sharedApplication].windows.firstObject;
        if (!win) return;
        if (!gHud) {
            UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(4, 60, win.bounds.size.width - 8, win.bounds.size.height - 160)];
            tv.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.78];
            tv.textColor = [UIColor greenColor];
            tv.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
            tv.editable = NO;
            tv.scrollEnabled = YES;
            tv.layer.cornerRadius = 8.0;
            tv.textContainerInset = UIEdgeInsetsMake(4, 4, 4, 4);
            gHud = tv;
            [win addSubview:tv];
        }
        ((UITextView *)gHud).text = text;
        [win bringSubviewToFront:gHud];
    });
}

static void HRDump(void) {
    UIWindow *key = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { key = w; break; }
    }
    if (!key) key = [UIApplication sharedApplication].windows.firstObject;
    if (!key) return;

    NSMutableArray *rows = [NSMutableArray array];
    [rows addObject:[NSString stringWithFormat:@"screen %.0f x %.0f", key.bounds.size.width, key.bounds.size.height]];
    HRCollect(key, 0, key.bounds.size.width, key.bounds.size.height, rows);

    NSMutableString *txt = [NSMutableString stringWithFormat:@"HideRail DIAG (%lu rows)\n", (unsigned long)rows.count];
    NSInteger limit = MIN((NSInteger)rows.count, 120);
    for (NSInteger i = 0; i < limit; i++) {
        [txt appendFormat:@"%@\n", rows[i]];
    }
    NSLog(@"[HideRail] %@", txt);
    HRShowHud(txt);
}

__attribute__((constructor))
static void HideRailInit(void) {
    NSLog(@"[HideRail] loaded v3 diag");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ if (!gDumped) { gDumped = YES; HRDump(); } });

    /* re-dump when the app becomes active and every 12s for 2 minutes, so the dump
       reflects whatever screen is on top when the user takes the screenshot */
    __block int ticks = 0;
    NSTimer *t = [NSTimer scheduledTimerWithTimeInterval:4.0 repeats:YES block:^(NSTimer *timer) {
        ticks++;
        HRDump();
        if (ticks > 30) [timer invalidate];
    }];
    [[NSRunLoop mainRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
}
