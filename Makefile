# Build CompatBridge.dylib for iOS (TrollStore IPA injection)
#
# Requires: Xcode with iOS SDK (macOS)
# Usage:    make
#
# For GitHub Actions CI, use the workflow at .github/workflows/build.yml

SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
TARGET = CompatBridge.dylib
SOURCES = CompatBridge.m
FRAMEWORKS = -framework Foundation -framework UIKit
CFLAGS = -arch arm64 -arch arm64e \
         -isysroot $(SDK) \
         -miphoneos-version-min=14.0 \
         -O2 -fobjc-arc

all: $(TARGET)

$(TARGET): $(SOURCES)
	xcrun clang $(CFLAGS) -dynamiclib -o $@ $^ $(FRAMEWORKS)
	xcrun codesign -s - $@ 2>/dev/null || true
	@echo ""
	@echo "Build successful: $(TARGET)"
	@file $(TARGET)
	@echo ""
	@echo "Injection order (alphabetical):"
	@echo "  1. CompatBridge.dylib (this file)"
	@echo "  2. WeChatLiquidGlass.dylib (patched)"
	@echo "  3. libPineappleDylib.dylib (ThemePro)"

clean:
	rm -f $(TARGET)
