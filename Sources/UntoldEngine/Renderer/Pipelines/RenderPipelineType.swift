//
//  RenderPipelineType.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public struct RenderPipelineType: Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public extension RenderPipelineType {
    static let grid: RenderPipelineType = "grid"
    static let sky: RenderPipelineType = "sky"
    static let shadow: RenderPipelineType = "shadow"
    /// The shadow pipeline for instanced draws: casters that share their meshes, one draw.
    static let shadowInstanced: RenderPipelineType = "shadowInstanced"
    static let model: RenderPipelineType = "model"
    /// The model pipeline compiled without fragment discards, for the opaque draws that never
    /// need them: the GPU resolves visibility before shading them.
    static let modelOpaque: RenderPipelineType = "modelOpaque"
    /// The model pipeline for instanced draws: entities that share their meshes and
    /// materials, one draw.
    static let modelInstanced: RenderPipelineType = "modelInstanced"
    /// The instanced model pipeline compiled without fragment discards, as `modelOpaque`.
    static let modelInstancedOpaque: RenderPipelineType = "modelInstancedOpaque"
    static let light: RenderPipelineType = "light"
    /// The TBDR light pass as a tile stage: lights each pixel once per colour it holds.
    static let lightTile: RenderPipelineType = "lightTile"
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
    static let iblSpecularPreFilter: RenderPipelineType = "iblSpecularPreFilter"
    static let xrIBLCubePreFilter: RenderPipelineType = "xrIBLCubePreFilter"
    static let xrIBLCubeSpecularPreFilter: RenderPipelineType = "xrIBLCubeSpecularPreFilter"
    static let gaussianTBDRInitialize: RenderPipelineType = "gaussianTBDRInitialize"
    static let gaussianTBDRDraw: RenderPipelineType = "gaussianTBDRDraw"
    static let gaussianTBDRPostprocess: RenderPipelineType = "gaussianTBDRPostprocess"
    static let spatialDebug: RenderPipelineType = "spatialDebug"
    static let look: RenderPipelineType = "look"
    static let outputTransform: RenderPipelineType = "outputTransform"
    static let fxaa: RenderPipelineType = "fxaa"
    static let fxaaEdgeDebug: RenderPipelineType = "fxaaEdgeDebug"
    static let taa: RenderPipelineType = "taa"
    /// The temporal resolve that also presents the frame (history, display colour, depth).
    static let taaPresent: RenderPipelineType = "taaPresent"
    /// The look pass that also presents the frame (look output, display colour, depth).
    static let lookPresent: RenderPipelineType = "lookPresent"
    static let smaaEdges: RenderPipelineType = "smaaEdges"
    static let smaaBlendWeights: RenderPipelineType = "smaaBlendWeights"
    static let smaaNeighborhood: RenderPipelineType = "smaaNeighborhood"
    static let smaaDifference: RenderPipelineType = "smaaDifference"
    static let transparency: RenderPipelineType = "transparency"
    static let wireframe: RenderPipelineType = "wireframe"
    static let wireframeOcclusionDepth: RenderPipelineType = "wireframeOcclusionDepth"
    static let meshOccluderShell: RenderPipelineType = "meshOccluderShell"
    static let debug: RenderPipelineType = "debug"
}
