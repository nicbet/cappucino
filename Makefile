.PHONY: build icon bundle install run clean

APP_NAME := Cappucino
BUNDLE := Cappucino.app
BUILD_DIR := .build/release
ICON_DIR := .build/icon

build:
	swift build -c release

# Compile the Icon Composer bundle into Assets.car (macOS 26 Liquid Glass icon)
# plus an AppIcon.icns fallback for older macOS. actool ships with Xcode.
icon:
	rm -rf "$(ICON_DIR)"
	mkdir -p "$(ICON_DIR)"
	xcrun actool Resources/AppIcon.icon --compile "$(ICON_DIR)" \
		--app-icon AppIcon --platform macosx --target-device mac \
		--minimum-deployment-target 14.0 --enable-on-demand-resources NO \
		--development-region en --output-partial-info-plist "$(ICON_DIR)/partial.plist" \
		--output-format human-readable-text > /dev/null

bundle: build icon
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	mkdir -p "$(BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/Cappucino" "$(BUNDLE)/Contents/MacOS/Cappucino"
	cp Resources/Info.plist "$(BUNDLE)/Contents/"
	cp "$(ICON_DIR)/Assets.car" "$(ICON_DIR)/AppIcon.icns" "$(BUNDLE)/Contents/Resources/"
	codesign --force --sign - "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

install: bundle
	rm -rf "/Applications/$(BUNDLE)"
	cp -R "$(BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

run: bundle
	open "$(BUNDLE)"

clean:
	swift package clean
	rm -rf "$(BUNDLE)"
