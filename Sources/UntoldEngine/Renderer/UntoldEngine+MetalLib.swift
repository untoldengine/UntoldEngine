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

        let libraryURL = Bundle.module.url(forResource: resourceName, withExtension: "metallib")

        if let libURL = libraryURL {
            Logger.log(message: "Loading Metal Library from Bundle: \(libURL)")
            return try makeLibrary(URL: libURL)
        }

        handleError(.metalLibraryNotFound, resourceName)
        throw ErrorHandlingSystem.metalLibraryNotFound
    }
}
