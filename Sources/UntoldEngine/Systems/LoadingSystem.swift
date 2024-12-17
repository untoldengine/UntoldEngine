
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func getResourceURL(forResource resourceName: String, withExtension ext: String) -> URL? {
    // First, check Bundle.module for the resource
    if let url = Bundle.module.url(forResource: resourceName, withExtension: ext) {
        return url
    }

    // If not found in Bundle.module, check Bundle.main
    return Bundle.main.url(forResource: resourceName, withExtension: ext)
}
