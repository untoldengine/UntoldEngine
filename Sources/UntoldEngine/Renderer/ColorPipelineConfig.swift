
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

public enum OutputEncodingMode: Int32, Sendable {
    case hardwareSRGB = 0
    case manualSRGBOETF = 1
    case hdrPassthrough = 2
}

public struct WorkingColorFormats: Sendable {
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

    #if targetEnvironment(simulator)
        /// The simulator caps combined render-target storage at 32 bytes/pixel/sample.
        /// The TBDR deferred pass keeps all 6 attachments (G-buffer 0-4 + sceneColor)
        /// live in tile memory, so the device set (44 bytes) exceeds the cap. This set
        /// totals exactly 32: albedo 4 + normal 4 (snorm keeps sign, shaders read
        /// half4 unchanged) + position 8 + material 4 + emissive 4 (unorm clamps HDR
        /// emissive — simulator-only quality loss; rg11b10Float is charged 8 bytes by
        /// the simulator's validator) + sceneColor 8.
        public static let standard = WorkingColorFormats(
            gBufferAlbedo: .rgba8Unorm,
            gBufferNormal: .rgba8Snorm,
            gBufferPosition: .rgba16Float,
            gBufferMaterial: .rgba8Unorm,
            gBufferEmissive: .rgba8Unorm,
            sceneColor: .rgba16Float,
            postProcess: .rgba16Float,
            sceneComposite: .rgba16Float,
            lookOutput: .rgba16Float,
            environment: .rgba16Float,
            gaussian: .rgba16Float,
            gizmo: .rgba16Float,
            ibl: .rgba16Float
        )
    #else
        public static let standard = WorkingColorFormats(
            gBufferAlbedo: .rgba16Float,
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
    #endif
}

public struct PresentOutputConfig: Sendable {
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

public struct ColorPipelineConfig: Sendable {
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

    /// The non-sRGB sibling format, or self if already linear. MPS kernels can
    /// read an sRGB texture but cannot write to one ("must be writable" assertion),
    /// so compute-written destinations must be allocated in this format instead of
    /// the source's raw pixelFormat.
    var mpsWritableFormat: MTLPixelFormat {
        switch self {
        case .bgra8Unorm_srgb: return .bgra8Unorm
        case .rgba8Unorm_srgb: return .rgba8Unorm
        default: return self
        }
    }
}
