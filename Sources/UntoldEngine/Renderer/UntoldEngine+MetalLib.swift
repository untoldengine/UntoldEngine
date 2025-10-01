//
//  UntoldEngine+MetalLib.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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

        Logger.logError(message: "No Metal Library found with name: \(resourceName)")
        throw ErrorHandlingSystem.metalLibraryNotFound
    }
}
