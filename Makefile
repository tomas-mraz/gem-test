APP = gem-test
BUILD_DIR = build

ANDROID_TARGET ?= aarch64-linux-android
ANDROID_ABI ?= arm64-v8a
ANDROID_DIR = android
ANDROID_JNILIBS = $(ANDROID_DIR)/app/src/main/jniLibs/$(ANDROID_ABI)
ANDROID_APK_DEBUG = $(ANDROID_DIR)/app/build/outputs/apk/debug/app-$(ANDROID_ABI)-debug.apk
ANDROID_APK_RELEASE = $(ANDROID_DIR)/app/build/outputs/apk/release/app-$(ANDROID_ABI)-release-unsigned.apk

# Linux amd64 is a host build (no -Dtarget) so Zig picks up system Wayland/X11
# headers and libraries; cross-compiling to a different Linux arch needs a
# matching sysroot, which the Makefile does not provision.
LINUX_ARM64_TARGET ?= aarch64-linux-gnu

WINDOWS_TARGET ?= x86_64-windows-gnu
WINDOWS_ARM64_TARGET ?= aarch64-windows-gnu

# macOS cross-compile from Linux needs a staged macOS SDK via SDKROOT;
# native builds on macOS pick the SDK up automatically via xcrun.
MACOS_TARGET ?= aarch64-macos-none

.PHONY: run ensure-build-dir \
        build-linux build-linux-release build-linux-arm64 build-linux-arm64-release clean-linux \
        build-android build-android-release clean-android \
        build-windows build-windows-release build-windows-arm64 build-windows-arm64-release clean-windows \
        build-macos build-macos-release clean-macos \
        build-all build-all-release

# build-linux-arm64 is omitted: it needs an aarch64-linux sysroot with
# Wayland/X11 headers, which the Makefile does not provision.
build-all: build-linux build-android build-windows build-windows-arm64 build-macos

build-all-release: build-linux-release build-android-release build-windows-release build-windows-arm64-release build-macos-release

run:
	zig build run

ensure-build-dir:
	mkdir -p $(BUILD_DIR)

build-linux: | ensure-build-dir
	zig build
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-amd64

build-linux-release: | ensure-build-dir
	zig build -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-amd64

build-linux-arm64: | ensure-build-dir
	zig build -Dtarget=$(LINUX_ARM64_TARGET)
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-arm64

build-linux-arm64-release: | ensure-build-dir
	zig build -Dtarget=$(LINUX_ARM64_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-linux-arm64

clean-linux:
	rm -f $(BUILD_DIR)/$(APP)-linux-amd64 $(BUILD_DIR)/$(APP)-linux-arm64

build-android: | ensure-build-dir
	zig build -Dtarget=$(ANDROID_TARGET)
	mkdir -p $(ANDROID_JNILIBS)
	mv zig-out/lib/lib$(APP).so $(ANDROID_JNILIBS)/
	cd $(ANDROID_DIR) && ./gradlew assembleDebug
	mv $(ANDROID_APK_DEBUG) $(BUILD_DIR)/$(APP)-arm64-debug.apk

build-android-release: | ensure-build-dir
	zig build -Dtarget=$(ANDROID_TARGET) -Doptimize=ReleaseSafe
	mkdir -p $(ANDROID_JNILIBS)
	mv zig-out/lib/lib$(APP).so $(ANDROID_JNILIBS)/
	cd $(ANDROID_DIR) && ./gradlew assembleRelease
	mv $(ANDROID_APK_RELEASE) $(BUILD_DIR)/$(APP)-arm64-release-unsigned.apk

clean-android:
	rm -rf $(ANDROID_DIR)/app/build $(ANDROID_DIR)/app/src/main/jniLibs
	rm -f $(BUILD_DIR)/$(APP)-arm64-debug.apk $(BUILD_DIR)/$(APP)-arm64-release-unsigned.apk

build-windows: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_TARGET)
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-amd64.exe

build-windows-release: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-amd64.exe

build-windows-arm64: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_ARM64_TARGET)
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-arm64.exe

build-windows-arm64-release: | ensure-build-dir
	zig build -Dtarget=$(WINDOWS_ARM64_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP).exe $(BUILD_DIR)/$(APP)-win-arm64.exe

clean-windows:
	rm -f $(BUILD_DIR)/$(APP)-win-amd64.exe $(BUILD_DIR)/$(APP)-win-amd64.pdb \
	      $(BUILD_DIR)/$(APP)-win-arm64.exe $(BUILD_DIR)/$(APP)-win-arm64.pdb

build-macos: | ensure-build-dir
	zig build -Dtarget=$(MACOS_TARGET)
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-macos-arm64

build-macos-release: | ensure-build-dir
	zig build -Dtarget=$(MACOS_TARGET) -Doptimize=ReleaseSafe
	mv zig-out/bin/$(APP) $(BUILD_DIR)/$(APP)-macos-arm64

clean-macos:
	rm -f $(BUILD_DIR)/$(APP)-macos-arm64
