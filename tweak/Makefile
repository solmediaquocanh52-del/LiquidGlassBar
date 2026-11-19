TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Messenger

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LiquidGlassBar
LiquidGlassBar_FILES = Tweak.x
LiquidGlassBar_CFLAGS = -fobjc-arc
LiquidGlassBar_FRAMEWORKS = UIKit QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
