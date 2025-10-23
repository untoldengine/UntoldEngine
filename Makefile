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

# Lint Swift files using SwiftFormat
lint:
	swiftformat --lint . --swiftversion 5.8 --reporter github-actions-log

# Auto-format Swift files (for convenience)
format:
	swiftformat . --swiftversion 5.8 --quiet
