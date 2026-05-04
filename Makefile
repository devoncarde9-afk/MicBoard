TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = MicBoard
MicBoard_FILES = Tweak.x MicBoardOverlay.mm
MicBoard_FRAMEWORKS = UIKit AVFoundation AudioToolbox
MicBoard_LIBRARIES = substrate
include $(THEOS_MAKE_PATH)/tweak.mk
