# One command each, so neither a person nor an agent has to remember xcodebuild's flags.
SCHEME  := FantasyCat
BUNDLE  := co.fantasycat.app
SIM     ?= iPhone 18 Pro
DERIVED := build
APP     := $(DERIVED)/Build/Products/Debug-iphonesimulator/$(SCHEME).app
THEME   ?= dark
XCB     := xcodebuild -project $(SCHEME).xcodeproj -scheme $(SCHEME) -destination 'platform=iOS Simulator,name=$(SIM)' -derivedDataPath $(DERIVED)

.PHONY: build test run shot tokens api console clean

build: ## compile for the Simulator; warnings are printed, errors fail
	@$(XCB) -quiet build

test:
	@$(XCB) -quiet test

run: build ## install and launch in the Simulator
	@xcrun simctl boot '$(SIM)' 2>/dev/null || true
	@xcrun simctl install '$(SIM)' $(APP)
	@xcrun simctl terminate '$(SIM)' $(BUNDLE) 2>/dev/null || true
	@xcrun simctl launch '$(SIM)' $(BUNDLE) $(if $(GALLERY),-gallery) $(ARGS)

shot: run ## screenshot the running app: make shot THEME=light OUT=.dev/welcome.png [GALLERY=1] [ARGS='-api http://localhost:8080']
	@mkdir -p .dev
	@xcrun simctl ui '$(SIM)' appearance $(THEME)
	@sleep $(or $(WAIT),2)
	@xcrun simctl io '$(SIM)' screenshot $(or $(OUT),.dev/shot-$(THEME).png)

tokens: ## regenerate Design/Tokens.swift from the server repo's resolved tokens
	@python3 scripts/gen-tokens.py

api: ## regenerate the API client from the server repo's OpenAPI spec
	@cp ../fantasy-cat/web/openapi.json Tools/openapi/openapi.json
	@cd Tools/openapi && swift run -c release swift-openapi-generator generate openapi.json --config openapi-generator-config.yaml --output-directory ../../FantasyCat/API/Generated 2>&1 | grep -i "error\|warning" || true
	@echo "api: regenerated FantasyCat/API/Generated from ../fantasy-cat/web/openapi.json"

console: build ## run in the Simulator with the app's print() output in this terminal
	@xcrun simctl boot '$(SIM)' 2>/dev/null || true
	@xcrun simctl install '$(SIM)' $(APP)
	@xcrun simctl terminate '$(SIM)' $(BUNDLE) 2>/dev/null || true
	@xcrun simctl launch --console-pty '$(SIM)' $(BUNDLE) $(ARGS)

clean:
	@rm -r $(DERIVED) 2>/dev/null || true
