CC ?= clang
CFLAGS ?= -O2 -Wall -Wextra -fobjc-arc
FRAMEWORKS = -framework Cocoa -framework AVFoundation

APP_NAME = Human
BUNDLE_NAME = $(APP_NAME).app
CONTENTS = $(BUNDLE_NAME)/Contents
MACOS = $(CONTENTS)/MacOS
RESOURCES = $(CONTENTS)/Resources

.PHONY: all app run clean

all: $(APP_NAME) app

$(APP_NAME): main.m Info.plist
	$(CC) $(CFLAGS) $(FRAMEWORKS) -Wl,-sectcreate,__TEXT,__info_plist,Info.plist main.m -o $(APP_NAME)

app: $(APP_NAME) Info.plist AppIcon.icns
	mkdir -p $(MACOS) $(RESOURCES)
	cp $(APP_NAME) $(MACOS)/$(APP_NAME)
	cp Info.plist $(CONTENTS)/Info.plist
	cp AppIcon.icns $(RESOURCES)/AppIcon.icns

AppIcon.icns: Icons/AppIcon.png
	@mkdir -p AppIcon.iconset
	sips -z 16 16     $< --out AppIcon.iconset/icon_16x16.png > /dev/null
	sips -z 32 32     $< --out AppIcon.iconset/icon_16x16@2x.png > /dev/null
	sips -z 32 32     $< --out AppIcon.iconset/icon_32x32.png > /dev/null
	sips -z 64 64     $< --out AppIcon.iconset/icon_32x32@2x.png > /dev/null
	sips -z 128 128   $< --out AppIcon.iconset/icon_128x128.png > /dev/null
	sips -z 256 256   $< --out AppIcon.iconset/icon_128x128@2x.png > /dev/null
	sips -z 256 256   $< --out AppIcon.iconset/icon_256x256.png > /dev/null
	sips -z 512 512   $< --out AppIcon.iconset/icon_256x256@2x.png > /dev/null
	sips -z 512 512   $< --out AppIcon.iconset/icon_512x512.png > /dev/null
	sips -z 1024 1024 $< --out AppIcon.iconset/icon_512x512@2x.png > /dev/null
	iconutil -c icns AppIcon.iconset -o $@
	@rm -rf AppIcon.iconset

run: app
	open $(BUNDLE_NAME)

clean:
	rm -rf $(APP_NAME) $(BUNDLE_NAME) AppIcon.icns AppIcon.iconset .iconset
