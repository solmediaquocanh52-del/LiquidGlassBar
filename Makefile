TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += tweak prefs

include $(THEOS_MAKE_PATH)/aggregate.mk
