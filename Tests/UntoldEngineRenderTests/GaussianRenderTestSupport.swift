//
//  GaussianRenderTestSupport.swift
//  UntoldEngine
//
//  Shared readback and comparison helpers for the Gaussian render tests: render one frame and
//  read the splat layer, compare two layers over the pixels they cover, read the shared
//  working set's count.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// PSNR over the covered pixels and the number of pixels where any channel differs by more
/// than one 8-bit step.
struct GaussianLayerComparison {
    let psnr: Float
    let differingPixels: Int
    let covered: Int
}

extension BaseRenderSetup {
    /// Renders one frame, waits for its command buffer, and returns the splat layer
    /// (premultiplied colour and alpha, rgba16Float).
    func renderGaussianSplatLayer() -> [Float16] {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
        let texture = renderInfo.gaussianRenderPassDescriptor.colorAttachments[0].texture!
        var pixels = [Float16](repeating: 0, count: texture.width * texture.height * 4)
        texture.getBytes(&pixels, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        return pixels
    }

    /// Compares two splat layers over the pixels either of them covers. The old entity-order
    /// blending measured about 56 dB over the whole (mostly empty) frame on the test asset, so
    /// bounds on this measure have to be far tighter than that.
    func compareGaussianSplatLayers(_ a: [Float16], _ b: [Float16]) -> GaussianLayerComparison {
        var sum: Double = 0
        var covered = 0
        var differing = 0
        for i in stride(from: 0, to: min(a.count, b.count), by: 4) {
            guard Float(a[i + 3]) > 0.001 || Float(b[i + 3]) > 0.001 else { continue }
            covered += 1
            var maxDelta: Float = 0
            for c in 0 ..< 4 {
                let d = Float(a[i + c]) - Float(b[i + c])
                sum += Double(d * d)
                maxDelta = max(maxDelta, abs(d))
            }
            if maxDelta > 1.0 / 255.0 {
                differing += 1
            }
        }
        let mse = covered == 0 ? 0 : sum / Double(covered * 4)
        return GaussianLayerComparison(psnr: mse == 0 ? .infinity : Float(10 * log10(1 / mse)), differingPixels: differing, covered: covered)
    }

    /// The shared working set's visible count for the current in-flight slot.
    func sharedGaussianVisibleCount() -> Int {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        return Int(GaussianSharedWorkingSet.shared.visibleSet(slot: slot)!.contents().load(as: GaussianVisibleSet.self).visibleCount)
    }

    /// A camera entity looking from `eye` at `target`, made the active camera.
    @discardableResult
    func placeGaussianTestCamera(eye: simd_float3, target: simd_float3 = .zero, up: simd_float3 = simd_float3(0, 1, 0)) -> EntityID {
        let cameraEntity = createEntity()
        if let cameraComponent = scene.assign(to: cameraEntity, component: CameraComponent.self) {
            CameraSystem.shared.activeCamera = cameraEntity
            cameraComponent.viewSpace = matrix_identity_float4x4
            cameraComponent.localPosition = .zero
        }
        cameraLookAt(entityId: cameraEntity, eye: eye, target: target, up: up)
        return cameraEntity
    }
}
