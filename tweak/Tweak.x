// LiquidGlassBar 1.4.0 — Thanh tab bar kiểu Liquid Glass cho Messenger
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const LGB_DOMAIN = @"com.vn.liquidglassbar";
static NSString *const LGB_PREFS_NOTIFICATION = @"com.vn.liquidglassbar/prefsChanged";

static NSString *LGBLogFilePath(void) {
    static NSString *path = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *base = dirs.firstObject;
        path = base ? [base stringByAppendingPathComponent:@"LiquidGlassBar.log"]
                    : @"/var/mobile/Documents/LiquidGlassBar.log";
    });
    return path;
}

static const NSInteger LGB_BG_TAG = 712001;
static const NSInteger LGB_INDICATOR_TAG = 712002;
static const NSInteger LGB_TINT_COLOR_TAG = 712012;
static const NSInteger LGB_ASSET_TAG = 712013;
static const void *kLGBScrollExtendedKey = &kLGBScrollExtendedKey;
static const void *kLGBItemTapAttachedKey = &kLGBItemTapAttachedKey;

static BOOL pEnabled = YES;
static BOOL pDragEnabled = YES;
static BOOL pHaptics = YES;
static BOOL pRefractBlur = YES;
static BOOL pDebug = YES;
static CGFloat pGlassAlpha = 0.88;
static CGFloat pBlobAlpha = 0.92;
static CGFloat pBlobWidthPct = 104.0;
static CGFloat pBlobHeightPct = 92.0;
static CGFloat pPillHeight = 60.0;
static CGFloat pPillInset = 10.0;
static CGFloat pPillOffsetY = 0.0;
static CGFloat pSpringPct = 60.0;
static CGFloat pStretchPct = 65.0;
static CGFloat pTouchScalePct = 105.0;
static NSString *pSelectedColorHex = @"#0084FF";
static NSString *pUnselectedColorHex = @"#A0A4AB";
static NSString *pGlassTintHex = @"#141418";

// ------------------------------------------------------------------ log
static void LGBLog(NSString *fmt, ...) {
    if (!pDebug) return;
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[LiquidGlassBar] %@", msg);
    @try {
        NSString *line = [NSString stringWithFormat:@"%@ %@\n",
                          [NSDateFormatter localizedStringFromDate:[NSDate date]
                                                         dateStyle:NSDateFormatterNoStyle
                                                         timeStyle:NSDateFormatterMediumStyle],
                          msg];
        NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:LGBLogFilePath()];
        if (!fh) {
            [line writeToFile:LGBLogFilePath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    } @catch (__unused NSException *e) {}
}

// ------------------------------------------------------------------ prefs
static id LGBGetPref(NSString *key, id def) {
    CFPropertyListRef v = CFPreferencesCopyAppValue((__bridge CFStringRef)key,
                                                    (__bridge CFStringRef)LGB_DOMAIN);
    id obj = (__bridge_transfer id)v;
    return obj ?: def;
}

static void LGBDiagWrite(NSString *key, id value) {
    if (value) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                 (__bridge CFPropertyListRef)value,
                                 (__bridge CFStringRef)LGB_DOMAIN);
    } else {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL,
                                 (__bridge CFStringRef)LGB_DOMAIN);
    }
    CFPreferencesAppSynchronize((__bridge CFStringRef)LGB_DOMAIN);
}

static NSString *LGBNowString(void) {
    return [NSDateFormatter localizedStringFromDate:[NSDate date]
                                          dateStyle:NSDateFormatterShortStyle
                                          timeStyle:NSDateFormatterMediumStyle];
}

static void LGBLoadPrefs(void) {
    CFPreferencesAppSynchronize((__bridge CFStringRef)LGB_DOMAIN);

    pEnabled            = [LGBGetPref(@"enabled", @YES) boolValue];
    pDragEnabled        = [LGBGetPref(@"dragEnabled", @YES) boolValue];
    pHaptics            = [LGBGetPref(@"haptics", @YES) boolValue];
    pRefractBlur        = [LGBGetPref(@"refractBlur", @YES) boolValue];
    pDebug              = [LGBGetPref(@"debug", @YES) boolValue];
    pGlassAlpha         = [LGBGetPref(@"glassAlpha", @0.88) doubleValue];
    pBlobAlpha          = [LGBGetPref(@"blobAlpha", @0.92) doubleValue];
    pBlobWidthPct       = [LGBGetPref(@"blobWidthPct", @104.0) doubleValue];
    pBlobHeightPct      = [LGBGetPref(@"blobHeightPct", @92.0) doubleValue];
    pPillHeight         = [LGBGetPref(@"pillHeight", @60.0) doubleValue];
    pPillInset          = [LGBGetPref(@"pillInset", @10.0) doubleValue];
    pPillOffsetY        = [LGBGetPref(@"pillOffsetY", @0.0) doubleValue];
    pSpringPct          = [LGBGetPref(@"springPct", @60.0) doubleValue];
    pStretchPct         = [LGBGetPref(@"stretchPct", @65.0) doubleValue];
    pTouchScalePct      = [LGBGetPref(@"touchScalePct", @105.0) doubleValue];

    if (pBlobWidthPct < 50 || pBlobWidthPct > 150) pBlobWidthPct = 104.0;
    if (pBlobHeightPct < 50 || pBlobHeightPct > 140) pBlobHeightPct = 92.0;
    if (pPillHeight < 44 || pPillHeight > 80) pPillHeight = 60.0;
    if (pPillInset < 0 || pPillInset > 30) pPillInset = 10.0;
    if (pPillOffsetY < -20 || pPillOffsetY > 20) pPillOffsetY = 0.0;
    if (pSpringPct < 0 || pSpringPct > 100) pSpringPct = 60.0;
    if (pStretchPct < 0 || pStretchPct > 100) pStretchPct = 65.0;
    if (pTouchScalePct < 100 || pTouchScalePct > 120) pTouchScalePct = 105.0;

    pSelectedColorHex   = LGBGetPref(@"selectedColorHex", @"#0084FF");
    pUnselectedColorHex = LGBGetPref(@"unselectedColorHex", @"#A0A4AB");
    pGlassTintHex       = LGBGetPref(@"glassTintHex", @"#141418");
    if (![pSelectedColorHex isKindOfClass:[NSString class]]) pSelectedColorHex = @"#0084FF";
    if (![pUnselectedColorHex isKindOfClass:[NSString class]]) pUnselectedColorHex = @"#A0A4AB";
    if (![pGlassTintHex isKindOfClass:[NSString class]]) pGlassTintHex = @"#141418";
}

static UIColor *LGBColorFromHex(NSString *hexStr, UIColor *fallback) {
    if (![hexStr isKindOfClass:[NSString class]] || hexStr.length == 0) return fallback;
    NSString *clean = [[hexStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([clean hasPrefix:@"#"]) clean = [clean substringFromIndex:1];
    if ([clean hasPrefix:@"0X"]) clean = [clean substringFromIndex:2];
    if (clean.length != 6) return fallback;
    unsigned int rgbVal = 0;
    if (![[NSScanner scannerWithString:clean] scanHexInt:&rgbVal]) return fallback;
    return [UIColor colorWithRed:((rgbVal & 0xFF0000) >> 16) / 255.0
                           green:((rgbVal & 0x00FF00) >> 8) / 255.0
                            blue:(rgbVal & 0x0000FF) / 255.0
                           alpha:1.0];
}

static UIColor *LGBSelectedColor(void) {
    return LGBColorFromHex(pSelectedColorHex, [UIColor colorWithRed:0.0 green:0.52 blue:1.0 alpha:1.0]);
}

static UIColor *LGBUnselectedColor(void) {
    return LGBColorFromHex(pUnselectedColorHex, [UIColor colorWithRed:0.63 green:0.64 blue:0.67 alpha:1.0]);
}

static UIColor *LGBGlassTintColor(void) {
    return LGBColorFromHex(pGlassTintHex, [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0]);
}

// ------------------------------------------------------------------ asset kính
static UIImage *LGBGlassImageForSize(CGSize size, BOOL isBlob) {
    CGFloat w = round(size.width * 2.0) / 2.0;
    CGFloat h = round(size.height * 2.0) / 2.0;
    if (w < 10 || h < 10) return nil;
    static NSMutableDictionary<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ cache = [NSMutableDictionary dictionary]; });
    NSString *key = [NSString stringWithFormat:@"%.1fx%.1f_%d", w, h, isBlob ? 1 : 0];
    UIImage *cached = cache[key];
    if (cached) return cached;

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(w, h) format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef c = ctx.CGContext;
        CGRect rect = CGRectMake(0, 0, w, h);
        CGFloat radius = h / 2.0;
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:radius];
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();

        [path addClip];

        CGFloat topAlpha = isBlob ? 0.16 : 0.12;
        CGFloat loc1[] = {0.0, 0.32, 0.72, 1.0};
        CGFloat comp1[] = {
            1, 1, 1, topAlpha,
            1, 1, 1, 0.01,
            1, 1, 1, 0.00,
            1, 1, 1, isBlob ? 0.09 : 0.06
        };
        CGGradientRef g1 = CGGradientCreateWithColorComponents(cs, comp1, loc1, 4);
        CGContextDrawLinearGradient(c, g1, CGPointMake(0, 0), CGPointMake(0, h), 0);
        CGGradientRelease(g1);

        CGContextSaveGState(c);
        CGFloat lineW = isBlob ? 1.1 : 1.0;
        UIBezierPath *rim = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(rect, lineW * 0.5, lineW * 0.5)
                                                       cornerRadius:MAX(1.0, radius - lineW * 0.5)];
        CGContextSetLineWidth(c, lineW);
        CGContextAddPath(c, rim.CGPath);
        CGContextReplacePathWithStrokedPath(c);
        CGContextClip(c);
        CGFloat locRim[] = {0.0, 0.5, 1.0};
        CGFloat compRim[] = {
            1, 1, 1, isBlob ? 0.55 : 0.48,
            1, 1, 1, isBlob ? 0.16 : 0.12,
            1, 1, 1, isBlob ? 0.34 : 0.28
        };
        CGGradientRef gRim = CGGradientCreateWithColorComponents(cs, compRim, locRim, 3);
        CGContextDrawLinearGradient(c, gRim, CGPointMake(0, 0), CGPointMake(0, h), 0);
        CGGradientRelease(gRim);
        CGContextRestoreGState(c);

        CGColorSpaceRelease(cs);
    }];
    if (image) {
        if (cache.count > 24) [cache removeAllObjects];
        cache[key] = image;
    }
    return image;
}

static BOOL LGBLooksLikeBadge(UIView *v) {
    if (!v || v.bounds.size.width <= 0 || v.bounds.size.height <= 0) return NO;
    if (v.bounds.size.width <= 54 && v.bounds.size.height <= 32) {
        UIColor *bg = v.backgroundColor;
        if (!bg && v.layer.backgroundColor) {
            bg = [UIColor colorWithCGColor:v.layer.backgroundColor];
        }
        if (bg) {
            CGFloat r = 0, g = 0, b = 0, a = 0;
            if ([bg getRed:&r green:&g blue:&b alpha:&a] && a >= 0.5) {
                if (r > 0.70 && g < 0.45 && b < 0.45) return YES;
            }
        }
        if ([v isKindOfClass:[UILabel class]]) {
            NSString *txt = [((UILabel *)v).text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (txt.length > 0 && txt.length <= 4) {
                NSCharacterSet *badgeChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789+•"];
                if ([[txt stringByTrimmingCharactersInSet:badgeChars] length] == 0) return YES;
            }
        }
    }
    return NO;
}

// ------------------------------------------------------------------ manager
@interface LGBManager : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UITabBar *tabBar;
@property (nonatomic, weak) UIView *customBar;
@property (nonatomic, strong) NSArray<UIView *> *customItems;
@property (nonatomic, assign) NSInteger customSelectedIndex;
@property (nonatomic, assign) BOOL customInitialDetected;
@property (nonatomic, assign) NSInteger previewIndex;
@property (nonatomic, assign) BOOL dragEngaged;
@property (nonatomic, assign) BOOL isSettling;
@property (nonatomic, assign) CGFloat dragStartX;
@property (nonatomic, assign) CGFloat dragStartY;
@property (nonatomic, assign) CGFloat lastDragX;
@property (nonatomic, assign) CGFloat dragSettledCenterX;
@property (nonatomic, weak) UIView *dragBlob;
@property (nonatomic, strong) NSTimer *scanTimer;
@property (nonatomic, assign) NSInteger scanCount;
@property (nonatomic, copy) NSString *diagState;
@property (nonatomic, assign) BOOL dumpedBottomHierarchy;
@property (nonatomic, copy) NSString *loggedCandidateSignature;
+ (instancetype)shared;
- (void)start;
- (void)writeDiagState:(NSString *)state;
- (void)reloadPrefs;
- (void)styleTabBar:(UITabBar *)bar;
- (void)styleCustomBar:(UIView *)bar items:(NSArray<UIView *> *)items;
- (void)tabBarSelectionChanged:(UITabBar *)bar;
- (void)tabBarSelectionChangedCustom;
- (void)handlePan:(UILongPressGestureRecognizer *)pan;
- (void)handleItemTap:(UITapGestureRecognizer *)tap;
- (void)customItemTapped:(UIControl *)sender;
- (void)scanTick:(NSTimer *)timer;
- (void)clearOpaqueParentsOfBar:(UIView *)bar;
- (void)extendScrollViewsBehindBar:(UIView *)bar;
- (UIView *)pillBackgroundInBar:(UIView *)bar frame:(CGRect)frame belowItems:(NSArray<UIView *> *)items;
- (UIView *)indicatorInBar:(UIView *)bar belowItems:(NSArray<UIView *> *)items;
- (NSInteger)glassInsertIndexInBar:(UIView *)bar items:(NSArray<UIView *> *)items;
- (void)placeGlassViewsInBar:(UIView *)bar belowItems:(NSArray<UIView *> *)items;
- (void)refreshIndicator:(UIView *)ind;
- (CGRect)pillFrameForBar:(UIView *)bar;
- (CGRect)targetFrameForIndex:(NSInteger)idx bar:(UIView *)bar items:(NSArray<UIView *> *)items;
- (CGFloat)springDamping;
- (void)animateIndicatorToIndex:(NSInteger)idx bar:(UIView *)bar items:(NSArray<UIView *> *)items completion:(void (^)(void))completion;
- (void)attachPanToBar:(UIView *)bar;
- (void)attachTapObserversToItems:(NSArray<UIView *> *)items;
- (void)hapticTick;
- (NSArray<UIView *> *)tabBarButtons:(UITabBar *)bar;
- (NSInteger)nearestIndex:(CGFloat)x centers:(NSArray<NSNumber *> *)centers;
- (void)finishDragToIndex:(NSInteger)idx bar:(UIView *)bar isTabBar:(BOOL)isTab;
- (void)selectTabBarIndex:(NSInteger)idx bar:(UITabBar *)bar;
- (void)selectCustomIndex:(NSInteger)idx;
- (NSInteger)detectActiveIndexInItems:(NSArray<UIView *> *)items;
- (void)applyCustomSelectionVisual;
- (void)tintTree:(UIView *)v color:(UIColor *)color selected:(BOOL)selected;
- (UIWindow *)activeWindow;
- (void)appDidBecomeActive:(NSNotification *)note;
- (BOOL)viewLooksLikeTabItem:(UIView *)v;
- (void)dumpBottomHierarchy:(UIWindow *)win;
- (void)dumpView:(UIView *)v window:(UIWindow *)win depth:(NSInteger)depth into:(NSMutableString *)out lines:(NSInteger *)lines;
- (BOOL)subtree:(UIView *)v hasIconOrLabelAtDepth:(NSInteger)depth;
- (void)collectCandidatesInView:(UIView *)v window:(UIWindow *)win depth:(NSInteger)depth best:(UIView **)best bestScore:(NSInteger *)bestScore bestItems:(NSArray<UIView *> **)bestItems;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other;
@end

@implementation LGBManager

+ (instancetype)shared {
    static LGBManager *inst = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [[LGBManager alloc] init]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _customSelectedIndex = 0;
        _previewIndex = -1;
    }
    return self;
}

- (void)writeDiagState:(NSString *)state {
    if (!state || [state isEqualToString:self.diagState]) return;
    self.diagState = state;
    LGBDiagWrite(@"diag_barState", state);
}

- (void)start {
    LGBDiagWrite(@"diag_lastLoadAt", LGBNowString());
    LGBDiagWrite(@"diag_process", [[NSBundle mainBundle] bundleIdentifier] ?: @"?");
    [self writeDiagState:@"Da nap vao Messenger, dang quet thanh bar..."];
    LGBLog(@"Khoi dong 1.4.0 trong process %@ (enabled=%d)", [[NSBundle mainBundle] bundleIdentifier], pEnabled);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(scanTick:)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)reloadPrefs {
    LGBLoadPrefs();
    if (self.tabBar) [self styleTabBar:self.tabBar];
    if (self.customBar) [self styleCustomBar:self.customBar items:self.customItems];
}

- (void)clearOpaqueParentsOfBar:(UIView *)bar {
    if (!bar) return;
    bar.backgroundColor = [UIColor clearColor];
    bar.opaque = NO;
    UIView *p = bar.superview;
    UIWindow *win = bar.window;
    for (NSInteger i = 0; i < 3 && p && p != win; i++) {
        if (p.bounds.size.height <= 140.0) {
            p.backgroundColor = [UIColor clearColor];
            p.opaque = NO;
            for (UIView *sib in p.subviews) {
                if (sib == bar || [bar isDescendantOfView:sib]) continue;
                if (sib.tag == LGB_BG_TAG || sib.tag == LGB_INDICATOR_TAG) continue;
                if (sib.bounds.size.height <= 2.0) {
                    sib.hidden = YES;
                } else if (sib.subviews.count == 0 && sib.bounds.size.height <= 140.0) {
                    sib.backgroundColor = [UIColor clearColor];
                }
            }
        }
        p = p.superview;
    }
}

- (void)extendScrollViewsBehindBar:(UIView *)bar {
    if (!pRefractBlur || !bar || !bar.window) return;
    UIWindow *win = bar.window;
    CGRect barInWin = [bar convertRect:bar.bounds toView:win];
    if (barInWin.size.height < 30) return;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:win];
    while (stack.count > 0) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:[UIScrollView class]]) {
            UIScrollView *sv = (UIScrollView *)v;
            CGRect svInWin = [sv convertRect:sv.bounds toView:win];
            if (svInWin.size.width > win.bounds.size.width * 0.85 &&
                svInWin.size.height > win.bounds.size.height * 0.45) {
                CGFloat gapToBottom = win.bounds.size.height - CGRectGetMaxY(svInWin);
                CGFloat distToBarTop = fabs(CGRectGetMaxY(svInWin) - CGRectGetMinY(barInWin));
                NSNumber *already = objc_getAssociatedObject(sv, kLGBScrollExtendedKey);
                if (!already.boolValue && distToBarTop <= 18.0 && gapToBottom >= 40.0) {
                    objc_setAssociatedObject(sv, kLGBScrollExtendedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    CGRect f = sv.frame;
                    f.size.height += gapToBottom;
                    sv.frame = f;
                    UIEdgeInsets inset = sv.contentInset;
                    inset.bottom += gapToBottom;
                    sv.contentInset = inset;
                    UIEdgeInsets indInset = sv.scrollIndicatorInsets;
                    indInset.bottom += gapToBottom;
                    sv.scrollIndicatorInsets = indInset;
                    LGBLog(@"Da mo rong UIScrollView %@ xuong duoi thanh bar (+%.0fpt)", NSStringFromClass([sv class]), gapToBottom);
                }
            }
        }
        for (UIView *sub in v.subviews) {
            [stack addObject:sub];
        }
    }
}

- (NSInteger)glassInsertIndexInBar:(UIView *)bar items:(NSArray<UIView *> *)items {
    for (UIView *item in items) {
        if (item.superview == bar) return (NSInteger)[bar.subviews indexOfObject:item];
    }
    return 0;
}

- (void)placeGlassViewsInBar:(UIView *)bar belowItems:(NSArray<UIView *> *)items {
    if (!bar || items.count == 0) return;
    UIView *pill = [bar viewWithTag:LGB_BG_TAG];
    UIView *ind = [bar viewWithTag:LGB_INDICATOR_TAG];
    if (pill && pill.superview != bar) pill = nil;
    if (ind && ind.superview != bar) ind = nil;
    if (!pill && !ind) return;
    UIView *firstItem = nil;
    for (UIView *item in items) {
        if (item.superview == bar) { firstItem = item; break; }
    }
    if (!firstItem) return;
    NSInteger firstIdx = (NSInteger)[bar.subviews indexOfObject:firstItem];
    NSInteger pillIdx = pill ? (NSInteger)[bar.subviews indexOfObject:pill] : NSNotFound;
    NSInteger indIdx = ind ? (NSInteger)[bar.subviews indexOfObject:ind] : NSNotFound;
    BOOL pillOK = (pillIdx != NSNotFound && pillIdx < firstIdx && (firstIdx - pillIdx) <= 2);
    BOOL indOK = (!ind || indIdx == pillIdx + 1 || (pillIdx == NSNotFound && indIdx == firstIdx - 1));
    if (pillOK && indOK) return;
    if (pill) [pill removeFromSuperview];
    if (ind) [ind removeFromSuperview];
    firstIdx = (NSInteger)[bar.subviews indexOfObject:firstItem];
    if (pill) [bar insertSubview:pill atIndex:firstIdx];
    if (ind) [bar insertSubview:ind atIndex:firstIdx + (pill ? 1 : 0)];
}

- (CGRect)pillFrameForBar:(UIView *)bar {
    CGFloat barW = bar.bounds.size.width;
    CGFloat barH = bar.bounds.size.height;
    CGFloat safeBottom = 0;
    UIWindow *win = bar.window;
    if (win && CGRectGetMaxY([bar convertRect:bar.bounds toView:win]) >= win.bounds.size.height - 2.0) {
        safeBottom = win.safeAreaInsets.bottom;
    }

    CGFloat pillH = MIN(MAX(pPillHeight, 46.0), MAX(46.0, barH - 4.0));
    CGFloat pillY = 0;
    if (safeBottom > 0) {
        CGFloat bottomMargin = MAX(10.0, safeBottom - 18.0);
        pillY = MAX(2.0, barH - bottomMargin - pillH);
    } else {
        pillY = MAX(2.0, (barH - pillH) / 2.0);
    }
    pillY = MIN(MAX(pillY + pPillOffsetY, 0.0), MAX(0.0, barH - pillH));

    CGFloat inset = MIN(MAX(pPillInset, 0.0), barW / 4.0);
    return CGRectMake(inset, pillY, barW - inset * 2.0, pillH);
}

- (UIView *)pillBackgroundInBar:(UIView *)bar frame:(CGRect)frame belowItems:(NSArray<UIView *> *)items {
    UIView *existing = [bar viewWithTag:LGB_BG_TAG];
    if (existing) {
        existing.frame = frame;
        UIVisualEffectView *fx = nil;
        for (UIView *sub in existing.subviews) {
            if ([sub isKindOfClass:[UIVisualEffectView class]]) { fx = (UIVisualEffectView *)sub; break; }
        }
        if (fx) {
            fx.frame = existing.bounds;
            fx.layer.cornerRadius = frame.size.height / 2.0;
            for (UIView *sub in fx.contentView.subviews) {
                sub.backgroundColor = [LGBGlassTintColor() colorWithAlphaComponent:0.24];
                sub.frame = fx.bounds;
            }
            fx.alpha = pGlassAlpha;
        }
        UIImageView *asset = (UIImageView *)[existing viewWithTag:LGB_ASSET_TAG];
        if (asset) {
            asset.frame = existing.bounds;
            asset.image = LGBGlassImageForSize(existing.bounds.size, NO);
            asset.alpha = pGlassAlpha;
        }
        existing.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:existing.bounds
                                                               cornerRadius:frame.size.height / 2.0].CGPath;
        [self placeGlassViewsInBar:bar belowItems:items];
        return existing;
    }

    UIView *holder = [[UIView alloc] initWithFrame:frame];
    holder.tag = LGB_BG_TAG;
    holder.userInteractionEnabled = NO;
    holder.backgroundColor = [UIColor clearColor];
    holder.layer.shadowColor = [UIColor blackColor].CGColor;
    holder.layer.shadowOpacity = 0.35;
    holder.layer.shadowRadius = 12.0;
    holder.layer.shadowOffset = CGSizeMake(0, 4);
    holder.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:holder.bounds
                                                         cornerRadius:frame.size.height / 2.0].CGPath;

    UIVisualEffectView *fx = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    fx.frame = holder.bounds;
    fx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    fx.layer.cornerRadius = frame.size.height / 2.0;
    fx.layer.masksToBounds = YES;
    fx.alpha = pGlassAlpha;

    UIView *tint = [[UIView alloc] initWithFrame:fx.bounds];
    tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tint.backgroundColor = [LGBGlassTintColor() colorWithAlphaComponent:0.24];
    tint.userInteractionEnabled = NO;
    [fx.contentView addSubview:tint];
    [holder addSubview:fx];

    UIImageView *asset = [[UIImageView alloc] initWithFrame:holder.bounds];
    asset.tag = LGB_ASSET_TAG;
    asset.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    asset.image = LGBGlassImageForSize(holder.bounds.size, NO);
    asset.alpha = pGlassAlpha;
    asset.userInteractionEnabled = NO;
    [holder addSubview:asset];

    NSInteger idx = [self glassInsertIndexInBar:bar items:items];
    [bar insertSubview:holder atIndex:idx];
    return holder;
}

- (void)refreshIndicator:(UIView *)ind {
    if (!ind) return;
    ind.backgroundColor = [UIColor clearColor];
    CGFloat h = ind.bounds.size.height;
    ind.layer.shadowColor = [UIColor blackColor].CGColor;
    ind.layer.shadowOpacity = 0.25;
    ind.layer.shadowRadius = 8.0;
    ind.layer.shadowOffset = CGSizeMake(0, 2);
    if (ind.bounds.size.width > 0 && h > 0) {
        ind.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:ind.bounds
                                                          cornerRadius:h / 2.0].CGPath;
    }
    for (UIView *sub in ind.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *fx = (UIVisualEffectView *)sub;
            fx.frame = ind.bounds;
            fx.layer.cornerRadius = h / 2.0;
            fx.alpha = pBlobAlpha;
            for (UIView *s2 in fx.contentView.subviews) {
                if (s2.tag == LGB_TINT_COLOR_TAG) {
                    s2.frame = fx.bounds;
                    s2.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
                }
            }
        } else if (sub.tag == LGB_ASSET_TAG) {
            sub.frame = ind.bounds;
            ((UIImageView *)sub).image = LGBGlassImageForSize(ind.bounds.size, YES);
            sub.alpha = pBlobAlpha;
        }
    }
}

- (UIView *)indicatorInBar:(UIView *)bar belowItems:(NSArray<UIView *> *)items {
    UIView *ind = [bar viewWithTag:LGB_INDICATOR_TAG];
    if (ind) {
        if (!self.dragEngaged && !self.isSettling) {
            [self placeGlassViewsInBar:bar belowItems:items];
        }
        return ind;
    }
    ind = [[UIView alloc] initWithFrame:CGRectZero];
    ind.tag = LGB_INDICATOR_TAG;
    ind.userInteractionEnabled = NO;
    ind.backgroundColor = [UIColor clearColor];

    UIVisualEffectView *fx = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    fx.frame = ind.bounds;
    fx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    fx.layer.masksToBounds = YES;
    fx.alpha = pBlobAlpha;

    UIView *colorTint = [[UIView alloc] initWithFrame:fx.bounds];
    colorTint.tag = LGB_TINT_COLOR_TAG;
    colorTint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    colorTint.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    colorTint.userInteractionEnabled = NO;
    [fx.contentView addSubview:colorTint];
    [ind addSubview:fx];

    UIImageView *asset = [[UIImageView alloc] initWithFrame:ind.bounds];
    asset.tag = LGB_ASSET_TAG;
    asset.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    asset.alpha = pBlobAlpha;
    asset.userInteractionEnabled = NO;
    [ind addSubview:asset];

    NSInteger idx = [self glassInsertIndexInBar:bar items:items];
    [bar insertSubview:ind atIndex:idx];
    [self placeGlassViewsInBar:bar belowItems:items];
    return ind;
}

- (CGRect)targetFrameForIndex:(NSInteger)idx bar:(UIView *)bar items:(NSArray<UIView *> *)items {
    CGRect pill = [self pillFrameForBar:bar];
    UIView *item = items[idx];

    CGFloat slotW = (items.count > 0) ? (pill.size.width / items.count) : item.bounds.size.width;
    CGFloat baseW = MIN(item.bounds.size.width, slotW);
    if (baseW < 36.0) baseW = slotW;

    CGFloat w = baseW * (pBlobWidthPct / 100.0);
    CGFloat h = (pill.size.height - 6.0) * (pBlobHeightPct / 100.0);

    w = MIN(MAX(w, 46.0), MAX(46.0, pill.size.width - 6.0));
    h = MIN(MAX(h, 42.0), MAX(42.0, pill.size.height - 4.0));

    CGFloat cx = CGRectGetMidX(item.frame);
    CGFloat minCx = CGRectGetMinX(pill) + w / 2.0 + 3.0;
    CGFloat maxCx = CGRectGetMaxX(pill) - w / 2.0 - 3.0;
    cx = (maxCx >= minCx) ? MIN(MAX(cx, minCx), maxCx) : CGRectGetMidX(pill);

    CGRect contentV = item.frame;
    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:item];
    while (stack.count > 0) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if (v != item) {
            if (LGBLooksLikeBadge(v)) continue;
            if ([v isKindOfClass:[UILabel class]] ||
                ([v isKindOfClass:[UIImageView class]] && v.bounds.size.width >= 16 && v.bounds.size.height >= 16)) {
                contentV = CGRectUnion(contentV, [v convertRect:v.bounds toView:bar]);
            }
        }
        for (UIView *sub in v.subviews) {
            if (sub.tag != LGB_BG_TAG && sub.tag != LGB_INDICATOR_TAG) [stack addObject:sub];
        }
    }
    for (UIView *sub in bar.subviews) {
        if (![sub isKindOfClass:[UILabel class]] || [sub isDescendantOfView:item] || LGBLooksLikeBadge(sub)) continue;
        CGFloat lcx = CGRectGetMidX(sub.frame);
        if (fabs(lcx - cx) <= slotW * 0.45 && CGRectGetMinY(sub.frame) >= CGRectGetMinY(item.frame)) {
            contentV = CGRectUnion(contentV, sub.frame);
        }
    }

    CGFloat cy = CGRectGetMidY(pill);
    CGFloat contentMidY = CGRectGetMidY(contentV);
    if (fabs(contentMidY - cy) <= 8.0) {
        cy = (cy + contentMidY) * 0.5;
    }
    CGFloat minCy = CGRectGetMinY(pill) + h / 2.0 + 2.0;
    CGFloat maxCy = CGRectGetMaxY(pill) - h / 2.0 - 2.0;
    cy = (maxCy >= minCy) ? MIN(MAX(cy, minCy), maxCy) : CGRectGetMidY(pill);

    return CGRectMake(cx - w / 2.0, cy - h / 2.0, w, h);
}

- (CGFloat)springDamping {
    return 1.0 - 0.52 * (pSpringPct / 100.0);
}

- (void)animateIndicatorToIndex:(NSInteger)idx bar:(UIView *)bar items:(NSArray<UIView *> *)items completion:(void (^)(void))completion {
    UIView *ind = [self indicatorInBar:bar belowItems:items];
    CGRect target = [self targetFrameForIndex:idx bar:bar items:items];
    CGFloat dx = CGRectGetMidX(target) - CGRectGetMidX(ind.frame);
    if (fabs(dx) < 0.5 && CGAffineTransformIsIdentity(ind.transform)) {
        ind.frame = target;
        [self refreshIndicator:ind];
        self.isSettling = NO;
        if (completion) completion();
        return;
    }
    self.isSettling = YES;
    [UIView animateWithDuration:0.38 delay:0
         usingSpringWithDamping:[self springDamping] initialSpringVelocity:0.6
                        options:(UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         ind.transform = CGAffineTransformMakeTranslation(dx, 0);
                     }
                     completion:^(__unused BOOL finished) {
                         ind.transform = CGAffineTransformIdentity;
                         ind.frame = target;
                         [self refreshIndicator:ind];
                         self.isSettling = NO;
                         if (completion) completion();
                     }];
}

- (void)attachPanToBar:(UIView *)bar {
    if (!pDragEnabled) return;
    for (UIGestureRecognizer *gr in bar.gestureRecognizers) {
        if ([gr isKindOfClass:[UILongPressGestureRecognizer class]] && gr.delegate == self) return;
    }
    UILongPressGestureRecognizer *pan = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    pan.minimumPressDuration = 0;
    pan.allowableMovement = CGFLOAT_MAX;
    pan.cancelsTouchesInView = NO;
    [bar addGestureRecognizer:pan];
    LGBLog(@"Da gan cu chi keo truot len bar class %@", NSStringFromClass([bar class]));
}

- (void)attachTapObserversToItems:(NSArray<UIView *> *)items {
    for (UIView *item in items) {
        NSNumber *attached = objc_getAssociatedObject(item, kLGBItemTapAttachedKey);
        if (attached.boolValue) continue;
        objc_setAssociatedObject(item, kLGBItemTapAttachedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleItemTap:)];
        tap.delegate = self;
        tap.cancelsTouchesInView = NO;
        [item addGestureRecognizer:tap];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gr shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    (void)gr; (void)other;
    return YES;
}

- (void)hapticTick {
    if (!pHaptics) return;
    UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [gen prepare];
    [gen impactOccurred];
}

// ---------------------------------------------------------- đường A: UITabBar
- (NSArray<UIView *> *)tabBarButtons:(UITabBar *)bar {
    NSMutableArray<UIView *> *out = [NSMutableArray array];
    for (UIView *sub in bar.subviews) {
        if ([NSStringFromClass([sub class]) isEqualToString:@"UITabBarButton"]) [out addObject:sub];
    }
    [out sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    return out;
}

- (void)styleTabBar:(UITabBar *)bar {
    if (!pEnabled || bar.bounds.size.width < 50) return;
    self.tabBar = bar;
    [self clearOpaqueParentsOfBar:bar];
    [self extendScrollViewsBehindBar:bar];

    bar.backgroundImage = [[UIImage alloc] init];
    bar.shadowImage = [[UIImage alloc] init];
    bar.backgroundColor = [UIColor clearColor];
    bar.translucent = YES;
    bar.tintColor = LGBSelectedColor();
    if (@available(iOS 10.0, *)) {
        bar.unselectedItemTintColor = LGBUnselectedColor();
    }

    CGRect pillFrame = [self pillFrameForBar:bar];
    NSArray<UIView *> *buttons = [self tabBarButtons:bar];
    [self pillBackgroundInBar:bar frame:pillFrame belowItems:buttons];

    if (buttons.count == 0 || bar.items.count == 0) return;
    NSInteger sel = bar.selectedItem ? (NSInteger)[bar.items indexOfObject:bar.selectedItem] : 0;
    if (sel == NSNotFound) sel = 0;
    if (sel >= (NSInteger)buttons.count) sel = (NSInteger)buttons.count - 1;

    UIView *ind = [self indicatorInBar:bar belowItems:buttons];
    if (!self.dragEngaged && !self.isSettling) {
        ind.transform = CGAffineTransformIdentity;
        ind.frame = [self targetFrameForIndex:sel bar:bar items:buttons];
    }
    [self refreshIndicator:ind];
    [self attachPanToBar:bar];
    [self writeDiagState:[NSString stringWithFormat:@"Da thay UITabBar chuan (%lu muc) — da ap kinh",
                          (unsigned long)bar.items.count]];
}

- (void)tabBarSelectionChanged:(UITabBar *)bar {
    if (self.dragEngaged || self.isSettling) return;
    NSArray<UIView *> *buttons = [self tabBarButtons:bar];
    if (buttons.count == 0 || bar.items.count == 0 || !bar.selectedItem) return;
    NSInteger sel = (NSInteger)[bar.items indexOfObject:bar.selectedItem];
    if (sel == NSNotFound || sel >= (NSInteger)buttons.count) return;
    [self animateIndicatorToIndex:sel bar:bar items:buttons completion:nil];
}

- (void)selectTabBarIndex:(NSInteger)idx bar:(UITabBar *)bar {
    if (idx < 0 || idx >= (NSInteger)bar.items.count) return;
    UITabBarItem *item = bar.items[idx];
    id delegate = bar.delegate;
    if ([delegate isKindOfClass:[UITabBarController class]]) {
        ((UITabBarController *)delegate).selectedIndex = idx;
    } else {
        bar.selectedItem = item;
        if ([delegate respondsToSelector:@selector(tabBar:didSelectItem:)]) {
            [delegate tabBar:bar didSelectItem:item];
        }
    }
}

// ---------------------------------------------------------- đường B: bar tự chế (Messenger)
- (NSInteger)detectActiveIndexInItems:(NSArray<UIView *> *)items {
    NSInteger bestIdx = 0;
    CGFloat bestBlueScore = -1.0;
    for (NSInteger i = 0; i < (NSInteger)items.count; i++) {
        UIView *item = items[i];
        if ([item isKindOfClass:[UIControl class]] && ((UIControl *)item).isSelected) {
            return i;
        }
        NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:item];
        while (stack.count > 0) {
            UIView *v = stack.lastObject;
            [stack removeLastObject];
            if (LGBLooksLikeBadge(v)) continue;
            UIColor *c = nil;
            if ([v isKindOfClass:[UILabel class]]) c = ((UILabel *)v).textColor;
            else if ([v isKindOfClass:[UIImageView class]]) c = v.tintColor;
            if (c) {
                CGFloat r = 0, g = 0, b = 0, a = 0;
                if ([c getRed:&r green:&g blue:&b alpha:&a] && a > 0.5) {
                    CGFloat blueScore = b - (r * 0.5);
                    if (blueScore > bestBlueScore) {
                        bestBlueScore = blueScore;
                        bestIdx = i;
                    }
                }
            }
            for (UIView *sub in v.subviews) [stack addObject:sub];
        }
    }
    return bestIdx;
}

- (void)tintTree:(UIView *)v color:(UIColor *)color selected:(BOOL)selected {
    (void)selected;
    if (v.tag == LGB_BG_TAG || v.tag == LGB_INDICATOR_TAG) return;
    if (LGBLooksLikeBadge(v)) return;
    if ([v isKindOfClass:[UIImageView class]]) {
        v.tintColor = color;
        UIImage *img = ((UIImageView *)v).image;
        if (img && img.renderingMode == UIImageRenderingModeAlwaysOriginal) {
            ((UIImageView *)v).image = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
    } else if ([v isKindOfClass:[UILabel class]]) {
        UILabel *lab = (UILabel *)v;
        UIColor *bg = lab.backgroundColor;
        CGFloat rr = 0, gg = 0, bb = 0, aa = 0;
        BOOL hasBg = bg && [bg getRed:&rr green:&gg blue:&bb alpha:&aa] && aa >= 0.5;
        if (!hasBg) {
            lab.textColor = color;
        }
    }
    for (UIView *sub in v.subviews) [self tintTree:sub color:color selected:selected];
}

- (void)applyCustomSelectionVisual {
    if (!self.customBar || !self.customItems) return;
    UIColor *sel = LGBSelectedColor();
    UIColor *unsel = LGBUnselectedColor();
    NSInteger active = (self.previewIndex >= 0) ? self.previewIndex : self.customSelectedIndex;
    for (NSInteger i = 0; i < (NSInteger)self.customItems.count; i++) {
        [self tintTree:self.customItems[i] color:(i == active ? sel : unsel) selected:(i == active)];
    }
    UIView *ind = [self indicatorInBar:self.customBar belowItems:self.customItems];
    [self refreshIndicator:ind];
}

- (void)styleCustomBar:(UIView *)bar items:(NSArray<UIView *> *)items {
    if (!pEnabled || !bar || items.count < 2) return;
    BOOL isNewBar = (self.customBar != bar);
    self.customBar = bar;
    self.customItems = items;

    if (isNewBar || !self.customInitialDetected) {
        self.customInitialDetected = YES;
        self.customSelectedIndex = [self detectActiveIndexInItems:items];
    }
    if (self.customSelectedIndex >= (NSInteger)items.count) self.customSelectedIndex = 0;

    [self clearOpaqueParentsOfBar:bar];
    [self extendScrollViewsBehindBar:bar];

    CGRect pillFrame = [self pillFrameForBar:bar];
    [self pillBackgroundInBar:bar frame:pillFrame belowItems:items];

    UIView *ind = [self indicatorInBar:bar belowItems:items];
    if (!self.dragEngaged && !self.isSettling) {
        ind.transform = CGAffineTransformIdentity;
        ind.frame = [self targetFrameForIndex:self.customSelectedIndex bar:bar items:items];
    }
    [self refreshIndicator:ind];
    [self applyCustomSelectionVisual];
    [self attachPanToBar:bar];
    [self attachTapObserversToItems:items];

    if (isNewBar) {
        for (UIView *item in items) {
            NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:item];
            while (stack.count > 0) {
                UIView *v = stack.lastObject;
                [stack removeLastObject];
                if ([v isKindOfClass:[UIControl class]]) {
                    [(UIControl *)v addTarget:self action:@selector(customItemTapped:) forControlEvents:UIControlEventTouchUpInside];
                }
                for (UIView *sub in v.subviews) [stack addObject:sub];
            }
        }
        NSMutableString *sig = [NSMutableString stringWithString:NSStringFromClass([bar class])];
        for (UIView *item in items) [sig appendFormat:@"|%@", NSStringFromClass([item class])];
        if (![sig isEqualToString:self.loggedCandidateSignature]) {
            self.loggedCandidateSignature = sig;
            LGBLog(@"Da ap kinh len bar tu che: %@ (frame %@, %lu muc)",
                   sig, NSStringFromCGRect(bar.frame), (unsigned long)items.count);
        }
        [self writeDiagState:[NSString stringWithFormat:@"Da thay bar tu che %@ (%lu muc) — da ap kinh",
                              NSStringFromClass([bar class]), (unsigned long)items.count]];
    }
}

- (void)handleItemTap:(UITapGestureRecognizer *)tap {
    if (!pEnabled || self.dragEngaged || !self.customBar || !self.customItems) return;
    UIView *tapped = tap.view;
    NSInteger idx = [self.customItems indexOfObject:tapped];
    if (idx != NSNotFound && idx != self.customSelectedIndex) {
        self.customSelectedIndex = idx;
        [self tabBarSelectionChangedCustom];
    }
}

- (void)customItemTapped:(UIControl *)sender {
    if (!self.customBar || !self.customItems || self.dragEngaged) return;
    for (NSInteger i = 0; i < (NSInteger)self.customItems.count; i++) {
        UIView *item = self.customItems[i];
        if (sender == (UIControl *)item || [sender isDescendantOfView:item] || [item isDescendantOfView:sender]) {
            if (self.customSelectedIndex != i) {
                self.customSelectedIndex = i;
                [self tabBarSelectionChangedCustom];
            }
            return;
        }
    }
}

- (void)selectCustomIndex:(NSInteger)idx {
    if (!self.customBar || idx < 0 || idx >= (NSInteger)self.customItems.count) return;
    self.customSelectedIndex = idx;
    [self applyCustomSelectionVisual];

    UIView *item = self.customItems[idx];
    BOOL triggered = NO;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:item];
    while (stack.count > 0) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if ([v isKindOfClass:[UIControl class]]) {
            UIControl *ctrl = (UIControl *)v;
            [ctrl sendActionsForControlEvents:UIControlEventTouchDown];
            [ctrl sendActionsForControlEvents:UIControlEventTouchUpInside];
            triggered = YES;
        }
        for (UIView *sub in v.subviews) [stack addObject:sub];
    }

    if (!triggered) {
        [stack addObject:item];
        while (stack.count > 0) {
            UIView *v = stack.lastObject;
            [stack removeLastObject];
            for (UIGestureRecognizer *gr in v.gestureRecognizers) {
                if (![gr isKindOfClass:[UITapGestureRecognizer class]]) continue;
                if (gr.delegate == self) continue;
                @try {
                    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
                    if (targetsIvar) {
                        NSArray *targets = object_getIvar(gr, targetsIvar);
                        for (id pair in targets) {
                            Ivar tIvar = class_getInstanceVariable([pair class], "_target");
                            Ivar aIvar = class_getInstanceVariable([pair class], "_action");
                            if (tIvar && aIvar) {
                                id target = object_getIvar(pair, tIvar);
                                ptrdiff_t offset = ivar_getOffset(aIvar);
                                SEL action = *(SEL *)((uint8_t *)(__bridge void *)pair + offset);
                                if (target && action && [target respondsToSelector:action]) {
                                    ((void (*)(id, SEL, id))objc_msgSend)(target, action, gr);
                                    triggered = YES;
                                }
                            }
                        }
                    }
                } @catch (__unused NSException *e) {}
            }
            for (UIView *sub in v.subviews) [stack addObject:sub];
        }
    }
    LGBLog(@"Chon muc tu che thu %ld (triggered=%d)", (long)idx, triggered);
}

// ---------------------------------------------------------- kéo trượt
- (void)tabBarSelectionChangedCustom {
    if (!self.customBar || !self.customItems || self.dragEngaged) return;
    [self animateIndicatorToIndex:self.customSelectedIndex bar:self.customBar items:self.customItems completion:nil];
    [self applyCustomSelectionVisual];
}

- (NSInteger)nearestIndex:(CGFloat)x centers:(NSArray<NSNumber *> *)centers {
    NSInteger best = 0;
    CGFloat bestDist = CGFLOAT_MAX;
    for (NSInteger i = 0; i < (NSInteger)centers.count; i++) {
        CGFloat d = fabs(x - centers[i].doubleValue);
        if (d < bestDist) { bestDist = d; best = i; }
    }
    return best;
}

- (void)handlePan:(UILongPressGestureRecognizer *)pan {
    if (!pEnabled || !pDragEnabled) return;
    UIView *bar = pan.view;
    if (!bar) return;
    BOOL isTab = [bar isKindOfClass:[UITabBar class]];
    NSArray<UIView *> *items = nil;
    if (isTab) items = [self tabBarButtons:(UITabBar *)bar];
    else if (bar == self.customBar) items = self.customItems;
    if (!items || items.count < 2) return;

    NSMutableArray<NSNumber *> *centers = [NSMutableArray array];
    for (UIView *it in items) [centers addObject:@(CGRectGetMidX(it.frame))];
    CGPoint pt = [pan locationInView:bar];
    CGFloat x = pt.x;
    CGFloat y = pt.y;
    CGFloat minX = centers.firstObject.doubleValue;
    CGFloat maxX = centers.lastObject.doubleValue;
    CGFloat clampedX = MIN(MAX(x, minX), maxX);
    NSInteger nearIdx = [self nearestIndex:clampedX centers:centers];

    UIView *ind = [self indicatorInBar:bar belowItems:items];
    CGRect pill = [self pillFrameForBar:bar];

    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            self.dragEngaged = NO;
            self.dragBlob = nil;
            self.dragStartX = x;
            self.dragStartY = y;
            self.lastDragX = x;
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.dragEngaged) {
                CGFloat totalDx = fabs(x - self.dragStartX);
                CGFloat totalDy = fabs(y - self.dragStartY);
                if (totalDx < 5.0 || totalDx < totalDy * 0.8) return;
                if (ind.frame.size.width < 10) return;

                self.isSettling = NO;
                [ind.layer removeAllAnimations];
                ind.transform = CGAffineTransformIdentity;

                self.dragEngaged = YES;
                self.previewIndex = nearIdx;
                self.dragBlob = ind;
                self.dragSettledCenterX = CGRectGetMidX(ind.frame);
                [self hapticTick];
                if (!isTab) [self applyCustomSelectionVisual];
            }

            UIView *blob = self.dragBlob ?: ind;
            CGFloat tx = clampedX - self.dragSettledCenterX;
            CGFloat txMin = CGRectGetMinX(pill) + 3.0 - CGRectGetMinX(blob.frame);
            CGFloat txMax = CGRectGetMaxX(pill) - 3.0 - CGRectGetMaxX(blob.frame);
            tx = MIN(MAX(tx, txMin), txMax);

            CGFloat dx = x - self.lastDragX;
            self.lastDragX = x;
            CGFloat baseScale = pTouchScalePct / 100.0;
            CGFloat maxStretch = 0.28 * (pStretchPct / 100.0);
            CGFloat stretch = (maxStretch > 0.001)
                ? MIN(maxStretch, fabs(dx) / 100.0 * (maxStretch / 0.18)) : 0;
            CGFloat sx = baseScale * (1.0 + stretch);
            CGFloat sy = baseScale / (1.0 + stretch * 0.50);

            CGAffineTransform tr = CGAffineTransformMakeTranslation(tx, 0);
            tr = CGAffineTransformScale(tr, sx, sy);
            blob.transform = tr;

            if (nearIdx != self.previewIndex) {
                self.previewIndex = nearIdx;
                [self hapticTick];
                if (!isTab) [self applyCustomSelectionVisual];
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (!self.dragEngaged) return;
            NSInteger target = nearIdx;
            self.dragEngaged = NO;
            self.dragBlob = nil;
            self.previewIndex = -1;
            [self finishDragToIndex:target bar:bar isTabBar:isTab];
            break;
        }
        default:
            break;
    }
}

- (void)finishDragToIndex:(NSInteger)idx bar:(UIView *)bar isTabBar:(BOOL)isTab {
    NSArray<UIView *> *items = isTab ? [self tabBarButtons:(UITabBar *)bar] : self.customItems;
    if (!items || idx < 0 || idx >= (NSInteger)items.count) return;
    if (isTab) [self selectTabBarIndex:idx bar:(UITabBar *)bar];
    else [self selectCustomIndex:idx];
    [self animateIndicatorToIndex:idx bar:bar items:items completion:nil];
}

// ---------------------------------------------------------- quét bar tự chế
- (void)appDidBecomeActive:(NSNotification *)note {
    (void)note;
    [self reloadPrefs];
    [self scanTick:nil];
}

- (UIWindow *)activeWindow {
    UIApplication *app = [UIApplication sharedApplication];
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
        }
        if (ws.windows.count > 0) return ws.windows.firstObject;
    }
    return nil;
}

- (void)dumpBottomHierarchy:(UIWindow *)win {
    if (self.dumpedBottomHierarchy || !win) return;
    self.dumpedBottomHierarchy = YES;
    NSMutableString *out = [NSMutableString stringWithString:@"--- Cay view vung day (chan doan bar tu che) ---\n"];
    NSInteger lines = 0;
    [self dumpView:win window:win depth:0 into:out lines:&lines];
    LGBLog(@"%@", out);
}

- (void)dumpView:(UIView *)v window:(UIWindow *)win depth:(NSInteger)depth into:(NSMutableString *)out lines:(NSInteger *)lines {
    if (*lines > 220) return;
    CGRect inWin = [v convertRect:v.bounds toView:win];
    if (CGRectGetMaxY(inWin) > win.bounds.size.height * 0.62 && v.bounds.size.width > 24) {
        (*lines)++;
        NSMutableString *pad = [NSMutableString string];
        for (NSInteger i = 0; i < depth; i++) [pad appendString:@"  "];
        [out appendFormat:@"%@%@ %@\n", pad, NSStringFromClass([v class]), NSStringFromCGRect(v.frame)];
    }
    if (depth < 14) {
        for (UIView *sub in v.subviews) {
            [self dumpView:sub window:win depth:depth + 1 into:out lines:lines];
        }
    }
}

- (BOOL)subtree:(UIView *)v hasIconOrLabelAtDepth:(NSInteger)depth {
    if ([v isKindOfClass:[UIImageView class]] || [v isKindOfClass:[UILabel class]]) return YES;
    if (depth >= 4) return NO;
    for (UIView *sub in v.subviews) {
        if ([self subtree:sub hasIconOrLabelAtDepth:depth + 1]) return YES;
    }
    return NO;
}

- (BOOL)viewLooksLikeTabItem:(UIView *)v {
    if ([v isKindOfClass:[UIControl class]]) return YES;
    if (v.gestureRecognizers.count > 0) return YES;
    return [self subtree:v hasIconOrLabelAtDepth:0];
}

- (void)collectCandidatesInView:(UIView *)v window:(UIWindow *)win depth:(NSInteger)depth
                           best:(UIView **)best bestScore:(NSInteger *)bestScore
                      bestItems:(NSArray<UIView *> **)bestItems {
    if (!v || depth > 14 || v.tag == LGB_BG_TAG || v.tag == LGB_INDICATOR_TAG) return;
    if ([v isKindOfClass:[UITabBar class]]) return;
    CGRect inWin = [v convertRect:v.bounds toView:win];
    CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
    BOOL inBottom = CGRectGetMaxY(inWin) > win.bounds.size.height - 150.0;
    BOOL sizeOK = (h >= 40 && h <= 115 && w > win.bounds.size.width * 0.6);
    NSInteger rawCount = 0;
    for (UIView *sub in v.subviews) {
        if (sub.tag != LGB_BG_TAG && sub.tag != LGB_INDICATOR_TAG) rawCount++;
    }
    if (inBottom && sizeOK && rawCount >= 3 && rawCount <= 8) {
        NSMutableArray<UIView *> *items = [NSMutableArray array];
        for (UIView *sub in v.subviews) {
            if (sub.tag == LGB_BG_TAG || sub.tag == LGB_INDICATOR_TAG) continue;
            if (sub.bounds.size.width < 26 || sub.bounds.size.height < 20) continue;
            if (![self viewLooksLikeTabItem:sub]) continue;
            [items addObject:sub];
        }
        if (items.count >= 3 && items.count <= 7) {
            [items sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];
            NSInteger score = 10;
            CGFloat firstW = items.firstObject.bounds.size.width;
            BOOL even = YES;
            for (UIView *it in items) {
                if (fabs(it.bounds.size.width - firstW) > firstW * 0.6 + 12) even = NO;
            }
            if (even) score += 5;
            if ([v isKindOfClass:[UIControl class]]) score -= 4;
            if (score > *bestScore) {
                *bestScore = score;
                *best = v;
                *bestItems = [items copy];
            }
        }
    }
    for (UIView *sub in v.subviews) {
        [self collectCandidatesInView:sub window:win depth:depth + 1 best:best bestScore:bestScore bestItems:bestItems];
    }
}

- (void)scanTick:(NSTimer *)timer {
    (void)timer;
    LGBLoadPrefs();
    if (!pEnabled) return;
    self.scanCount++;
    if (self.scanCount % 10 == 1) {
        LGBDiagWrite(@"diag_scanCount", @(self.scanCount));
        if (!self.tabBar && !self.customBar) {
            [self writeDiagState:[NSString stringWithFormat:@"Da nap nhung CHUA thay thanh bar nao (da quet %ld lan)",
                                  (long)self.scanCount]];
        }
    }
    if (self.tabBar && self.tabBar.window) {
        if (!self.dragEngaged && !self.isSettling) [self styleTabBar:self.tabBar];
        return;
    }
    if (self.customBar && self.customBar.window) {
        if (!self.dragEngaged && !self.isSettling) {
            [self styleCustomBar:self.customBar items:self.customItems];
        }
        return;
    }
    UIWindow *win = [self activeWindow];
    if (!win) return;
    [self dumpBottomHierarchy:win];
    UIView *best = nil;
    NSInteger bestScore = -1;
    NSArray<UIView *> *bestItems = nil;
    [self collectCandidatesInView:win window:win depth:0 best:&best bestScore:&bestScore bestItems:&bestItems];
    if (best && bestItems) {
        [self styleCustomBar:best items:bestItems];
    }
}

@end

// ------------------------------------------------------------------ hooks
%hook UITabBar
- (void)layoutSubviews {
    %orig;
    [[LGBManager shared] styleTabBar:self];
}
- (void)setSelectedItem:(UITabBarItem *)item {
    %orig;
    [[LGBManager shared] tabBarSelectionChanged:self];
}
%end

// ------------------------------------------------------------------ ctor
static void LGBPrefsChanged(CFNotificationCenterRef center, void *observer,
                            CFStringRef name, const void *object,
                            CFDictionaryRef userInfo) {
    (void)center; (void)observer; (void)name; (void)object; (void)userInfo;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[LGBManager shared] reloadPrefs];
    });
}

%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (![bid isEqualToString:@"com.facebook.Messenger"]) return;
        LGBLoadPrefs();
        [[LGBManager shared] start];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
            LGBPrefsChanged, (__bridge CFStringRef)LGB_PREFS_NOTIFICATION, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
