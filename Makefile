APP_DIR := test/my-app
BUILD_DIR := /tmp/uv-bp-build
CACHE_DIR := /tmp/uv-bp-cache
ENV_DIR := /tmp/uv-bp-env
ROOT_DIR := $(CURDIR)
BUILDPACK_DIR := $(ROOT_DIR)
PYTHON_BIN ?= python3

.PHONY: test-buildpack clean-test-buildpack start-local

# Reset the temporary staging directories used for local buildpack testing.
clean-test-buildpack:
	rm -rf $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)

# Run the sample app through detect, compile, and release using the same
# temporary directories each time so local testing is repeatable.
test-buildpack: clean-test-buildpack
	mkdir -p $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)
	cp -R $(APP_DIR)/. $(BUILD_DIR)
	cd $(APP_DIR) && ../../bin/detect
	$(BUILDPACK_DIR)/bin/compile $(BUILD_DIR) $(CACHE_DIR) $(ENV_DIR)
	cd $(BUILD_DIR) && /bin/bash -lc 'source .profile.d/python.sh && $(PYTHON_BIN) -c "import fastapi; print(fastapi.__version__)"'
	cd $(BUILD_DIR) && $(BUILDPACK_DIR)/bin/release

# Start the staged sample app locally using the dependencies prepared by `test-buildpack`.
start-local:
	cd $(BUILD_DIR) && /bin/bash -lc 'source .profile.d/python.sh && $(PYTHON_BIN) main.py'
