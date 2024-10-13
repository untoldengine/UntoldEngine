# Makefile for UntoldEngine

# Default target - compile shaders and then build the swift package

all: compile-shaders build 

# Compile the .metal files into a .metallib

compile-shaders:
#	sh ./buildkernels.sh

# Build the Swift package

build:
	swift build

# Clean build artifact

clean:
	swift package clean 

# Test target 
test:
	swift test 
