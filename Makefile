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

testexporter:
	python3 -m unittest discover -s scripts/tests -t . -v

testcore:
	swift test --filter UntoldEngineTests

# Empirically validated on an 18-core/24GB M5 Pro: --num-workers 4 gave a 3-4x
# wall-clock speedup on both light and heavy (memory-budget-stressing) renderer
# suites with zero failures. Override with `make testrenderer WORKERS=1` if your
# machine has less RAM/GPU headroom.
WORKERS ?= 4

testrenderer:
	python3 -m pip install --user --break-system-packages --upgrade pip wheel setuptools
	python3 -m pip install --user --break-system-packages opencv-python-headless scikit-image
	UNTOLD_KEEP_ARTIFACTS=$(KEEP) swift test --parallel --num-workers $(WORKERS) --filter UntoldEngineRenderTests

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
