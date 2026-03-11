# Makefile for UntoldEngine

# Default target - compile shaders and then build the swift package

all: compile-shaders build 

# Compile the .metal files into a .metallib

compile-shaders:
	sh ./buildkernels.sh

# hot reload
hot-reload-shaders:
	sh ./buildkernels-hotreload.sh

# Build the Swift package

build:
	swift build

# Build with strict Swift concurrency diagnostics and emit a migration report
strict-concurrency-check:
	bash ./scripts/strict-concurrency-guardrails.sh

# Clean build artifact

clean:
	swift package clean 

# Test target 
test:
	swift test

testcore:
	swift test --filter UntoldEngineTests

testrenderer:
	python3 -m pip install --user --break-system-packages --upgrade pip wheel setuptools
	python3 -m pip install --user --break-system-packages opencv-python-headless scikit-image
	UNTOLD_KEEP_ARTIFACTS=$(KEEP) swift test --parallel --num-workers 1 --filter UntoldEngineRenderTests

# Required SwiftFormat version
SWIFTFORMAT_VERSION := 0.60.1

# Verify installed SwiftFormat matches the required version
check-swiftformat-version:
	@INSTALLED=$$(swiftformat --version 2>&1 | awk '{print $$NF}'); \
	if [ "$$INSTALLED" != "$(SWIFTFORMAT_VERSION)" ]; then \
		echo "Error: swiftformat $(SWIFTFORMAT_VERSION) required, but found $$INSTALLED"; \
		echo "Install from: https://github.com/nicklockwood/SwiftFormat/releases/tag/$(SWIFTFORMAT_VERSION)"; \
		exit 1; \
	fi

# Lint Swift files using SwiftFormat
lint: check-swiftformat-version
	swiftformat --lint . --swiftversion 5.8 --reporter github-actions-log

# Auto-format Swift files (for convenience)
format: check-swiftformat-version
	swiftformat . --swiftversion 5.8 --quiet
