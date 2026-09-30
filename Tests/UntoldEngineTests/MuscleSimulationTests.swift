//
//  MuscleSimulationTests.swift
//  UntoldEngineTests
//
//  Headless GPU tests for the XPBD muscle kernels.
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

final class MuscleSimulationTests: XCTestCase {
    private struct Pipelines {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let predict: MTLComputePipelineState
        let gradient: MTLComputePipelineState
        let solve: MTLComputePipelineState
        let skinWrap: MTLComputePipelineState
    }

    private func makePipelines() throws -> Pipelines {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        guard let library = try device.makeLibraryFromBundle() else {
            throw XCTSkip("Engine metallib unavailable")
        }
        guard let predict = library.makeFunction(name: "musclePredict"),
              let gradient = library.makeFunction(name: "muscleVolumeGradient"),
              let solve = library.makeFunction(name: "muscleSolve"),
              let skinWrap = library.makeFunction(name: "muscleSkinWrap"),
              let queue = device.makeCommandQueue()
        else {
            throw XCTSkip("muscle kernels missing from engine metallib — regenerate via buildkernels.sh")
        }
        return try Pipelines(
            device: device,
            queue: queue,
            predict: device.makeComputePipelineState(function: predict),
            gradient: device.makeComputePipelineState(function: gradient),
            solve: device.makeComputePipelineState(function: solve),
            skinWrap: device.makeComputePipelineState(function: skinWrap)
        )
    }

    /// Bends the elbow to `angle` (about +Z through the elbow) and returns the
    /// per-muscle frame params, mirroring DeformationSystem.makeFrameParams.
    private func frameParams(
        geometry: MuscleBakedGeometry,
        elbowAngle: Float,
        activation: Float,
        substepDelta: Float
    ) -> [MuscleFrameParams] {
        let muscle = geometry.muscles[0]
        let elbow = simd_float3(0.3, 1, 0)
        let rotation = simd_quatf(angle: elbowAngle, axis: simd_float3(0, 0, 1))
        var forearmPose = simd_float4x4(rotation)
        let rotatedElbow = rotation.act(elbow)
        forearmPose.columns.3 = simd_float4(elbow - rotatedElbow, 1) // rotate about the elbow
        let upperArmPose = matrix_identity_float4x4

        func transform(_ matrix: simd_float4x4, _ point: simd_float3) -> simd_float3 {
            let p = matrix * simd_float4(point, 1)
            return simd_float3(p.x, p.y, p.z)
        }
        let originCurrent = transform(upperArmPose, muscle.originRest)
        let insertionCurrent = transform(forearmPose, muscle.insertionRest)
        let axis = insertionCurrent - originCurrent
        let dt2 = substepDelta * substepDelta
        let definition = muscle.definition
        return [MuscleFrameParams(
            originJoint: upperArmPose,
            insertionJoint: forearmPose,
            referenceRotation: simd_float4x4(simd_quatf(from: muscle.restAxis, to: simd_normalize(axis))),
            originCurrent: simd_float4(originCurrent, muscle.restLength),
            insertionCurrent: simd_float4(insertionCurrent, simd_length(axis)),
            capsuleA0: simd_float4(transform(upperArmPose, muscle.originBone.start), definition.boneRadius),
            capsuleA1: simd_float4(transform(upperArmPose, muscle.originBone.end), 0),
            capsuleB0: simd_float4(transform(forearmPose, muscle.insertionBone.start), definition.boneRadius),
            capsuleB1: simd_float4(transform(forearmPose, muscle.insertionBone.end), 0),
            fiberScale: 1 - definition.maxContraction * activation,
            fiberAlpha: definition.fiberCompliance / dt2,
            crossAlpha: definition.crossCompliance / dt2,
            volumeAlpha: definition.volumeCompliance / dt2,
            damping: definition.damping,
            skinWeight: 1,
            restVolume: muscle.restVolume,
            pad0: 0,
            particleStart: UInt32(muscle.particleRange.lowerBound),
            particleCount: UInt32(muscle.particleRange.count),
            pad1: 0, pad2: 0
        )]
    }

    private func encodeFrame(
        _ pipelines: Pipelines,
        state: MuscleSimState,
        params: [MuscleFrameParams],
        substepDelta: Float
    ) {
        let commandBuffer = pipelines.queue.makeCommandBuffer()!
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        MuscleSimulator.encodeFrame(
            encoder: encoder,
            pipelines: MusclePipelines(
                predict: pipelines.predict, volumeGradient: pipelines.gradient,
                solve: pipelines.solve, skinWrap: pipelines.skinWrap
            ),
            state: state,
            frameParams: params,
            substepDelta: substepDelta,
            gravity: simd_float3(0, -2, 0),
            reset: false
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    private func readPositions(_ state: MuscleSimState) -> [simd_float4] {
        let pointer = state.currentPositions.contents().bindMemory(to: simd_float4.self, capacity: state.particleCount)
        return Array(UnsafeBufferPointer(start: pointer, count: state.particleCount))
    }

    private func totalVolume(_ geometry: MuscleBakedGeometry, positions: [simd_float4]) -> Float {
        MuscleGeometryBuilder.surfaceVolume(geometry.triangles[...], positions: positions)
    }

    /// 600 frames of an elbow curl with rising activation: the cage keeps its
    /// volume within 2%, never produces NaNs, and bulges at the belly.
    func testCurlKeepsVolumeAndBulges() throws {
        let pipelines = try makePipelines()
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        let geometry = try XCTUnwrap(MuscleGeometryBuilder.bake(rig: MuscleGeometryTests.makeBicepsRig(), skeleton: skeleton))
        let state = try XCTUnwrap(MuscleSimState(geometry: geometry, device: pipelines.device, label: "test"))
        let restVolume = totalVolume(geometry, positions: geometry.initialPositions)
        XCTAssertGreaterThan(restVolume, 0)

        let frameDelta: Float = 1.0 / 90.0
        let substepDelta = frameDelta / Float(muscleSubstepsPerFrame)
        let initial = frameParams(geometry: geometry, elbowAngle: 0, activation: 0, substepDelta: substepDelta)
        state.resetPositions(MuscleSimulator.referencePositions(state: state, frameParams: initial))

        var maxDrift: Float = 0
        var bellyRadiusRelaxed: Float = 0
        var bellyRadiusFlexed: Float = 0
        let muscle = geometry.muscles[0]
        let bellyRing = (muscle.definition.rings / 2) * (muscle.definition.segments + 1)

        func bellyRadius(_ positions: [simd_float4]) -> Float {
            let center = positions[bellyRing]
            var sum: Float = 0
            for slot in 1 ... muscle.definition.segments {
                let p = positions[bellyRing + slot]
                sum += simd_length(simd_float3(p.x - center.x, p.y - center.y, p.z - center.z))
            }
            return sum / Float(muscle.definition.segments)
        }

        for frame in 0 ..< 600 {
            let progress = min(Float(frame) / 300, 1)
            let angle = progress * 1.9
            let activation = min(max((angle - 0.2) / 1.7, 0), 1)
            let params = frameParams(geometry: geometry, elbowAngle: angle, activation: activation, substepDelta: substepDelta)
            encodeFrame(pipelines, state: state, params: params, substepDelta: substepDelta)

            if frame == 60 || frame == 599 {
                let positions = readPositions(state)
                XCTAssertTrue(positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite }, "NaN at frame \(frame)")
                let drift = abs(totalVolume(geometry, positions: positions) - restVolume) / restVolume
                maxDrift = max(maxDrift, drift)
                if frame == 60 {
                    bellyRadiusRelaxed = bellyRadius(positions)
                } else {
                    bellyRadiusFlexed = bellyRadius(positions)
                }
            }
        }

        XCTAssertLessThan(maxDrift, 0.02, "tet volume drifted \(maxDrift * 100)%")
        XCTAssertGreaterThan(bellyRadiusFlexed, bellyRadiusRelaxed * 1.05, "activation must bulge the belly")
    }

    /// A relaxed muscle in the bind pose adds nothing to the skin; a flexed
    /// one moves a bound vertex outward and keeps the normal unit length.
    func testSkinWrapAddsSimulatedDelta() throws {
        let pipelines = try makePipelines()
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        let geometry = try XCTUnwrap(MuscleGeometryBuilder.bake(rig: MuscleGeometryTests.makeBicepsRig(), skeleton: skeleton))
        let state = try XCTUnwrap(MuscleSimState(geometry: geometry, device: pipelines.device, label: "test"))
        let muscle = geometry.muscles[0]
        let frameDelta: Float = 1.0 / 90.0
        let substepDelta = frameDelta / Float(muscleSubstepsPerFrame)

        let belly = muscle.originRest + muscle.restAxis * (muscle.restLength * 0.5)
        let skinPoint = belly + simd_float3(0, 0, 1) * (muscle.definition.bellyRadius * 0.6)
        let bindings = MuscleGeometryBuilder.bindSkin(positions: [simd_float4(skinPoint, 1)], geometry: geometry)
        XCTAssertNotEqual(bindings[0].tetIndex, MUSCLE_SKIN_UNBOUND)

        let device = pipelines.device
        let bindingBuffer = bindings.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)! }
        var skinPositions = [simd_float4(skinPoint, 1)]
        var skinNormals = [simd_float4(0, 0, 1, 0)]
        var skinTangents = [simd_float4(1, 0, 0, 1)]
        let positionBuffer = skinPositions.withUnsafeMutableBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)! }
        let normalBuffer = skinNormals.withUnsafeMutableBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)! }
        let tangentBuffer = skinTangents.withUnsafeMutableBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)! }

        func runWrap() -> (position: simd_float3, normal: simd_float3) {
            var simParams = MuscleSimParams(
                particleCount: UInt32(state.particleCount), skinVertexCount: 1, dt: 0, relaxation: 0,
                gravity: simd_float4(0, 0, 0, 0), maxVelocity: 0, pad0: 0, pad1: 0, pad2: 0
            )
            positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: 1)[0] = simd_float4(skinPoint, 1)
            normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: 1)[0] = simd_float4(0, 0, 1, 0)
            let commandBuffer = pipelines.queue.makeCommandBuffer()!
            let encoder = commandBuffer.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(pipelines.skinWrap)
            encoder.setBuffer(positionBuffer, offset: 0, index: Int(musclePassSkinPositionsIndex.rawValue))
            encoder.setBuffer(normalBuffer, offset: 0, index: Int(musclePassSkinNormalsIndex.rawValue))
            encoder.setBuffer(tangentBuffer, offset: 0, index: Int(musclePassSkinTangentsIndex.rawValue))
            encoder.setBuffer(bindingBuffer, offset: 0, index: Int(musclePassSkinBindingIndex.rawValue))
            encoder.setBuffer(state.currentPositions, offset: 0, index: Int(musclePassPositionsIndex.rawValue))
            encoder.setBuffer(state.particleInfo, offset: 0, index: Int(musclePassParticleInfoIndex.rawValue))
            encoder.setBuffer(state.tets, offset: 0, index: Int(musclePassTetsIndex.rawValue))
            encoder.setBuffer(state.currentMuscleParams, offset: 0, index: Int(musclePassMuscleParamsIndex.rawValue))
            encoder.setBytes(&simParams, length: MemoryLayout<MuscleSimParams>.stride, index: Int(musclePassParamsIndex.rawValue))
            encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1))
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            let p = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: 1)[0]
            let n = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: 1)[0]
            return (simd_float3(p.x, p.y, p.z), simd_float3(n.x, n.y, n.z))
        }

        // Relaxed: the simulated cage equals the reference, so the delta is zero.
        let relaxed = frameParams(geometry: geometry, elbowAngle: 0, activation: 0, substepDelta: substepDelta)
        state.resetPositions(MuscleSimulator.referencePositions(state: state, frameParams: relaxed))
        state.writeMuscleParams { pointer in pointer[0] = relaxed[0] }
        let relaxedResult = runWrap()
        XCTAssertLessThan(simd_length(relaxedResult.position - skinPoint), 1e-5)

        // Flexed in place (no bend): the belly bulges, pushing the vertex outward.
        let flexed = frameParams(geometry: geometry, elbowAngle: 0, activation: 1, substepDelta: substepDelta)
        for _ in 0 ..< 120 {
            encodeFrame(pipelines, state: state, params: flexed, substepDelta: substepDelta)
        }
        let flexedResult = runWrap()
        XCTAssertGreaterThan(flexedResult.position.z, skinPoint.z + 1e-4, "bulge must push the skin outward")
        XCTAssertEqual(simd_length(flexedResult.normal), 1, accuracy: 1e-4)
        XCTAssertGreaterThan(flexedResult.normal.z, 0.9)
    }
}
