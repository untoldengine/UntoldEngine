#!/bin/bash

cd Sources/UntoldEngine/UntoldEngineKernels

# mac (device)
xcrun -sdk macosx metal UntoldEngineKernels.metal -c -o UntoldEngineKernels.air

xcrun -sdk macosx metallib UntoldEngineKernels.air -o UntoldEngineKernels.metallib

# iOS (device)
xcrun -sdk iphoneos metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-ios.air

xcrun -sdk iphoneos metallib UntoldEngineKernels-ios.air -o UntoldEngineKernels-ios.metallib

# iOS (simulator)

xcrun -sdk iphonesimulator metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-ios.air

xcrun -sdk iphonesimulator metallib UntoldEngineKernels-ios.air -o UntoldEngineKernels-ios.metallib
