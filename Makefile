APP_NAME      := ReviveRight
EXT_NAME      := ReviveRightFinder
BUNDLE_ID     := com.shining.rightkit
EXT_BUNDLE_ID := com.shining.rightkit.FinderSync
VERSION       := $(shell /usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/App-Info.plist)

BUILD       := build
APP         := $(BUILD)/$(APP_NAME).app
EXT         := $(APP)/Contents/PlugIns/$(EXT_NAME).appex
SDK         := $(shell xcrun --show-sdk-path)
MIN_MACOS   := 14.0
ARCHS       ?= arm64 x86_64
APP_BINS    := $(foreach a,$(ARCHS),$(BUILD)/obj/$(APP_NAME)-$(a))
EXT_BINS    := $(foreach a,$(ARCHS),$(BUILD)/obj/$(EXT_NAME)-$(a))

SHARED_SRC := Sources/Shared/Config.swift Sources/Shared/Terminal.swift
APP_SRC    := $(SHARED_SRC) Sources/App/App.swift
EXT_SRC    := $(SHARED_SRC) Sources/Ext/FinderSync.swift Sources/Ext/Actions.swift

INSTALLED_APP := $(HOME)/Applications/$(APP_NAME).app
INSTALLED_EXT := $(INSTALLED_APP)/Contents/PlugIns/$(EXT_NAME).appex

.PHONY: all build bundle sign install register verify dist clean icon

all: sign

icon:
	swift scripts/gen_icon.swift Resources
	iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

build: $(APP)/Contents/MacOS/$(APP_NAME) $(EXT)/Contents/MacOS/$(EXT_NAME)

bundle: build
	cp Resources/App-Info.plist $(APP)/Contents/Info.plist
	printf 'APPL????' > $(APP)/Contents/PkgInfo
	cp Resources/Ext-Info.plist $(EXT)/Contents/Info.plist
	mkdir -p $(APP)/Contents/Resources
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	mkdir -p $(EXT)/Contents/Resources/Templates
	cp Resources/Templates/* $(EXT)/Contents/Resources/Templates/

$(BUILD)/obj/$(APP_NAME)-%: $(APP_SRC)
	mkdir -p $(BUILD)/obj
	swiftc -O -parse-as-library -module-name $(APP_NAME) -sdk "$(SDK)" \
		-target $*-apple-macosx$(MIN_MACOS) \
		-framework AppKit -framework SwiftUI -framework FinderSync $(APP_SRC) -o $@

$(BUILD)/obj/$(EXT_NAME)-%: $(EXT_SRC)
	mkdir -p $(BUILD)/obj
	swiftc -O -parse-as-library -application-extension -module-name $(EXT_NAME) \
		-sdk "$(SDK)" -target $*-apple-macosx$(MIN_MACOS) \
		-framework FinderSync -framework AppKit \
		-Xlinker -e -Xlinker _NSExtensionMain $(EXT_SRC) -o $@

$(APP)/Contents/MacOS/$(APP_NAME): $(APP_BINS)
	mkdir -p $(dir $@)
	lipo -create $(APP_BINS) -output $@

$(EXT)/Contents/MacOS/$(EXT_NAME): $(EXT_BINS)
	mkdir -p $(dir $@)
	lipo -create $(EXT_BINS) -output $@

sign: bundle
	codesign --force --sign - --timestamp=none \
		--entitlements Resources/Ext.entitlements "$(EXT)"
	codesign --force --sign - --timestamp=none "$(APP)"
	codesign --verify --deep --strict --verbose=2 "$(APP)"

install: sign
	mkdir -p $(HOME)/Applications
	rm -rf "$(INSTALLED_APP)"
	ditto "$(APP)" "$(INSTALLED_APP)"

register: install
	pluginkit -r "$(INSTALLED_EXT)" >/dev/null 2>&1 || true
	pluginkit -a "$(INSTALLED_EXT)"
	pluginkit -e use -i $(EXT_BUNDLE_ID)
	killall Finder 2>/dev/null || true

verify:
	pluginkit -m -i $(EXT_BUNDLE_ID) || true
	pgrep -fl FinderSyncExtensionHost || true

dist: sign
	ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(BUILD)/$(APP_NAME)-$(VERSION).zip"

clean:
	rm -rf $(BUILD)
