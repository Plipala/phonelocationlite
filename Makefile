ARCHS = armv7 arm64
include theos/makefiles/common.mk

TWEAK_NAME = PhoneLocationLite
PhoneLocationLite_FILES = Tweak.xm area.c
PhoneLocationLite_FRAMEWORKS = CoreTelephony CoreMedia

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
