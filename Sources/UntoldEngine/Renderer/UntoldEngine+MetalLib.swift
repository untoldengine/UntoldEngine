//
//  UntoldEngine+MetalLib.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 22/9/25.
//

import MetalKit

extension MTLDevice
{
    func makeLibraryFromBundle() throws -> MTLLibrary? {
                        
        #if os(macOS)
        let resourceName = "UntoldEngineKernels"
        #elseif os(iOS) && !targetEnvironment(simulator)
        let resourceName = "UntoldEngineKernels-ios"
        #elseif os(iOS) && targetEnvironment(simulator)
        let resourceName = "UntoldEngineKernels-iossim"
        #endif
            // elseif os(xrOS)
            // let libraryURL=Bundle.main.url(forResource: "UntoldEngineKernels-xros", withExtension: "metallib")
            // elseif os(xrOS)
                
        let libraryURL = Bundle.module.url(forResource: resourceName, withExtension: "metallib")
        
        if let libURL = libraryURL {
            Logger.log(message: "Loading Metal Library from Bundle: \(libURL)")
            return try self.makeLibrary(URL: libURL)
        }
        
        Logger.logError(message: "No Metal Library found with name: \(resourceName)")
        throw LoadError.metalLibraryNotFound("No Metal Library found with name: \(resourceName)")
    }
}
