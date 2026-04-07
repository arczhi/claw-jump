APP_NAME := claw-jump-agent
BUILD_DIR := .build
MODULE_CACHE_DIR := $(BUILD_DIR)/ModuleCache.noindex
SOURCE_DIR := Sources/ClawJumpAgent
SOURCES := \
	$(SOURCE_DIR)/main.m \
	$(SOURCE_DIR)/CJAppDelegate.m \
	$(SOURCE_DIR)/CJEventServer.m \
	$(SOURCE_DIR)/CJOverlayView.m

CFLAGS := -fobjc-arc -fmodules -Wall -Wextra -Wno-nullability-completeness
FRAMEWORKS := -framework AppKit -framework Foundation -framework QuartzCore

.PHONY: all clean run

all: $(BUILD_DIR)/$(APP_NAME)

$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	mkdir -p $(BUILD_DIR) $(MODULE_CACHE_DIR)
	CLANG_MODULE_CACHE_PATH=$(abspath $(MODULE_CACHE_DIR)) clang $(CFLAGS) $(FRAMEWORKS) $(SOURCES) -o $@

run: all
	./$(BUILD_DIR)/$(APP_NAME)

clean:
	rm -rf $(BUILD_DIR)
