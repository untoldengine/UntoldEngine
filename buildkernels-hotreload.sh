#!/bin/bash

cd Sources/UntoldEngine/UntoldEngineKernels

xcrun -sdk macosx metal UntoldEngineKernels.metal -c -o UntoldEngineKernels.air

# Create a timestamp
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

# Define output filename with timestamp
outputFile="$HOME/Downloads/UntoldEngineKernels_$timestamp.metallib"

# Link the .air file into a .metallib with the timestamped name
xcrun -sdk macosx metallib UntoldEngineKernels.air -o "$outputFile"
