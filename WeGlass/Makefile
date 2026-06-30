# Build WeGlass.dylib for iOS (TrollStore IPA injection)
#
# Requires: Xcode with iOS SDK (macOS)
# Usage:    make
#
# For GitHub Actions CI, use the workflow at ../.github/workflows/weglass-build.yml

SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
TARGET = WeGlass.dylib
SOURCES = WeGlass.m
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
	@echo "  1. CompatBridge.dylib"
	@echo "  2. libPineappleDylib.dylib (ThemePro)"
	@echo "  3. WeGlass.dylib (this file)"

clean:
	rm -f $(TARGET)