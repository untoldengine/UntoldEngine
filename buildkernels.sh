#!/bin/bash

# Earlier versions of this script left .air intermediates in the kernels directory, which
# SwiftPM flags as unhandled files; clear any stale ones from an existing checkout first.
rm -f Sources/UntoldEngine/UntoldEngineKernels/*.air

cd Sources/UntoldEngine/UntoldEngineKernels

# .air files are compiler intermediates that embed this machine's paths; keep them out of the package tree.
airDir="${TMPDIR:-/tmp}"

# mac (device)
xcrun -sdk macosx metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels.air"

xcrun -sdk macosx metallib "$airDir/UntoldEngineKernels.air" -o UntoldEngineKernels.metallib

# iOS (device)
xcrun -sdk iphoneos metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-ios.air"

xcrun -sdk iphoneos metallib "$airDir/UntoldEngineKernels-ios.air" -o UntoldEngineKernels-ios.metallib

# iOS (simulator)

xcrun -sdk iphonesimulator metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-iossim.air"

xcrun -sdk iphonesimulator metallib "$airDir/UntoldEngineKernels-iossim.air" -o UntoldEngineKernels-iossim.metallib

# tvOS (device)

xcrun -sdk appletvos metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-tvos.air"

xcrun -sdk appletvos metallib "$airDir/UntoldEngineKernels-tvos.air" -o UntoldEngineKernels-tvos.metallib

# tvOS (simulator)

xcrun -sdk appletvsimulator metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-tvossim.air"

xcrun -sdk appletvsimulator metallib "$airDir/UntoldEngineKernels-tvossim.air" -o UntoldEngineKernels-tvossim.metallib

# visionOS (device)

xcrun -sdk xros metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-xros.air"

xcrun -sdk xros metallib "$airDir/UntoldEngineKernels-xros.air" -o UntoldEngineKernels-xros.metallib

# visionOS (simulator)

xcrun -sdk xrsimulator metal UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-xrossim.air"

xcrun -sdk xrsimulator metallib "$airDir/UntoldEngineKernels-xrossim.air" -o UntoldEngineKernels-xrossim.metallib
