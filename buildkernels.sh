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

# tvOS (device)

xcrun -sdk appletvos metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-tvos.air

xcrun -sdk appletvos metallib UntoldEngineKernels-tvos.air -o UntoldEngineKernels-tvos.metallib

# tvOS (simulator)

xcrun -sdk appletvsimulator metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-tvossim.air

xcrun -sdk appletvsimulator metallib UntoldEngineKernels-tvossim.air -o UntoldEngineKernels-tvossim.metallib

# visionOS (device)

xcrun -sdk xros metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-xros.air

xcrun -sdk xros metallib UntoldEngineKernels-xros.air -o UntoldEngineKernels-xros.metallib

# visionOS (simulator)

xcrun -sdk xrsimulator metal UntoldEngineKernels.metal -c -o UntoldEngineKernels-xrossim.air

xcrun -sdk xrsimulator metallib UntoldEngineKernels-xrossim.air -o UntoldEngineKernels-xrossim.metallib
