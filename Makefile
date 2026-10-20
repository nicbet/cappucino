.PHONY: build icon bundle install run snapshot screenshots signing-cert clean

APP_NAME := Cappucino
BUNDLE := Cappucino.app
BUILD_DIR := .build/release

# Sign with the local certificate from `make signing-cert` when it is in the keychain, otherwise ad hoc.
SIGNING_IDENTITY ?= Local App Signing
SIGN_WITH := $(shell security find-identity -v -p codesigning 2>/dev/null | grep -q '"$(SIGNING_IDENTITY)"' && echo '$(SIGNING_IDENTITY)' || echo -)
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
	@if [ "$(SIGN_WITH)" = "-" ]; then echo "Signing ad hoc. Run 'make signing-cert' once to sign with a stable identity."; fi
	codesign --force --sign "$(SIGN_WITH)" "$(BUNDLE)"
	@echo "Built $(BUNDLE)"

install: bundle
	rm -rf "/Applications/$(BUNDLE)"
	cp -R "$(BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(BUNDLE)"

run: bundle
	open "$(BUNDLE)"

# Render the popover and Settings, light and dark, to .build/snapshots/*.png
snapshot: build
	"$(BUILD_DIR)/Cappucino" --snapshot .build/snapshots

# Refresh the README screenshots in docs/ from the snapshots (needs cwebp: brew install webp)
SCREENSHOTS := popover-agents popover-timer popover-burn-in settings
screenshots: snapshot
	@for name in $(SCREENSHOTS); do for theme in light dark; do \
		cwebp -quiet -q 92 -m 6 -exact ".build/snapshots/$$name-$$theme.png" -o "docs/$$name-$$theme.webp"; \
	done; done
	@ls -l docs

signing-cert:
	SIGNING_IDENTITY="$(SIGNING_IDENTITY)" scripts/create-signing-cert.sh

clean:
	swift package clean
	rm -rf "$(BUNDLE)"
