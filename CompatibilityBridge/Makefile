# AACompat — WeChat ThemePro + LiquidGlass 兼容桥接
# 编译环境：theos (iOS 越狱插件开发工具链)

export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64 arm64e
export DEBUG = 0
export FINALPACKAGE = 1

INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AACompat

AACompat_FILES = Tweak.x
AACompat_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AACompat_FRAMEWORKS = UIKit Foundation
AACompat_PRIVATE_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat || true"
