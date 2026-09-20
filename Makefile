# One command each, so neither a person nor an agent has to remember xcodebuild's flags.
SCHEME  := FantasyCat
BUNDLE  := co.fantasycat.app
SIM     ?= iPhone 18 Pro
DERIVED := build
APP     := $(DERIVED)/Build/Products/Debug-iphonesimulator/$(SCHEME).app
THEME   ?= dark
XCB     := xcodebuild -project $(SCHEME).xcodeproj -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DERIVED)

.PHONY: build test run shot clean

build: ## compile for the Simulator; warnings are printed, errors fail
	@$(XCB) -quiet build

test:
	@$(XCB) -quiet test

run: build ## install and launch in the Simulator
	@xcrun simctl boot '$(SIM)' 2>/dev/null || true
	@xcrun simctl install '$(SIM)' $(APP)
	@xcrun simctl launch '$(SIM)' $(BUNDLE)

shot: run ## screenshot the running app: make shot THEME=light OUT=.dev/welcome.png
	@mkdir -p .dev
	@xcrun simctl ui '$(SIM)' appearance $(THEME)
	@sleep 2
	@xcrun simctl io '$(SIM)' screenshot $(or $(OUT),.dev/shot-$(THEME).png)

clean:
	@rm -r $(DERIVED) 2>/dev/null || true
