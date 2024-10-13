#!/bin/bash

cd Sources/UntoldEngine/UntoldEngineKernels

xcrun -sdk macosx metal UntoldEngineKernels.metal -c -o UntoldEngineKernels.air

xcrun -sdk macosx metallib UntoldEngineKernels.air -o UntoldEngineKernels.metallib
