TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = LiquidGlassBarPrefs
LiquidGlassBarPrefs_FILES = LGCRootListController.m LGCColorCell.m LGCPreviewCell.m
LiquidGlassBarPrefs_FRAMEWORKS = UIKit QuartzCore
LiquidGlassBarPrefs_INSTALL_PATH = /Library/PreferenceBundles
LiquidGlassBarPrefs_CFLAGS = -fobjc-arc
LiquidGlassBarPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
