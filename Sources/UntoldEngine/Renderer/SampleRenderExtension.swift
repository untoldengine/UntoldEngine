//
//  SampleRenderExtension.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd

/// Minimal opt-in render extension used as a reference implementation.
///
/// The extension allocates a viewport-sized scratch texture and clears it from
/// a staged graph pass. It intentionally does not write to the scene output.
public final class SampleRenderExtension: RenderExtension, @unchecked Sendable {
    public let id: String
    public let passID: String
    public let scratchTextureID: String
    public let stage: RenderStage
    public let clearColor: SIMD4<Double>

    public init(
        id: String = "sample.renderExtension",
        passID: String = "sample.renderExtension.clearScratch",
        scratchTextureID: String = "sample.renderExtension.scratch",
        stage: RenderStage = .beforeOutput,
        clearColor: SIMD4<Double> = SIMD4<Double>(0.0, 0.0, 0.0, 0.0)
    ) {
        self.id = id
        self.passID = passID
        self.scratchTextureID = scratchTextureID
        self.stage = stage
        self.clearColor = clearColor
    }

    public func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: scratchTextureID,
                label: "Sample Render Extension Scratch",
                size: .viewportScale(1.0),
                pixelFormat: .rgba16Float,
                usage: [.renderTarget, .shaderRead]
            )
        )
    }

    public func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: passID,
            stage: stage,
            resources: [
                .texture(RenderTextureResourceID(scratchTextureID), access: .renderTarget),
            ]
        ) { [scratchTextureID, clearColor] context in
            guard let scratchTexture = context.resources.texture(scratchTextureID) else {
                return
            }

            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = scratchTexture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = MTLClearColorMake(
                clearColor.x,
                clearColor.y,
                clearColor.z,
                clearColor.w
            )

            guard let encoder = context.commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }
            encoder.label = "Sample Render Extension Scratch Clear"
            encoder.endEncoding()
        }
    }
}
