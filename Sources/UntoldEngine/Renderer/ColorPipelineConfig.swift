
//
//  ColorPipelineConfig.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import MetalKit

public enum OutputEncodingMode: Int32 {
    case hardwareSRGB = 0
    case manualSRGBOETF = 1
    case hdrPassthrough = 2
}

public struct WorkingColorFormats {
    public var gBufferAlbedo: MTLPixelFormat
    public var gBufferNormal: MTLPixelFormat
    public var gBufferPosition: MTLPixelFormat
    public var gBufferMaterial: MTLPixelFormat
    public var gBufferEmissive: MTLPixelFormat

    public var sceneColor: MTLPixelFormat
    public var postProcess: MTLPixelFormat
    public var sceneComposite: MTLPixelFormat
    public var lookOutput: MTLPixelFormat

    public var environment: MTLPixelFormat
    public var gaussian: MTLPixelFormat
    public var gizmo: MTLPixelFormat
    public var ibl: MTLPixelFormat

    public static let standard = WorkingColorFormats(
        gBufferAlbedo: .rgba8Unorm_srgb,
        gBufferNormal: .rgba16Float,
        gBufferPosition: .rgba16Float,
        gBufferMaterial: .rgba8Unorm,
        gBufferEmissive: .rgba16Float,
        sceneColor: .rgba16Float,
        postProcess: .rgba16Float,
        sceneComposite: .rgba16Float,
        lookOutput: .rgba16Float,
        environment: .rgba16Float,
        gaussian: .rgba16Float,
        gizmo: .rgba16Float,
        ibl: .rgba16Float
    )
}

public struct PresentOutputConfig {
    public var pixelFormat: MTLPixelFormat
    public var encodingMode: OutputEncodingMode

    public init(pixelFormat: MTLPixelFormat) {
        self.pixelFormat = pixelFormat
        if pixelFormat.isSRGBFormat {
            encodingMode = .hardwareSRGB
        } else {
            encodingMode = .manualSRGBOETF
        }
    }
}

public struct ColorPipelineConfig {
    public var working: WorkingColorFormats
    public var present: PresentOutputConfig

    public static func standard(presentFormat: MTLPixelFormat) -> ColorPipelineConfig {
        ColorPipelineConfig(
            working: .standard,
            present: .init(pixelFormat: presentFormat)
        )
    }
}

public extension MTLPixelFormat {
    var isSRGBFormat: Bool {
        switch self {
        case .bgra8Unorm_srgb, .rgba8Unorm_srgb:
            return true
        default:
            return false
        }
    }
}
