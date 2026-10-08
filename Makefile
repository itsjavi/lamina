INSTALL_DIR ?= /Applications

.PHONY: app dev run run-dev test test-ui metrics metrics-web install release appcast bump clean

app: ## Build build/Lamina.app (release, with the updater)
	scripts/build-app.sh release

dev: ## Build build/Lamina Dev.app (debug, separate id, sandbox container and prefs, no updater)
	scripts/build-app.sh dev

run: app ## Build and open the release app
	open build/Lamina.app

run-dev: dev ## Build and open the dev app
	open "build/Lamina Dev.app"

test: ## Run the unit tests, except those that take focus or show windows
	swift test

test-ui: ## Run every test, including those that take focus or show windows (CI does)
	LAMINA_UI_TESTS=1 swift test

metrics: build/metrics ## Measure size, launch time and memory, record them in brand/metrics.json and compare with the last record
	build/metrics

metrics-web: build/metrics ## Write the latest recorded metrics into the website's cards (web/index.html)
	build/metrics --web

# Compiled optimized: interpreted, the script's timing loop adds tenths of a second to every launch it measures.
build/metrics: scripts/metrics.swift
	@mkdir -p build
	swiftc -O scripts/metrics.swift -o build/metrics

install: app ## Copy the release app to /Applications (quits the running copy first) and open it
	-osascript -e 'tell application id "com.itsjavi.lamina" to quit' 2>/dev/null
	rm -rf "$(INSTALL_DIR)/Lamina.app"
	cp -R build/Lamina.app "$(INSTALL_DIR)/"
	open "$(INSTALL_DIR)/Lamina.app"

# Apple silicon app, zip and DMG in build/release; signs and notarizes when
# DEVELOPER_ID and NOTARY_PROFILE are set (see scripts/release.sh).
release:
	scripts/release.sh

# Signs build/release's zip (EdDSA key "lamina" from the Keychain) and updates build/appcast/appcast.xml.
appcast:
	scripts/appcast.sh

# Bumps VERSION, commits and tags it: make bump V=patch|minor|major|X.Y.Z [PUSH=1]
bump:
	scripts/bump-version.sh $(V) $(if $(PUSH),--push)

clean: ## Remove build outputs
	rm -rf .build build
