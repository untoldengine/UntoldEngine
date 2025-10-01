//
//  RenderPipeLines.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import UntoldEngine

// MARK: Gizmo Pipeline
public func InitGizmoPipeline() -> RenderPipeline? {
    return CreatePipeline(
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
    return CreatePipeline(
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

extension RenderPipelineType {
    public static let gizmo : RenderPipelineType = "gizmo"
    public static let debug : RenderPipelineType = "debug"
}

public func EditorDefaultPipeLines() -> [(RenderPipelineType, RenderPipelineInitBlock)] {
    return DefaultPipeLines() + [
        ( .gizmo, InitGizmoPipeline),
        ( .debug, InitDebugPipeline)
    ]
}
