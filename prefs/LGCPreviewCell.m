#import "LGCPreviewCell.h"
#import <QuartzCore/QuartzCore.h>

static NSString *const LGC_DOMAIN = @"com.vn.liquidglassbar";
static NSString *const LGC_PREFS_NOTIFICATION = @"com.vn.liquidglassbar/prefsChanged";

static UIColor *LGCColorFromHex(NSString *hexStr, UIColor *fallback) {
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

static UIImage *LGCGlassImageForSize(CGSize size, BOOL isBlob) {
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

@interface LGCPreviewCell () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *stageView;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *bgDigitsLabel;
@property (nonatomic, strong) UIView *circleA;
@property (nonatomic, strong) UIView *circleB;
@property (nonatomic, strong) NSArray<UIView *> *fakeRows;
@property (nonatomic, strong) UIVisualEffectView *pillFx;
@property (nonatomic, strong) UIView *pillTint;
@property (nonatomic, strong) UIImageView *pillAsset;
@property (nonatomic, strong) UIView *blobContainer;
@property (nonatomic, strong) UIVisualEffectView *blobFx;
@property (nonatomic, strong) UIView *blobTint;
@property (nonatomic, strong) UIImageView *blobAsset;
@property (nonatomic, strong) NSArray<UIImageView *> *iconViews;
@property (nonatomic, strong) NSArray<UILabel *> *labelViews;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign) NSInteger hoverIndex;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) CGFloat dragStartX;
@property (nonatomic, assign) CGFloat lastDragX;
@property (nonatomic, assign) CGFloat settledCenterX;
@property (nonatomic, assign) CGRect currentPillRect;
@property (nonatomic, assign) CGFloat springPct;
@property (nonatomic, assign) CGFloat stretchPct;
@property (nonatomic, assign) CGFloat touchScalePct;
@property (nonatomic, assign) BOOL hapticsEnabled;
@property (nonatomic, copy) NSString *lastHash;
@end

static void LGCPreviewPrefsChanged(CFNotificationCenterRef center, void *observer,
                                   CFStringRef name, const void *object,
                                   CFDictionaryRef userInfo) {
    (void)center; (void)name; (void)object; (void)userInfo;
    LGCPreviewCell *cell = (__bridge LGCPreviewCell *)observer;
    dispatch_async(dispatch_get_main_queue(), ^{
        [cell refreshPreview];
    });
}

@implementation LGCPreviewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        _selectedIndex = 0;
        _hoverIndex = -1;
        [self buildPreview];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge void *)self, LGCPreviewPrefsChanged,
            (__bridge CFStringRef)LGC_PREFS_NOTIFICATION, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
    }
    return self;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge void *)self, (__bridge CFStringRef)LGC_PREFS_NOTIFICATION, NULL);
}

- (void)buildPreview {
    self.stageView = [[UIView alloc] initWithFrame:CGRectZero];
    self.stageView.backgroundColor = [UIColor colorWithRed:0.03 green:0.03 blue:0.04 alpha:1.0];
    self.stageView.layer.cornerRadius = 22;
    self.stageView.layer.masksToBounds = YES;
    [self.contentView addSubview:self.stageView];

    self.circleA = [[UIView alloc] initWithFrame:CGRectZero];
    self.circleA.backgroundColor = [UIColor colorWithRed:1.0 green:0.48 blue:0.12 alpha:0.92];
    [self.stageView addSubview:self.circleA];

    self.circleB = [[UIView alloc] initWithFrame:CGRectZero];
    self.circleB.backgroundColor = [UIColor colorWithRed:0.15 green:0.52 blue:1.0 alpha:0.92];
    [self.stageView addSubview:self.circleB];

    self.bgDigitsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bgDigitsLabel.text = @"0269 8891588 • Hạnh Hồ (2) • Việt Nam";
    self.bgDigitsLabel.font = [UIFont systemFontOfSize:21 weight:UIFontWeightBold];
    self.bgDigitsLabel.textColor = [UIColor colorWithRed:1.0 green:0.24 blue:0.20 alpha:0.95];
    [self.stageView addSubview:self.bgDigitsLabel];

    NSMutableArray<UIView *> *rows = [NSMutableArray array];
    for (NSInteger i = 0; i < 2; i++) {
        UIView *row = [[UIView alloc] initWithFrame:CGRectZero];
        row.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        row.layer.cornerRadius = 4.5;
        [self.stageView addSubview:row];
        [rows addObject:row];
    }
    self.fakeRows = rows;

    self.hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.hintLabel.text = @"Chạm hoặc kéo thử glass trên khung này";
    self.hintLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.hintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    self.hintLabel.textAlignment = NSTextAlignmentCenter;
    [self.stageView addSubview:self.hintLabel];

    self.pillFx = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.pillFx.layer.masksToBounds = YES;
    self.pillTint = [[UIView alloc] initWithFrame:CGRectZero];
    self.pillTint.userInteractionEnabled = NO;
    [self.pillFx.contentView addSubview:self.pillTint];
    [self.stageView addSubview:self.pillFx];

    self.pillAsset = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.pillAsset.userInteractionEnabled = NO;
    [self.stageView addSubview:self.pillAsset];

    self.blobContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.blobContainer.userInteractionEnabled = NO;
    self.blobContainer.backgroundColor = [UIColor clearColor];
    [self.stageView addSubview:self.blobContainer];

    self.blobFx = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark]];
    self.blobFx.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blobFx.layer.masksToBounds = YES;
    self.blobTint = [[UIView alloc] initWithFrame:CGRectZero];
    self.blobTint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blobTint.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.blobTint.userInteractionEnabled = NO;
    [self.blobFx.contentView addSubview:self.blobTint];
    [self.blobContainer addSubview:self.blobFx];

    self.blobAsset = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.blobAsset.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.blobAsset.userInteractionEnabled = NO;
    [self.blobContainer addSubview:self.blobAsset];

    NSArray<NSString *> *symbols = @[@"message.fill", @"person.2.fill", @"bell.fill", @"line.3.horizontal"];
    NSArray<NSString *> *names = @[@"Đoạn chat", @"Mọi người", @"Thông báo", @"Menu"];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightMedium];
    NSMutableArray<UIImageView *> *icons = [NSMutableArray array];
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    for (NSInteger i = 0; i < 4; i++) {
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbols[i] withConfiguration:cfg]];
        iv.contentMode = UIViewContentModeCenter;
        [self.stageView addSubview:iv];
        [icons addObject:iv];

        UILabel *lab = [[UILabel alloc] initWithFrame:CGRectZero];
        lab.text = names[i];
        lab.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
        lab.textAlignment = NSTextAlignmentCenter;
        [self.stageView addSubview:lab];
        [labels addObject:lab];
    }
    self.iconViews = icons;
    self.labelViews = labels;

    UILongPressGestureRecognizer *drag = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePreviewDrag:)];
    drag.minimumPressDuration = 0;
    drag.allowableMovement = CGFLOAT_MAX;
    drag.delegate = self;
    [self.stageView addGestureRecognizer:drag];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.contentView.bounds.size.width;
    CGFloat H = self.contentView.bounds.size.height;
    self.stageView.frame = CGRectMake(14, 8, W - 28, H - 16);
    [self refreshPreview];
}

- (CGRect)blobFrameForIndex:(NSInteger)idx pill:(CGRect)pill wPct:(CGFloat)wPct hPct:(CGFloat)hPct {
    NSInteger n = 4;
    CGFloat slotW = pill.size.width / n;
    CGFloat bw = MIN(MAX(slotW * (wPct / 100.0), 44.0), pill.size.width - 6.0);
    CGFloat bh = MIN(MAX((pill.size.height - 6.0) * (hPct / 100.0), 40.0), pill.size.height - 4.0);
    CGFloat cx = CGRectGetMinX(pill) + slotW * (idx + 0.5);
    cx = MIN(MAX(cx, CGRectGetMinX(pill) + bw / 2.0 + 3.0), CGRectGetMaxX(pill) - bw / 2.0 - 3.0);
    CGFloat cy = CGRectGetMidY(pill);
    return CGRectMake(cx - bw / 2.0, cy - bh / 2.0, bw, bh);
}

- (void)updateItemColorsWithActiveIndex:(NSInteger)activeIdx {
    CFPreferencesAppSynchronize((__bridge CFStringRef)LGC_DOMAIN);
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:LGC_DOMAIN];
    NSString *selHex = [d stringForKey:@"selectedColorHex"] ?: @"#0084FF";
    NSString *unselHex = [d stringForKey:@"unselectedColorHex"] ?: @"#A0A4AB";
    UIColor *selColor = LGCColorFromHex(selHex, [UIColor colorWithRed:0.0 green:0.52 blue:1.0 alpha:1.0]);
    UIColor *unselColor = LGCColorFromHex(unselHex, [UIColor colorWithRed:0.63 green:0.64 blue:0.67 alpha:1.0]);
    for (NSInteger i = 0; i < 4; i++) {
        UIColor *c = (i == activeIdx) ? selColor : unselColor;
        self.iconViews[i].tintColor = c;
        self.labelViews[i].textColor = c;
    }
}

- (void)refreshPreview {
    if (self.stageView.bounds.size.width < 50) return;
    CFPreferencesAppSynchronize((__bridge CFStringRef)LGC_DOMAIN);
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:LGC_DOMAIN];

    NSString *selHex = [d stringForKey:@"selectedColorHex"] ?: @"#0084FF";
    NSString *unselHex = [d stringForKey:@"unselectedColorHex"] ?: @"#A0A4AB";
    NSString *tintHex = [d stringForKey:@"glassTintHex"] ?: @"#141418";
    CGFloat glassAlpha = [d objectForKey:@"glassAlpha"] ? (CGFloat)[d doubleForKey:@"glassAlpha"] : 0.88;
    CGFloat blobAlpha = [d objectForKey:@"blobAlpha"] ? (CGFloat)[d doubleForKey:@"blobAlpha"] : 0.92;
    CGFloat wPct = [d objectForKey:@"blobWidthPct"] ? (CGFloat)[d doubleForKey:@"blobWidthPct"] : 104.0;
    CGFloat hPct = [d objectForKey:@"blobHeightPct"] ? (CGFloat)[d doubleForKey:@"blobHeightPct"] : 92.0;
    CGFloat pillH = [d objectForKey:@"pillHeight"] ? (CGFloat)[d doubleForKey:@"pillHeight"] : 60.0;
    CGFloat inset = [d objectForKey:@"pillInset"] ? (CGFloat)[d doubleForKey:@"pillInset"] : 10.0;
    self.springPct = [d objectForKey:@"springPct"] ? (CGFloat)[d doubleForKey:@"springPct"] : 60.0;
    self.stretchPct = [d objectForKey:@"stretchPct"] ? (CGFloat)[d doubleForKey:@"stretchPct"] : 65.0;
    self.touchScalePct = [d objectForKey:@"touchScalePct"] ? (CGFloat)[d doubleForKey:@"touchScalePct"] : 105.0;
    self.hapticsEnabled = [d objectForKey:@"haptics"] ? [d boolForKey:@"haptics"] : YES;

    NSString *hash = [NSString stringWithFormat:@"%@|%@|%@|%.2f|%.2f|%.0f|%.0f|%.0f|%.0f|%ld|%@",
                      selHex, unselHex, tintHex, glassAlpha, blobAlpha, wPct, hPct, pillH, inset,
                      (long)self.selectedIndex, NSStringFromCGSize(self.stageView.bounds.size)];
    if ([hash isEqualToString:self.lastHash]) return;
    self.lastHash = hash;

    UIColor *tintColor = LGCColorFromHex(tintHex, [UIColor colorWithRed:0.08 green:0.08 blue:0.10 alpha:1.0]);
    CGRect stage = self.stageView.bounds;

    self.hintLabel.frame = CGRectMake(12, 8, stage.size.width - 24, 16);

    self.circleA.frame = CGRectMake(stage.size.width * 0.04, stage.size.height - 96, 86, 86);
    self.circleA.layer.cornerRadius = 43;
    self.circleB.frame = CGRectMake(stage.size.width * 0.74, stage.size.height - 104, 78, 78);
    self.circleB.layer.cornerRadius = 39;
    self.bgDigitsLabel.frame = CGRectMake(18, stage.size.height - 74, stage.size.width - 24, 28);

    CGFloat rowW[] = {0.48, 0.66};
    for (NSInteger i = 0; i < 2; i++) {
        self.fakeRows[i].frame = CGRectMake(18, 28 + i * 14, stage.size.width * rowW[i], 8);
    }

    CGFloat clampedPillH = MIN(MAX(pillH, 48.0), 70.0);
    CGRect pill = CGRectMake(inset, stage.size.height - clampedPillH - 12,
                             stage.size.width - inset * 2, clampedPillH);
    self.currentPillRect = pill;

    self.pillFx.frame = pill;
    self.pillFx.layer.cornerRadius = clampedPillH / 2.0;
    self.pillFx.alpha = glassAlpha;
    self.pillTint.frame = self.pillFx.bounds;
    self.pillTint.backgroundColor = [tintColor colorWithAlphaComponent:0.24];

    self.pillAsset.frame = pill;
    self.pillAsset.image = LGCGlassImageForSize(pill.size, NO);
    self.pillAsset.alpha = glassAlpha;

    NSInteger n = 4;
    CGFloat slotW = pill.size.width / n;
    CGFloat contentH = 38;
    CGFloat contentY = CGRectGetMidY(pill) - contentH / 2.0;
    for (NSInteger i = 0; i < n; i++) {
        CGFloat cx = CGRectGetMinX(pill) + slotW * (i + 0.5);
        self.iconViews[i].frame = CGRectMake(cx - 14, contentY, 28, 23);
        self.labelViews[i].frame = CGRectMake(CGRectGetMinX(pill) + slotW * i, contentY + 25, slotW, 13);
    }

    NSInteger activeIdx = (self.hoverIndex >= 0) ? self.hoverIndex : self.selectedIndex;
    [self updateItemColorsWithActiveIndex:activeIdx];

    if (!self.isDragging) {
        CGRect blob = [self blobFrameForIndex:self.selectedIndex pill:pill wPct:wPct hPct:hPct];
        self.blobContainer.transform = CGAffineTransformIdentity;
        self.blobContainer.frame = blob;
        self.blobFx.frame = self.blobContainer.bounds;
        self.blobFx.layer.cornerRadius = blob.size.height / 2.0;
        self.blobFx.alpha = blobAlpha;
        self.blobAsset.frame = self.blobContainer.bounds;
        self.blobAsset.image = LGCGlassImageForSize(blob.size, YES);
        self.blobAsset.alpha = blobAlpha;
    }
}

- (void)handlePreviewDrag:(UILongPressGestureRecognizer *)gr {
    CGRect pill = self.currentPillRect;
    if (pill.size.width < 40) return;

    CGFloat x = [gr locationInView:self.stageView].x;
    CGFloat slotW = pill.size.width / 4.0;
    CGFloat minX = CGRectGetMinX(pill) + slotW * 0.5;
    CGFloat maxX = CGRectGetMaxX(pill) - slotW * 0.5;
    CGFloat clampedX = MIN(MAX(x, minX), maxX);

    NSInteger nearIdx = (NSInteger)floor((clampedX - CGRectGetMinX(pill)) / slotW);
    nearIdx = MIN(MAX(nearIdx, 0), 3);

    switch (gr.state) {
        case UIGestureRecognizerStateBegan: {
            self.isDragging = YES;
            self.dragStartX = x;
            self.lastDragX = x;
            self.hoverIndex = nearIdx;
            [self.blobContainer.layer removeAllAnimations];
            self.blobContainer.transform = CGAffineTransformIdentity;
            self.settledCenterX = CGRectGetMidX(self.blobContainer.frame);
            if (nearIdx != self.selectedIndex) {
                [self updateItemColorsWithActiveIndex:nearIdx];
                if (self.hapticsEnabled) {
                    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
                }
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            CGFloat tx = clampedX - self.settledCenterX;
            CGFloat txMin = CGRectGetMinX(pill) + 3.0 - CGRectGetMinX(self.blobContainer.frame);
            CGFloat txMax = CGRectGetMaxX(pill) - 3.0 - CGRectGetMaxX(self.blobContainer.frame);
            tx = MIN(MAX(tx, txMin), txMax);

            CGFloat dx = x - self.lastDragX;
            self.lastDragX = x;
            CGFloat baseScale = self.touchScalePct / 100.0;
            CGFloat maxStretch = 0.28 * (self.stretchPct / 100.0);
            CGFloat stretch = (maxStretch > 0.001)
                ? MIN(maxStretch, fabs(dx) / 90.0 * (maxStretch / 0.18)) : 0;
            CGFloat sx = baseScale * (1.0 + stretch);
            CGFloat sy = baseScale / (1.0 + stretch * 0.50);

            CGAffineTransform tr = CGAffineTransformMakeTranslation(tx, 0);
            tr = CGAffineTransformScale(tr, sx, sy);
            self.blobContainer.transform = tr;

            if (nearIdx != self.hoverIndex) {
                self.hoverIndex = nearIdx;
                [self updateItemColorsWithActiveIndex:nearIdx];
                if (self.hapticsEnabled) {
                    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
                }
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            self.isDragging = NO;
            self.selectedIndex = nearIdx;
            self.hoverIndex = -1;
            self.lastHash = nil;
            [self updateItemColorsWithActiveIndex:nearIdx];

            NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:LGC_DOMAIN];
            CGFloat wPct = [d objectForKey:@"blobWidthPct"] ? (CGFloat)[d doubleForKey:@"blobWidthPct"] : 104.0;
            CGFloat hPct = [d objectForKey:@"blobHeightPct"] ? (CGFloat)[d doubleForKey:@"blobHeightPct"] : 92.0;
            CGRect target = [self blobFrameForIndex:nearIdx pill:pill wPct:wPct hPct:hPct];
            CGFloat dx = CGRectGetMidX(target) - CGRectGetMidX(self.blobContainer.frame);
            CGFloat damping = 1.0 - 0.52 * (self.springPct / 100.0);

            [UIView animateWithDuration:0.38 delay:0
                 usingSpringWithDamping:damping initialSpringVelocity:0.6
                                options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.blobContainer.transform = CGAffineTransformMakeTranslation(dx, 0);
                             }
                             completion:^(__unused BOOL finished) {
                                 self.blobContainer.transform = CGAffineTransformIdentity;
                                 self.blobContainer.frame = target;
                                 self.blobFx.frame = self.blobContainer.bounds;
                                 self.blobAsset.frame = self.blobContainer.bounds;
                             }];
            break;
        }
        default:
            break;
    }
}

@end
