// HideRail 鈥?闅愯棌 Telegram iOS 13.x 缇よ亰/璇濋椤靛乏渚ч偅鏉°€岃亰澶?棰戦亾銆嶇珫鏍?//
// 鍘熺悊锛氫笉渚濊禆浠讳綍 Telegram 绉佹湁绫诲悕銆?//   TrollFools / ElleKit 娉ㄥ叆鍚庯紝%ctor 鍦?app 鍚姩鏃惰繍琛岋紱鎴戜滑鍙嶅鎵弿 keyWindow
//   鐨勮鍥炬爲锛屾壘鍑恒€岃创宸﹁竟銆佺獎銆侀珮銆佸惈澶氫釜鍥剧墖瑙嗗浘銆嶇殑瀹瑰櫒骞?hidden = YES銆?//
// 鍙皟鍙傛暟鍦ㄤ笅闈?DEFINES 鍖猴紝鏀瑰畬閲嶆柊缂栬瘧鍗冲彲銆?//
// 璋冭瘯锛欳onsole.app 閲屾悳 "HideRail"锛屼細鎵撳嵃姣忔闅愯棌鐨?view 绫诲拰 frame銆?
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 鈹€鈹€ 鍙皟鍙傛暟 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
#define RAIL_MAX_WIDTH      90.0   // 绔栨爮鏈€澶у搴︼紙pt锛?#define RAIL_MIN_HEIGHT     200.0  // 鏈€灏忛珮搴?#define RAIL_LEFT_TOLERANCE 8.0    // 鍏佽鐨?origin.x 鍋忕Щ
#define RAIL_MIN_IMAGES     2      // 鑷冲皯鍖呭惈鍑犲紶"鍥剧墖绫?瀛愯鍥?#define SCAN_DURATION       20.0   // 鍚姩鍚庢寔缁壂鎻忓灏戠
#define SCAN_INTERVAL       0.35   // 鎵弿闂撮殧
#define HR_LOG              1      // 1 = NSLog 杈撳嚭

static BOOL gHRDisabled = NO;

static void HRLog(NSString *fmt, ...) {
#if HR_LOG
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[HideRail] %@", msg);
#endif
}

/// 涓€涓鍥炬槸鍚?鍍忓浘鐗?锛歎IImageView銆佹垨鑰?layer.contents 鏈夊唴瀹?static BOOL HRIsImageLike(UIView *v) {
    if ([v isKindOfClass:[UIImageView class]]) return YES;
    if ([v isKindOfClass:NSClassFromString(@"TGImageView")]) return YES;
    if ([v isKindOfClass:NSClassFromString(@"YYAnimatedImageView")]) return YES;
    CALayer *l = v.layer;
    if (l.contents != nil) return YES;
    // 鏈変簺澶村儚鐢?CAShapeLayer + mask锛岄€€涓€姝ョ湅鏄惁鏈?cornerRadius 鐨勫渾褰㈠皬瑙嗗浘
    if (l.cornerRadius > 6.0 && v.bounds.size.width > 12.0 && v.bounds.size.width < 80.0) return YES;
    return NO;
}

/// 缁熻瀛愭爲閲?鍍忓浘鐗?鐨勮鍥炬暟閲忥紙鍙湅涓ゅ眰锛屽鐢級
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

/// 閫掑綊鎵惧嚭鎵€鏈夊€欓€夌珫鏍忓苟闅愯棌
static NSInteger HRScan(UIView *root) {
    if (!root || root.hidden || gHRDisabled) return 0;
    NSInteger hidden = 0;

    CGRect f = [root convertRect:root.bounds toView:nil]; // 杞垚绐楀彛鍧愭爣
    BOOL leftFlush   = f.origin.x <= RAIL_LEFT_TOLERANCE;
    BOOL narrow      = f.size.width >= 20.0 && f.size.width <= RAIL_MAX_WIDTH;
    BOOL tall        = f.size.height >= RAIL_MIN_HEIGHT;
    BOOL notFullWide = f.size.width < CGRectGetWidth(root.window.bounds) * 0.45;

    if (leftFlush && narrow && tall && notFullWide) {
        NSInteger imgs = HRCountImages(root);
        if (imgs >= RAIL_MIN_IMAGES) {
            HRLog(@"hide %@ frame=%@ images=%ld", NSStringFromClass([root class]),
                  NSStringFromCGRect(f), (long)imgs);
            root.hidden = YES;
            root.userInteractionEnabled = NO;
            root.alpha = 0.0;
            hidden++;
            return hidden; // 鍛戒腑鍗冲仠锛岄伩鍏嶆妸閲屽眰鐨勫ご鍍忎篃閲嶅澶勭悊
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
        // 璁╁畠褰诲簳涓嶅崰浣嶏細鎶婄埗瀹瑰櫒涔熸爣璁颁竴涓嬶紙鍙拡瀵圭埗瑙嗗浘锛屼笉閫掑綊锛?        HRLog(@"hidden %ld candidate view(s) this pass", (long)total);
    }
}

__attribute__((constructor))
static void HideRailInit(void) {
    HRLog(@"loaded");

    // 涓€浜涚敤鎴峰叧闂柟寮忥細TrollFools 閲屽嵏杞?dylib 鍗崇敓鏁堬紱涔熷彲鍒涘缓绂佺敤鏍囪
    NSString *flag = [NSTemporaryDirectory() stringByAppendingPathComponent:@"hiderail.off"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:flag]) {
        gHRDisabled = YES;
        HRLog(@"disabled by flag file");
        return;
    }

    // 棣栬疆 + 瀹氭椂杞挱鎵弿锛堥〉闈㈠垏鎹?杩涘叆缇よ亰鏃朵細閲嶆柊甯冨眬锛?    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
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

    // 鍓嶅彴鎭㈠鏃跺啀鎵竴娆?    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ HRScanAllWindows(); });
    }];
}
