GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

TWEAK_NAME = MCServer
MCServer_FILES = Tweak.xm
MCServer_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
