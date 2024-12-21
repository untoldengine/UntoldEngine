
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
    // First, check Bundle.main for the resourc
    if let mainBundleUrl = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        return mainBundleUrl
    }

    // else search in bundle module
    return Bundle.module.url(forResource: resourceName, withExtension: ext)
}
