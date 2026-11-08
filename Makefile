TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = Telegram

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = HideRail

HideRail_FILES = HideRail.m
HideRail_CFLAGS = -fobjc-arc
HideRail_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/library.mk