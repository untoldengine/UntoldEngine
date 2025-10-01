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
    public init(stringLiteral value: String) { rawValue = value }
}

public extension RenderPipelineType {
    static let grid: RenderPipelineType = "grid"
    static let shadow: RenderPipelineType = "shadow"
    static let model: RenderPipelineType = "model"
    static let light: RenderPipelineType = "light"
    static let geometry: RenderPipelineType = "geometry"
    static let highlight: RenderPipelineType = "highlight"
    static let lightVisual: RenderPipelineType = "lightVisual"
    static let outline: RenderPipelineType = "outline"
    static let composite: RenderPipelineType = "composite"
    static let preComposite: RenderPipelineType = "preComposite"
    static let tonemapping: RenderPipelineType = "tonemapping"
    static let blur: RenderPipelineType = "blur"
    static let colorGrading: RenderPipelineType = "colorGrading"
    static let colorCorrection: RenderPipelineType = "colorCorrection"
    static let bloomThreshold: RenderPipelineType = "bloomThreshold"
    static let bloomComposite: RenderPipelineType = "bloomComposite"
    static let vignette: RenderPipelineType = "vignette"
    static let chromaticAberration: RenderPipelineType = "chromaticAberration"
    static let depthOfField: RenderPipelineType = "depthOfField"
    static let ssao: RenderPipelineType = "ssao"
    static let ssaoBlur: RenderPipelineType = "ssaoBlur"
    static let environment: RenderPipelineType = "environment"
    static let iblPreFilter: RenderPipelineType = "iblPreFilter"
}
