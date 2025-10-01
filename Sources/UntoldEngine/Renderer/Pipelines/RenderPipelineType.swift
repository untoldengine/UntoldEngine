//
//  RenderPipelineType.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

public struct RenderPipelineType: Hashable, ExpressibleByStringLiteral {
    let rawValue: String
    
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

extension RenderPipelineType {
    public static let grid               : RenderPipelineType = "grid"
    public static let shadow             : RenderPipelineType = "shadow"
    public static let model              : RenderPipelineType = "model"
    public static let light              : RenderPipelineType = "light"
    public static let geometry           : RenderPipelineType = "geometry"
    public static let highlight          : RenderPipelineType = "highlight"
    public static let lightVisual        : RenderPipelineType = "lightVisual"
    public static let outline            : RenderPipelineType = "outline"
    public static let composite          : RenderPipelineType = "composite"
    public static let preComposite       : RenderPipelineType = "preComposite"
    public static let tonemapping        : RenderPipelineType = "tonemapping"
    public static let blur               : RenderPipelineType = "blur"
    public static let colorGrading       : RenderPipelineType = "colorGrading"
    public static let colorCorrection    : RenderPipelineType = "colorCorrection"
    public static let bloomThreshold     : RenderPipelineType = "bloomThreshold"
    public static let bloomComposite     : RenderPipelineType = "bloomComposite"
    public static let vignette           : RenderPipelineType = "vignette"
    public static let chromaticAberration: RenderPipelineType = "chromaticAberration"
    public static let depthOfField       : RenderPipelineType = "depthOfField"
    public static let ssao               : RenderPipelineType = "ssao"
    public static let ssaoBlur           : RenderPipelineType = "ssaoBlur"
    public static let environment        : RenderPipelineType = "environment"
    public static let iblPreFilter       : RenderPipelineType = "iblPreFilter"
}
