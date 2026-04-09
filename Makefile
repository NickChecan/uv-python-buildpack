APP_DIR := test/smoke/my-app-1
BUILD_DIR := /tmp/uv-bp-build
CACHE_DIR := /tmp/uv-bp-cache
ENV_DIR := /tmp/uv-bp-env
ROOT_DIR := $(CURDIR)
BUILDPACK_DIR := $(ROOT_DIR)
PYTHON_BIN ?= python3

.PHONY: test-buildpack clean-test-buildpack test-detect test-compile test-release smoke-test start-local

# Reset the temporary staging directories used for local buildpack testing.
clean-test-buildpack:
	rm -rf $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)

# Run unit tests for the detect script without requiring external test tooling.
test-detect:
	@bash ./test/unit/detect_test.sh

# Run unit tests for the compile script with stubbed python and uv commands.
test-compile:
	@bash ./test/unit/compile_test.sh

# Run unit tests for the release script command-resolution logic.
test-release:
	@bash ./test/unit/release_test.sh

# Run the sample app through detect, compile, and release using the same
# temporary directories each time so local testing is repeatable.
test-buildpack: clean-test-buildpack
	mkdir -p $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)
	cp -R $(APP_DIR)/. $(BUILD_DIR)
	# Run detect from the fixture app directory, but use the buildpack script from the repo root.
	cd $(APP_DIR) && $(BUILDPACK_DIR)/bin/detect
	$(BUILDPACK_DIR)/bin/compile $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)
	# Confirm staged dependencies are importable before checking the release metadata.
	cd $(BUILD_DIR) && /bin/bash -lc 'source .profile.d/python.sh && $(PYTHON_BIN) -c "import fastapi; print(fastapi.__version__)"'
	cd $(BUILD_DIR) && $(BUILDPACK_DIR)/bin/release

# Run the single-app smoke test target against every app fixture under test/smoke.
smoke-test:
	@./scripts/smoke-test.sh

# Start the staged sample app locally using the dependencies prepared by `test-buildpack`.
start-local:
	@cd $(BUILD_DIR) && /bin/bash -lc '\
		source .profile.d/python.sh && \
		# Prefer the app Procfile, otherwise reuse the buildpack release logic. \
		if [ -f Procfile ]; then \
			WEB_CMD=$$(awk -F": " '\''$$1 == "web" { print $$2; exit }'\'' Procfile); \
		else \
			WEB_CMD=$$($(BUILDPACK_DIR)/bin/release | awk -F": " '\''$$1 ~ /web/ { print $$2; exit }'\''); \
		fi; \
		if [ -z "$$WEB_CMD" ]; then \
			echo "Could not determine a web command to run locally."; \
			exit 1; \
		fi; \
		# Local machines often expose `python3` instead of `python`, so normalize that here. \
		WEB_CMD=$$(printf "%s" "$$WEB_CMD" | sed "s/^python /$(PYTHON_BIN) /"); \
		eval "$$WEB_CMD"'
