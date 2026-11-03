CC ?= clang
ARCH_FLAGS ?= -arch arm64 -arch x86_64
CFLAGS ?= -O2 -Wall -Wextra -fobjc-arc $(ARCH_FLAGS)
FRAMEWORKS = -framework Cocoa -framework AVFoundation

APP_NAME = Human
BUNDLE_NAME = $(APP_NAME).app
BUILD_DIR = build
CONTENTS = $(BUILD_DIR)/$(BUNDLE_NAME)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources
DIST_ZIP = $(BUILD_DIR)/$(APP_NAME).zip
PREFIX ?= /Applications

SRC = src/main.m
PLIST = resources/Info.plist
ICON_PNG = resources/AppIcon.png
ICON_ICNS = $(BUILD_DIR)/AppIcon.icns

.PHONY: all app dist run install uninstall clean

all: $(BUILD_DIR)/$(APP_NAME) app

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(APP_NAME): $(SRC) $(PLIST) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(FRAMEWORKS) -Wl,-sectcreate,__TEXT,__info_plist,$(PLIST) $(SRC) -o $@

$(ICON_ICNS): $(ICON_PNG) | $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/AppIcon.iconset
	sips -z 16 16     $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16.png > /dev/null
	sips -z 32 32     $< --out $(BUILD_DIR)/AppIcon.iconset/icon_16x16@2x.png > /dev/null
	sips -z 32 32     $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32.png > /dev/null
	sips -z 64 64     $< --out $(BUILD_DIR)/AppIcon.iconset/icon_32x32@2x.png > /dev/null
	sips -z 128 128   $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128.png > /dev/null
	sips -z 256 256   $< --out $(BUILD_DIR)/AppIcon.iconset/icon_128x128@2x.png > /dev/null
	sips -z 256 256   $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256.png > /dev/null
	sips -z 512 512   $< --out $(BUILD_DIR)/AppIcon.iconset/icon_256x256@2x.png > /dev/null
	sips -z 512 512   $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512.png > /dev/null
	sips -z 1024 1024 $< --out $(BUILD_DIR)/AppIcon.iconset/icon_512x512@2x.png > /dev/null
	iconutil -c icns $(BUILD_DIR)/AppIcon.iconset -o $@
	@rm -rf $(BUILD_DIR)/AppIcon.iconset

app: $(BUILD_DIR)/$(APP_NAME) $(PLIST) $(ICON_ICNS) | $(BUILD_DIR)
	mkdir -p $(MACOS) $(RESOURCES)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS)/$(APP_NAME)
	cp $(PLIST) $(CONTENTS)/Info.plist
	cp $(ICON_ICNS) $(RESOURCES)/AppIcon.icns

dist: app
	rm -f $(DIST_ZIP)
	ditto -c -k --keepParent $(BUILD_DIR)/$(BUNDLE_NAME) $(DIST_ZIP)

run: app
	open $(BUILD_DIR)/$(BUNDLE_NAME)

install: app
	rm -rf $(PREFIX)/$(BUNDLE_NAME)
	cp -R $(BUILD_DIR)/$(BUNDLE_NAME) $(PREFIX)/

uninstall:
	rm -rf $(PREFIX)/$(BUNDLE_NAME)

clean:
	rm -rf $(BUILD_DIR)
