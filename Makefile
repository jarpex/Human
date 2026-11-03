CC ?= clang
CFLAGS ?= -O2 -Wall -Wextra -fobjc-arc
FRAMEWORKS = -framework Cocoa -framework AVFoundation

APP_NAME = Human
BUNDLE_NAME = $(APP_NAME).app
CONTENTS = $(BUNDLE_NAME)/Contents
MACOS = $(CONTENTS)/MacOS

.PHONY: all app run clean

all: $(APP_NAME) app

$(APP_NAME): main.m Info.plist
	$(CC) $(CFLAGS) $(FRAMEWORKS) -Wl,-sectcreate,__TEXT,__info_plist,Info.plist main.m -o $(APP_NAME)

app: $(APP_NAME) Info.plist
	mkdir -p $(MACOS)
	cp $(APP_NAME) $(MACOS)/$(APP_NAME)
	cp Info.plist $(CONTENTS)/Info.plist

run: app
	open $(BUNDLE_NAME)

clean:
	rm -rf $(APP_NAME) $(BUNDLE_NAME)
