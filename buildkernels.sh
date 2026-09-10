#!/bin/bash

# Builds the engine's Metal library for every platform the package supports. The deployment
# target of each build is pinned to the package's (Package.swift: macOS 14, iOS 17, visionOS 2;
# tvOS 17): without the flag the metal compiler stamps the library with the SDK's own version,
# and a metallib built by a newer Xcode then fails to load on any older OS the package still
# supports (an older CI runner, a headset on the previous release).

set -e

# Earlier versions of this script left .air intermediates in the kernels directory, which
# SwiftPM flags as unhandled files; clear any stale ones from an existing checkout first.
rm -f Sources/UntoldEngine/UntoldEngineKernels/*.air

cd Sources/UntoldEngine/UntoldEngineKernels

# .air files are compiler intermediates that embed this machine's paths; keep them out of the package tree.
airDir="${TMPDIR:-/tmp}"

MACOS_MIN=14.0
IOS_MIN=17.0
TVOS_MIN=17.0
XROS_MIN=2.0

# mac (device)
xcrun -sdk macosx metal -mmacosx-version-min=$MACOS_MIN UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels.air"

xcrun -sdk macosx metallib "$airDir/UntoldEngineKernels.air" -o UntoldEngineKernels.metallib

# iOS (device)
xcrun -sdk iphoneos metal -mios-version-min=$IOS_MIN UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-ios.air"

xcrun -sdk iphoneos metallib "$airDir/UntoldEngineKernels-ios.air" -o UntoldEngineKernels-ios.metallib

# iOS (simulator)

xcrun -sdk iphonesimulator metal -mtargetos=ios$IOS_MIN-simulator UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-iossim.air"

xcrun -sdk iphonesimulator metallib "$airDir/UntoldEngineKernels-iossim.air" -o UntoldEngineKernels-iossim.metallib

# tvOS (device)

xcrun -sdk appletvos metal -mtvos-version-min=$TVOS_MIN UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-tvos.air"

xcrun -sdk appletvos metallib "$airDir/UntoldEngineKernels-tvos.air" -o UntoldEngineKernels-tvos.metallib

# tvOS (simulator)

xcrun -sdk appletvsimulator metal -mtargetos=tvos$TVOS_MIN-simulator UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-tvossim.air"

xcrun -sdk appletvsimulator metallib "$airDir/UntoldEngineKernels-tvossim.air" -o UntoldEngineKernels-tvossim.metallib

# visionOS (device)

xcrun -sdk xros metal -mtargetos=xros$XROS_MIN UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-xros.air"

xcrun -sdk xros metallib "$airDir/UntoldEngineKernels-xros.air" -o UntoldEngineKernels-xros.metallib

# visionOS (simulator)

xcrun -sdk xrsimulator metal -mtargetos=xros$XROS_MIN-simulator UntoldEngineKernels.metal -c -o "$airDir/UntoldEngineKernels-xrossim.air"

xcrun -sdk xrsimulator metallib "$airDir/UntoldEngineKernels-xrossim.air" -o UntoldEngineKernels-xrossim.metallib
