#import "LGCColorCell.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *LGCCellColorFromHex(NSString *hexStr, UIColor *fallback) {
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

@interface LGCColorCell ()
@property (nonatomic, strong) UIView *swatchView;
@property (nonatomic, strong) UILabel *hexLabel;
@end

@implementation LGCColorCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

        self.swatchView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
        self.swatchView.translatesAutoresizingMaskIntoConstraints = NO;
        self.swatchView.layer.cornerRadius = 13.0;
        self.swatchView.layer.borderWidth = 2.0;
        self.swatchView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.65].CGColor;

        self.hexLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.hexLabel.translatesAutoresizingMaskIntoConstraints = NO;
        self.hexLabel.font = [UIFont monospacedSystemFontOfSize:12.0 weight:UIFontWeightMedium];
        self.hexLabel.textColor = [UIColor secondaryLabelColor];

        [self.contentView addSubview:self.swatchView];
        [self.contentView addSubview:self.hexLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.swatchView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.swatchView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-8.0],
            [self.swatchView.widthAnchor constraintEqualToConstant:26.0],
            [self.swatchView.heightAnchor constraintEqualToConstant:26.0],
            [self.hexLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.hexLabel.trailingAnchor constraintEqualToAnchor:self.swatchView.leadingAnchor constant:-8.0]
        ]];

        [self refreshCellContentsWithSpecifier:specifier];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    CFPreferencesAppSynchronize((__bridge CFStringRef)@"com.vn.liquidglassbar");
    NSString *key = [specifier propertyForKey:@"colorKey"] ?: [specifier propertyForKey:@"key"];
    NSString *defaultHex = [specifier propertyForKey:@"defaultHex"] ?: @"#0084FF";
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.vn.liquidglassbar"];
    NSString *hex = key ? [defaults stringForKey:key] : nil;
    if (!hex || hex.length < 6) hex = defaultHex;
    self.swatchView.backgroundColor = LGCCellColorFromHex(hex, [UIColor blueColor]);
    self.hexLabel.text = [hex uppercaseString];
}

@end
