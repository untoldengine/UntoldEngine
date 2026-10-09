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

# Honor UNTOLD_PYTHON so the interpreter we install into matches the one
# BaseRenderSetup actually shells out to at test time (default: python3).
TESTRENDERER_PYTHON ?= $(if $(UNTOLD_PYTHON),$(UNTOLD_PYTHON),python3)

# --break-system-packages only exists in pip 23.0.1+. Xcode's bundled Python
# (pip 21.2.4 as of this writing) rejects it as an unknown option, which aborts
# the target before it can even upgrade pip. Detect support instead of
# hardcoding the flag so Homebrew/python.org pips (which need it under PEP 668)
# keep working while older pips fall back to an unflagged install.
PIP_BREAK_FLAG := $(shell $(TESTRENDERER_PYTHON) -m pip install --help 2>/dev/null | grep -q -- --break-system-packages && echo --break-system-packages)

testrenderer:
	$(TESTRENDERER_PYTHON) -m pip install --user $(PIP_BREAK_FLAG) --upgrade pip wheel setuptools
	$(TESTRENDERER_PYTHON) -m pip install --user $(PIP_BREAK_FLAG) opencv-python-headless scikit-image
	UNTOLD_KEEP_ARTIFACTS=$(KEEP) swift test --parallel --num-workers $(WORKERS) --filter UntoldEngineRenderTests

# AsyncMeshLoadingTest/AssetLoadingGateRenderingTests only — the two classes CI runs
# serially, without --parallel, in their own step (see ci-build-test.yml) because they
# hang on the CI runner otherwise. Mirrors that exact invocation so a local pass/fail
# is directly comparable, without paying for the full testrenderer suite or its PSNR
# pip installs (neither class does image comparison).
testrenderer-async:
	swift test --disable-swift-testing --filter 'UntoldEngineRenderTests.(AsyncMeshLoadingTest|AssetLoadingGateRenderingTests)'

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
