APP = gem-test
BUILD_DIR = build
MACOS_APP_DISPLAY_NAME ?= Gem Test
MACOS_BUNDLE_ID ?= com.example.gemtest
MACOS_CODESIGN ?= codesign
MACOS_CODESIGN_IDENTITY ?=

ANDROID_TARGET ?= aarch64-linux-android
ANDROID_ABI ?= arm64-v8a
ANDROID_DIR = android
ANDROID_JNILIBS = $(ANDROID_DIR)/app/src/main/jniLibs/$(ANDROID_ABI)
ANDROID_APK_DEBUG = $(ANDROID_DIR)/app/build/outputs/apk/debug/app-$(ANDROID_ABI)-debug.apk
ANDROID_AAB_RELEASE = $(ANDROID_DIR)/app/build/outputs/bundle/release/app-release.aab
ANDROID_AAB_UNSIGNED = $(BUILD_DIR)/$(APP)-android.aab
ANDROID_AAB_SIGNED = $(BUILD_DIR)/$(APP)-android-signed.aab
JARSIGNER ?= jarsigner

# Linux amd64 is a host build (no -Dtarget) so Zig picks up system Wayland/X11
# headers and libraries; cross-compiling to a different Linux arch needs a
# matching sysroot, which the Makefile does not provision.
LINUX_ARM64_TARGET ?= aarch64-linux-gnu

WINDOWS_TARGET ?= x86_64-windows-gnu
WINDOWS_ARM64_TARGET ?= aarch64-windows-gnu

# macOS cross-compile from Linux needs a staged macOS SDK via SDKROOT;
# native builds on macOS pick the SDK up automatically via xcrun.
MACOS_TARGET ?= aarch64-macos-none
MACOS_APP_DEV = $(BUILD_DIR)/$(APP)-macos-arm64-dev.app
MACOS_APP_RELEASE = $(BUILD_DIR)/$(APP)-macos-arm64.app
MACOS_APP_SIGNED_DEV = $(BUILD_DIR)/$(APP)-macos-arm64-dev-signed.app
MACOS_APP_SIGNED_RELEASE = $(BUILD_DIR)/$(APP)-macos-arm64-signed.app
MACOS_DMG_DEV = $(BUILD_DIR)/$(APP)-macos-arm64-dev.dmg
MACOS_DMG_RELEASE = $(BUILD_DIR)/$(APP)-macos-arm64.dmg

.PHONY: run ensure-build-dir \
        build-linux build-linux-release build-linux-arm64 build-linux-arm64-release clean-linux \
        build-android build-android-release sign-android-release clean-android \
        build-windows build-windows-release build-windows-arm64 build-windows-arm64-release clean-windows \
        build-macos build-macos-release build-macos-app build-macos-app-release \
        sign-macos-app sign-macos-app-release \
        build-macos-dmg build-macos-dmg-release clean-macos \
        build-all build-all-release

build-all: build-linux build-linux-arm64 build-android build-windows build-windows-arm64 build-macos

build-all-release: build-linux-release build-linux-arm64-release build-android-release build-windows-release build-windows-arm64-release build-macos-release

run:
	zig build run

ensure-build-dir:
	mkdir -p $(BUILD_DIR)

build-linux: | ensure-build-dir
	zig build
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-amd64-dev

build-linux-release: | ensure-build-dir
	zig build -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-amd64

build-linux-arm64: | ensure-build-dir
	zig build -Dtarget=$(LINUX_ARM64_TARGET)
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-arm64-dev

build-linux-arm64-release: | ensure-build-dir
	zig build -Dtarget=$(LINUX_ARM64_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-arm64

clean-linux:
	rm -f $(BUILD_DIR)/$(APP)-linux-amd64 $(BUILD_DIR)/$(APP)-linux-amd64-dev \
	      $(BUILD_DIR)/$(APP)-linux-arm64 $(BUILD_DIR)/$(APP)-linux-arm64-dev

build-android: | ensure-build-dir
	zig build -Dtarget=$(ANDROID_TARGET)
	mkdir -p $(ANDROID_JNILIBS)
	mv zig-out/lib/lib$(APP).so $(ANDROID_JNILIBS)/
	cd $(ANDROID_DIR) && ./gradlew assembleDebug
	mv $(ANDROID_APK_DEBUG) $(BUILD_DIR)/$(APP)-android-arm64-dev.apk

build-android-release: | ensure-build-dir
	zig build -Dtarget=$(ANDROID_TARGET) -Doptimize=ReleaseSafe
	mkdir -p $(ANDROID_JNILIBS)
	mv zig-out/lib/lib$(APP).so $(ANDROID_JNILIBS)/
	cd $(ANDROID_DIR) && ./gradlew bundleRelease
	mv $(ANDROID_AAB_RELEASE) $(ANDROID_AAB_UNSIGNED)

sign-android-release: build-android-release
	@test -n "$(ANDROID_KEYSTORE)" || (echo "ANDROID_KEYSTORE is not set"; exit 1)
	@test -n "$(ANDROID_KEY_ALIAS)" || (echo "ANDROID_KEY_ALIAS is not set"; exit 1)
	@test -n "$(ANDROID_KEYSTORE_PASSWORD)" || (echo "ANDROID_KEYSTORE_PASSWORD is not set"; exit 1)
	@test -n "$(ANDROID_KEY_PASSWORD)" || (echo "ANDROID_KEY_PASSWORD is not set"; exit 1)
	$(JARSIGNER) -keystore "$(ANDROID_KEYSTORE)" -storepass "$(ANDROID_KEYSTORE_PASSWORD)" \
		-keypass "$(ANDROID_KEY_PASSWORD)" -signedjar "$(ANDROID_AAB_SIGNED)" \
		"$(ANDROID_AAB_UNSIGNED)" "$(ANDROID_KEY_ALIAS)"

clean-android:
	rm -rf $(ANDROID_DIR)/app/build $(ANDROID_DIR)/app/src/main/jniLibs
	rm -f $(BUILD_DIR)/$(APP)-android-arm64-dev.apk $(ANDROID_AAB_UNSIGNED) $(ANDROID_AAB_SIGNED)

build-windows: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_TARGET)
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-amd64-dev.exe

build-windows-release: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-amd64.exe

build-windows-arm64: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_ARM64_TARGET)
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-arm64-dev.exe

build-windows-arm64-release: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_ARM64_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-arm64.exe

clean-windows:
	rm -f $(BUILD_DIR)/$(APP)-win-amd64.exe $(BUILD_DIR)/$(APP)-win-amd64.pdb \
	      $(BUILD_DIR)/$(APP)-win-amd64-dev.exe $(BUILD_DIR)/$(APP)-win-amd64-dev.pdb \
	      $(BUILD_DIR)/$(APP)-win-arm64.exe $(BUILD_DIR)/$(APP)-win-arm64.pdb \
	      $(BUILD_DIR)/$(APP)-win-arm64-dev.exe $(BUILD_DIR)/$(APP)-win-arm64-dev.pdb

build-macos: | ensure-build-dir
	zig build -Dtarget=$(MACOS_TARGET)
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-macos-arm64-dev

build-macos-release: | ensure-build-dir
	zig build -Dtarget=$(MACOS_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-macos-arm64

build-macos-app: build-macos | ensure-build-dir
	rm -rf "$(MACOS_APP_DEV)"
	mkdir -p "$(MACOS_APP_DEV)/Contents/MacOS"
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleDevelopmentRegion</key>' \
		'  <string>en</string>' \
		'  <key>CFBundleDisplayName</key>' \
		'  <string>$(MACOS_APP_DISPLAY_NAME)</string>' \
		'  <key>CFBundleExecutable</key>' \
		'  <string>$(APP)</string>' \
		'  <key>CFBundleIdentifier</key>' \
		'  <string>$(MACOS_BUNDLE_ID)</string>' \
		'  <key>CFBundleInfoDictionaryVersion</key>' \
		'  <string>6.0</string>' \
		'  <key>CFBundleName</key>' \
		'  <string>$(MACOS_APP_DISPLAY_NAME)</string>' \
		'  <key>CFBundlePackageType</key>' \
		'  <string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key>' \
		'  <string>1.0.0</string>' \
		'  <key>CFBundleVersion</key>' \
		'  <string>1</string>' \
		'  <key>LSMinimumSystemVersion</key>' \
		'  <string>11.0</string>' \
		'  <key>NSHighResolutionCapable</key>' \
		'  <true/>' \
		'</dict>' \
		'</plist>' > "$(MACOS_APP_DEV)/Contents/Info.plist"
	cp "$(BUILD_DIR)/$(APP)-macos-arm64-dev" "$(MACOS_APP_DEV)/Contents/MacOS/$(APP)"
	chmod +x "$(MACOS_APP_DEV)/Contents/MacOS/$(APP)"

build-macos-app-release: build-macos-release | ensure-build-dir
	rm -rf "$(MACOS_APP_RELEASE)"
	mkdir -p "$(MACOS_APP_RELEASE)/Contents/MacOS"
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'  <key>CFBundleDevelopmentRegion</key>' \
		'  <string>en</string>' \
		'  <key>CFBundleDisplayName</key>' \
		'  <string>$(MACOS_APP_DISPLAY_NAME)</string>' \
		'  <key>CFBundleExecutable</key>' \
		'  <string>$(APP)</string>' \
		'  <key>CFBundleIdentifier</key>' \
		'  <string>$(MACOS_BUNDLE_ID)</string>' \
		'  <key>CFBundleInfoDictionaryVersion</key>' \
		'  <string>6.0</string>' \
		'  <key>CFBundleName</key>' \
		'  <string>$(MACOS_APP_DISPLAY_NAME)</string>' \
		'  <key>CFBundlePackageType</key>' \
		'  <string>APPL</string>' \
		'  <key>CFBundleShortVersionString</key>' \
		'  <string>1.0.0</string>' \
		'  <key>CFBundleVersion</key>' \
		'  <string>1</string>' \
		'  <key>LSMinimumSystemVersion</key>' \
		'  <string>11.0</string>' \
		'  <key>NSHighResolutionCapable</key>' \
		'  <true/>' \
		'</dict>' \
		'</plist>' > "$(MACOS_APP_RELEASE)/Contents/Info.plist"
	cp "$(BUILD_DIR)/$(APP)-macos-arm64" "$(MACOS_APP_RELEASE)/Contents/MacOS/$(APP)"
	chmod +x "$(MACOS_APP_RELEASE)/Contents/MacOS/$(APP)"

sign-macos-app: build-macos-app | ensure-build-dir
	@test "$$(uname -s)" = Darwin || (echo "sign-macos-app requires macOS (codesign)"; exit 1)
	@test -n "$(MACOS_CODESIGN_IDENTITY)" || (echo "MACOS_CODESIGN_IDENTITY is not set"; exit 1)
	rm -rf "$(MACOS_APP_SIGNED_DEV)"
	cp -R "$(MACOS_APP_DEV)" "$(MACOS_APP_SIGNED_DEV)"
	$(MACOS_CODESIGN) --force --sign "$(MACOS_CODESIGN_IDENTITY)" --timestamp --options runtime "$(MACOS_APP_SIGNED_DEV)"
	$(MACOS_CODESIGN) --verify --deep --strict --verbose=2 "$(MACOS_APP_SIGNED_DEV)"

sign-macos-app-release: build-macos-app-release | ensure-build-dir
	@test "$$(uname -s)" = Darwin || (echo "sign-macos-app-release requires macOS (codesign)"; exit 1)
	@test -n "$(MACOS_CODESIGN_IDENTITY)" || (echo "MACOS_CODESIGN_IDENTITY is not set"; exit 1)
	rm -rf "$(MACOS_APP_SIGNED_RELEASE)"
	cp -R "$(MACOS_APP_RELEASE)" "$(MACOS_APP_SIGNED_RELEASE)"
	$(MACOS_CODESIGN) --force --sign "$(MACOS_CODESIGN_IDENTITY)" --timestamp --options runtime "$(MACOS_APP_SIGNED_RELEASE)"
	$(MACOS_CODESIGN) --verify --deep --strict --verbose=2 "$(MACOS_APP_SIGNED_RELEASE)"

build-macos-dmg: sign-macos-app | ensure-build-dir
	@test "$$(uname -s)" = Darwin || (echo "build-macos-dmg requires macOS (hdiutil)"; exit 1)
	rm -f "$(MACOS_DMG_DEV)"
	hdiutil create -volname "$(MACOS_APP_DISPLAY_NAME)" -srcfolder "$(MACOS_APP_SIGNED_DEV)" -ov -format UDZO "$(MACOS_DMG_DEV)"

build-macos-dmg-release: sign-macos-app-release | ensure-build-dir
	@test "$$(uname -s)" = Darwin || (echo "build-macos-dmg-release requires macOS (hdiutil)"; exit 1)
	rm -f "$(MACOS_DMG_RELEASE)"
	hdiutil create -volname "$(MACOS_APP_DISPLAY_NAME)" -srcfolder "$(MACOS_APP_SIGNED_RELEASE)" -ov -format UDZO "$(MACOS_DMG_RELEASE)"

clean-macos:
	rm -f $(BUILD_DIR)/$(APP)-macos-arm64 $(BUILD_DIR)/$(APP)-macos-arm64-dev \
	      "$(MACOS_DMG_RELEASE)" "$(MACOS_DMG_DEV)"
	rm -rf "$(MACOS_APP_RELEASE)" "$(MACOS_APP_DEV)" \
	       "$(MACOS_APP_SIGNED_RELEASE)" "$(MACOS_APP_SIGNED_DEV)"
