//
//  EditorRenderPipeLines.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import UntoldEngine

// MARK: Gizmo Pipeline

public func InitGizmoPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGizmoShader",
        fragmentShader: "fragmentGizmoShader",
        vertexDescriptor: createGizmoVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Gizmo Pipeline"
    )
}

// MARK: Debug Pipeline

public func InitDebugPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexDebugShader",
        fragmentShader: "fragmentDebugShader",
        vertexDescriptor: createDebugVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "Debug Pipeline"
    )
}

public extension RenderPipelineType {
    static let gizmo: RenderPipelineType = "gizmo"
    static let debug: RenderPipelineType = "debug"
}

public func EditorDefaultPipeLines() -> [(RenderPipelineType, RenderPipelineInitBlock)] {
    DefaultPipeLines() + [
        (.gizmo, InitGizmoPipeline),
        (.debug, InitDebugPipeline),
    ]
}
