//
//  UntoldEngine+MetalLib.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit

extension MTLDevice {
    func makeLibraryFromBundle() throws -> MTLLibrary? {
        #if os(macOS)
            let resourceName = "UntoldEngineKernels"
        #elseif os(iOS) && !targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-ios"
        #elseif os(iOS) && targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-iossim"
        #elseif os(tvOS) && !targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-tvos"
        #elseif os(tvOS) && targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-tvossim"
        #elseif os(xrOS) && !targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-xros"
        #elseif os(xrOS) && targetEnvironment(simulator)
            let resourceName = "UntoldEngineKernels-xrossim"
        #endif

        // Bundle.main is checked first: it's where a signed/notarized macOS .app that flattens
        // UntoldEngine's resources into Contents/Resources will have them. The filesystem check
        // is a fallback for cases where Bundle.main's resource index misses a file that is
        // actually present. Bundle.untoldEngineModuleResourceURL covers the unflattened case
        // (swift run/swift test/CLI tools, and the nested layout on iOS/tvOS/visionOS) without
        // the crash risk of the SwiftPM-generated Bundle.module accessor -- see
        // Bundle+ResourceFallback.swift.
        let libraryURL = Bundle.main.url(forResource: resourceName, withExtension: "metallib")
            ?? Bundle.mainResourceURLByPath(forResource: resourceName, withExtension: "metallib")
            ?? Bundle.untoldEngineModuleResourceURL(forResource: resourceName, withExtension: "metallib")

        if let libURL = libraryURL {
            Logger.log(message: "Loading Metal Library from Bundle: \(libURL)")
            return try makeLibrary(URL: libURL)
        }

        handleError(.metalLibraryNotFound, resourceName)
        throw ErrorHandlingSystem.metalLibraryNotFound
    }
}
