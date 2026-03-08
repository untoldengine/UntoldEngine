//
//  RenderPipelineType.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
    static let colorCorrection: RenderPipelineType = "colorCorrection"
    static let bloomThreshold: RenderPipelineType = "bloomThreshold"
    static let bloomComposite: RenderPipelineType = "bloomComposite"
    static let vignette: RenderPipelineType = "vignette"
    static let chromaticAberration: RenderPipelineType = "chromaticAberration"
    static let depthOfField: RenderPipelineType = "depthOfField"
    static let ssao: RenderPipelineType = "ssao"
    static let ssaoBlur: RenderPipelineType = "ssaoBlur"
    static let ssaoBilateralBlur: RenderPipelineType = "ssaoBilateralBlur"
    static let ssaoUpsample: RenderPipelineType = "ssaoUpsample"
    static let environment: RenderPipelineType = "environment"
    static let iblPreFilter: RenderPipelineType = "iblPreFilter"
    static let gaussian: RenderPipelineType = "gaussian"
    static let spatialDebug: RenderPipelineType = "spatialDebug"
    static let look: RenderPipelineType = "look"
    static let outputTransform: RenderPipelineType = "outputTransform"
    static let transparency: RenderPipelineType = "transparency"
}
