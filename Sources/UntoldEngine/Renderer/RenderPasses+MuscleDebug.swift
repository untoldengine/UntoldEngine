//
//  RenderPasses+MuscleDebug.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

public extension RenderPasses {
    /// Draws every simulated muscle cage as wireframe lines over the lit
    /// scene (edges coloured green → red by activation, grey when the muscle
    /// is disabled, bone capsules in cyan), plus the world-space line sets
    /// registered with `setDebugLines(_:named:)`. Reads back the last
    /// simulated particle positions from the shared buffers; a tuning aid,
    /// not a shipping feature. Cages enabled with `setMuscleDebugOverlay(enabled:)`.
    static let muscleDebugExecution: RenderPassExecution = { commandBuffer in
        let system = DeformationSystem.shared
        let debugLineSets = DebugLineStore.shared.snapshot()
        guard system.muscleDebugOverlayEnabled || !debugLineSets.isEmpty else { return }
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.spatialDebug],
              pipeline.success, let pipelineState = pipeline.pipelineState
        else { return }
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera),
              let encoderDescriptor = renderInfo.deferredRenderPassDescriptor
        else { return }

        struct Batch {
            let color: simd_float4
            let model: simd_float4x4
            let vertexStart: Int
            let vertexCount: Int
        }
        var vertices: [simd_float4] = []
        var batches: [Batch] = []

        let entities = system.muscleDebugOverlayEnabled
            ? queryEntities(with: [DeformationComponent.self, SkeletonComponent.self])
            : []
        for entityId in entities {
            guard let component = scene.get(component: DeformationComponent.self, for: entityId),
                  component.musclesEnabled,
                  let state = component.muscleSim,
                  let world = scene.get(component: WorldTransformComponent.self, for: entityId)?.space
            else { continue }

            let positions = UnsafeBufferPointer(
                start: state.currentPositions.contents().bindMemory(to: simd_float4.self, capacity: state.particleCount),
                count: state.particleCount
            )
            let frameParams = UnsafeBufferPointer(
                start: state.currentMuscleParams.contents().bindMemory(to: MuscleFrameParams.self, capacity: state.muscleCount),
                count: state.muscleCount
            )
            let geometry = state.geometry

            // Edges, one batch per muscle so the colour can follow activation.
            var edgesByMuscle = [[MuscleEdge]](repeating: [], count: geometry.muscles.count)
            for edge in geometry.edges {
                edgesByMuscle[Int(geometry.particleInfos[Int(edge.a)].muscleIndex)].append(edge)
            }
            for (muscleIndex, muscle) in geometry.muscles.enumerated() {
                let start = vertices.count
                for edge in edgesByMuscle[muscleIndex] {
                    let a = positions[Int(edge.a)]
                    let b = positions[Int(edge.b)]
                    vertices.append(simd_float4(a.x, a.y, a.z, 1))
                    vertices.append(simd_float4(b.x, b.y, b.z, 1))
                }
                let activation = state.activations[muscleIndex]
                let color: simd_float4 = component.disabledMuscles.contains(muscle.definition.name)
                    ? simd_float4(0.5, 0.5, 0.5, 1)
                    : simd_float4(activation, 1 - activation, 0.1, 1)
                batches.append(Batch(color: color, model: world, vertexStart: start, vertexCount: vertices.count - start))
            }

            // Bone capsules: the axis plus four lines at the collision radius.
            let capsuleStart = vertices.count
            for muscleIndex in 0 ..< state.muscleCount where muscleIndex < frameParams.count {
                let params = frameParams[muscleIndex]
                for (c0, c1) in [(params.capsuleA0, params.capsuleA1), (params.capsuleB0, params.capsuleB1)] {
                    let radius = c0.w
                    guard radius > 0 else { continue }
                    let start = simd_float3(c0.x, c0.y, c0.z)
                    let end = simd_float3(c1.x, c1.y, c1.z)
                    let axis = end - start
                    guard simd_length_squared(axis) > 1e-10 else { continue }
                    let direction = simd_normalize(axis)
                    let helper = abs(direction.y) < 0.9 ? simd_float3(0, 1, 0) : simd_float3(1, 0, 0)
                    let u = simd_normalize(simd_cross(direction, helper))
                    let v = simd_cross(direction, u)
                    vertices.append(simd_float4(start, 1))
                    vertices.append(simd_float4(end, 1))
                    for offset in [u, -u, v, -v] {
                        vertices.append(simd_float4(start + offset * radius, 1))
                        vertices.append(simd_float4(end + offset * radius, 1))
                    }
                }
            }
            if vertices.count > capsuleStart {
                batches.append(Batch(
                    color: simd_float4(0.2, 0.9, 1.0, 1), model: world,
                    vertexStart: capsuleStart, vertexCount: vertices.count - capsuleStart
                ))
            }
        }

        // Registered world-space lines: one batch per run of equal colour.
        for segments in debugLineSets {
            var batchStart = vertices.count
            var batchColor = segments[0].color
            for segment in segments {
                if segment.color != batchColor {
                    batches.append(Batch(color: batchColor, model: matrix_identity_float4x4, vertexStart: batchStart, vertexCount: vertices.count - batchStart))
                    batchStart = vertices.count
                    batchColor = segment.color
                }
                vertices.append(simd_float4(segment.start, 1))
                vertices.append(simd_float4(segment.end, 1))
            }
            batches.append(Batch(color: batchColor, model: matrix_identity_float4x4, vertexStart: batchStart, vertexCount: vertices.count - batchStart))
        }

        guard !vertices.isEmpty else { return }
        let requiredLength = vertices.count * MemoryLayout<simd_float4>.stride
        if system.muscleDebugLineBuffer == nil || (system.muscleDebugLineBuffer?.length ?? 0) < requiredLength {
            system.muscleDebugLineBuffer = renderInfo.device.makeBuffer(length: max(requiredLength * 2, 4096), options: .storageModeShared)
            system.muscleDebugLineBuffer?.label = "Muscle Debug Line Buffer"
        }
        guard let lineBuffer = system.muscleDebugLineBuffer else { return }
        vertices.withUnsafeBytes { raw in
            guard let source = raw.baseAddress else { return }
            lineBuffer.contents().copyMemory(from: source, byteCount: requiredLength)
        }

        encoderDescriptor.colorAttachments[0].loadAction = .load
        encoderDescriptor.colorAttachments[0].storeAction = .store
        encoderDescriptor.depthAttachment.loadAction = .load
        encoderDescriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor) else {
            handleError(.renderPassCreationFailed, "Muscle Debug Pass")
            return
        }
        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
        renderEncoder.label = "Muscle Debug Pass"
        renderEncoder.pushDebugGroup("Muscle Debug Pass")
        renderEncoder.setRenderPipelineState(pipelineState)
        // The cages live under the skin, so never depth-test them. In visionOS
        // mixed immersion the compositor drops pixels that wrote no depth, so
        // there the lines must write theirs (same reason as the wireframe pass).
        if let depthState = system.muscleDebugDepthState(
            device: renderInfo.device, writeDepth: renderInfo.immersionStyle == .mixed
        ) {
            renderEncoder.setDepthStencilState(depthState)
        }
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        renderEncoder.setCullMode(.none)

        var viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        var projectionMatrix = renderInfo.perspectiveSpace
        var scale = simd_float3(repeating: 1.0)
        renderEncoder.setVertexBuffer(lineBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 1)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        renderEncoder.setVertexBytes(&scale, length: MemoryLayout<simd_float3>.stride, index: 4)

        for batch in batches where batch.vertexCount > 0 {
            var model = batch.model
            var color = batch.color
            renderEncoder.setVertexBytes(&model, length: MemoryLayout<simd_float4x4>.stride, index: 3)
            renderEncoder.setFragmentBytes(&color, length: MemoryLayout<simd_float4>.stride, index: 0)
            renderEncoder.drawPrimitivesTracked(
                type: .line, vertexStart: batch.vertexStart, vertexCount: batch.vertexCount, category: .other
            )
        }
        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }
}

/// Shows or hides the muscle cage wireframe overlay for every simulated
/// entity (a placement-tuning aid).
public func setMuscleDebugOverlay(enabled: Bool) {
    DeformationSystem.shared.muscleDebugOverlayEnabled = enabled
}
