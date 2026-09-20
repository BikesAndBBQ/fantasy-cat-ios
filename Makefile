# One command each, so neither a person nor an agent has to remember xcodebuild's flags.
SCHEME  := FantasyCat
BUNDLE  := co.fantasycat.app
SIM     ?= iPhone 18 Pro
DERIVED := build
APP     := $(DERIVED)/Build/Products/Debug-iphonesimulator/$(SCHEME).app
THEME   ?= dark
XCB     := xcodebuild -project $(SCHEME).xcodeproj -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DERIVED)

.PHONY: build test run shot tokens clean

build: ## compile for the Simulator; warnings are printed, errors fail
	@$(XCB) -quiet build

test:
	@$(XCB) -quiet test

run: build ## install and launch in the Simulator
	@xcrun simctl boot '$(SIM)' 2>/dev/null || true
	@xcrun simctl install '$(SIM)' $(APP)
	@xcrun simctl terminate '$(SIM)' $(BUNDLE) 2>/dev/null || true
	@xcrun simctl launch '$(SIM)' $(BUNDLE) $(if $(GALLERY),-gallery)

shot: run ## screenshot the running app: make shot THEME=light OUT=.dev/welcome.png [GALLERY=1]
	@mkdir -p .dev
	@xcrun simctl ui '$(SIM)' appearance $(THEME)
	@sleep 2
	@xcrun simctl io '$(SIM)' screenshot $(or $(OUT),.dev/shot-$(THEME).png)

tokens: ## regenerate Design/Tokens.swift from the server repo's resolved tokens
	@python3 scripts/gen-tokens.py

clean:
	@rm -r $(DERIVED) 2>/dev/null || true
