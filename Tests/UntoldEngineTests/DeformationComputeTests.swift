//
//  DeformationComputeTests.swift
//  UntoldEngineTests
//
//  Headless parity tests for the deformation compute kernels.
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

final class DeformationComputeTests: XCTestCase {
    /// deformSkinLBS must reproduce CPU linear blend skinning: blended joint
    /// matrix on positions, cofactor (inverse-transpose) on normals, rotation
    /// on tangents — within float tolerance.
    func testSkinLBSMatchesCPUReference() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        guard let library = try device.makeLibraryFromBundle() else {
            throw XCTSkip("Engine metallib unavailable")
        }
        guard let function = library.makeFunction(name: "deformSkinLBS") else {
            return XCTFail("deformSkinLBS missing from engine metallib — regenerate via buildkernels.sh")
        }
        let pipeline = try device.makeComputePipelineState(function: function)

        // Synthetic skinned mesh: a vertex strip influenced by four rigid joints.
        let vertexCount = 1024
        let jointCount = 4

        var jointMatrices: [simd_float4x4] = []
        for jointIndex in 0 ..< jointCount {
            let angle = Float(jointIndex) * 0.35 + 0.2
            let axis = simd_normalize(simd_float3(0.2, 1.0, Float(jointIndex) * 0.1 - 0.15))
            let rotation = simd_float4x4(simd_quatf(angle: angle, axis: axis))
            var matrix = rotation
            matrix.columns.3 = simd_float4(
                Float(jointIndex) * 0.5 - 0.75, Float(jointIndex) * -0.25, 0.3, 1.0
            )
            jointMatrices.append(matrix)
        }

        var positions: [simd_float4] = []
        var normals: [simd_float4] = []
        var tangents: [simd_float4] = []
        var jointIndices: [simd_ushort4] = []
        var jointWeights: [simd_float4] = []

        var seed: UInt64 = 0x5DEF_02F4
        func nextUnitFloat() -> Float {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(seed >> 40) / Float(1 << 24)
        }

        for vertexIndex in 0 ..< vertexCount {
            positions.append(simd_float4(
                nextUnitFloat() * 2 - 1, nextUnitFloat() * 2 - 1, nextUnitFloat() * 2 - 1, 1
            ))
            let normal = simd_normalize(simd_float3(
                nextUnitFloat() * 2 - 1, nextUnitFloat() * 2 - 1, nextUnitFloat() * 2 - 1
            ))
            normals.append(simd_float4(normal, 0))
            let tangent = simd_normalize(simd_cross(normal, simd_float3(0, 1, 0.2)))
            tangents.append(simd_float4(tangent, vertexIndex % 2 == 0 ? 1 : -1))

            let joint0 = UInt16(vertexIndex % jointCount)
            let joint1 = UInt16((vertexIndex + 1) % jointCount)
            jointIndices.append(simd_ushort4(joint0, joint1, 0, 0))
            let weight0 = 0.25 + 0.5 * nextUnitFloat()
            jointWeights.append(simd_float4(weight0, 1 - weight0, 0, 0))
        }
        // Exercise the zero-weight passthrough branch too.
        jointWeights[0] = simd_float4(repeating: 0)

        func makeBuffer(_ data: [some Any]) throws -> MTLBuffer {
            try data.withUnsafeBytes { bytes in
                try XCTUnwrap(device.makeBuffer(
                    bytes: bytes.baseAddress!,
                    length: bytes.count,
                    options: .storageModeShared
                ))
            }
        }

        let inPositions = try makeBuffer(positions)
        let inNormals = try makeBuffer(normals)
        let inTangents = try makeBuffer(tangents)
        let inJointIndices = try makeBuffer(jointIndices)
        let inJointWeights = try makeBuffer(jointWeights)
        let inJointMatrices = try makeBuffer(jointMatrices)
        let outLength = vertexCount * MemoryLayout<simd_float4>.stride
        let outPositions = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))
        let outNormals = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))
        let outTangents = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))

        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        let commandBuffer = try XCTUnwrap(commandQueue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commandBuffer.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(inPositions, offset: 0, index: Int(deformationPassInPositionIndex.rawValue))
        encoder.setBuffer(inNormals, offset: 0, index: Int(deformationPassInNormalIndex.rawValue))
        encoder.setBuffer(inTangents, offset: 0, index: Int(deformationPassInTangentIndex.rawValue))
        encoder.setBuffer(inJointIndices, offset: 0, index: Int(deformationPassJointIdIndex.rawValue))
        encoder.setBuffer(inJointWeights, offset: 0, index: Int(deformationPassJointWeightsIndex.rawValue))
        encoder.setBuffer(inJointMatrices, offset: 0, index: Int(deformationPassJointTransformIndex.rawValue))
        encoder.setBuffer(outPositions, offset: 0, index: Int(deformationPassOutPositionIndex.rawValue))
        encoder.setBuffer(outNormals, offset: 0, index: Int(deformationPassOutNormalIndex.rawValue))
        encoder.setBuffer(outTangents, offset: 0, index: Int(deformationPassOutTangentIndex.rawValue))
        var params = DeformationPassParams(vertexCount: UInt32(vertexCount), hasMorphDeltas: 0)
        encoder.setBytes(
            &params,
            length: MemoryLayout<DeformationPassParams>.stride,
            index: Int(deformationPassParamsIndex.rawValue)
        )
        let width = pipeline.threadExecutionWidth
        encoder.dispatchThreadgroups(
            MTLSize(width: (vertexCount + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        let gpuPositions = outPositions.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let gpuNormals = outNormals.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let gpuTangents = outTangents.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)

        var maxPositionError: Float = 0
        var maxNormalError: Float = 0
        var maxTangentError: Float = 0

        for vertexIndex in 0 ..< vertexCount {
            let weights = jointWeights[vertexIndex]
            let joints = jointIndices[vertexIndex]

            var expectedPosition = positions[vertexIndex]
            var expectedNormal = normals[vertexIndex]
            var expectedTangent = tangents[vertexIndex]

            let weightSum = weights.x + weights.y + weights.z + weights.w
            if weightSum > 0.0001 {
                var skinMatrix = weights.x * jointMatrices[Int(joints.x)]
                skinMatrix += weights.y * jointMatrices[Int(joints.y)]
                skinMatrix += weights.z * jointMatrices[Int(joints.z)]
                skinMatrix += weights.w * jointMatrices[Int(joints.w)]

                let rotation = simd_float3x3(
                    simd_float3(skinMatrix.columns.0.x, skinMatrix.columns.0.y, skinMatrix.columns.0.z),
                    simd_float3(skinMatrix.columns.1.x, skinMatrix.columns.1.y, skinMatrix.columns.1.z),
                    simd_float3(skinMatrix.columns.2.x, skinMatrix.columns.2.y, skinMatrix.columns.2.z)
                )
                let cofactor = simd_float3x3(
                    simd_cross(rotation.columns.1, rotation.columns.2),
                    simd_cross(rotation.columns.2, rotation.columns.0),
                    simd_cross(rotation.columns.0, rotation.columns.1)
                )

                let skinnedPosition = skinMatrix * simd_float4(
                    positions[vertexIndex].x, positions[vertexIndex].y, positions[vertexIndex].z, 1
                )
                expectedPosition = simd_float4(
                    skinnedPosition.x, skinnedPosition.y, skinnedPosition.z, positions[vertexIndex].w
                )
                expectedNormal = simd_float4(
                    simd_normalize(cofactor * simd_float3(
                        normals[vertexIndex].x, normals[vertexIndex].y, normals[vertexIndex].z
                    )),
                    normals[vertexIndex].w
                )
                expectedTangent = simd_float4(
                    simd_normalize(rotation * simd_float3(
                        tangents[vertexIndex].x, tangents[vertexIndex].y, tangents[vertexIndex].z
                    )),
                    tangents[vertexIndex].w
                )
            }

            maxPositionError = max(maxPositionError, simd_reduce_max(simd_abs(gpuPositions[vertexIndex] - expectedPosition)))
            maxNormalError = max(maxNormalError, simd_reduce_max(simd_abs(gpuNormals[vertexIndex] - expectedNormal)))
            maxTangentError = max(maxTangentError, simd_reduce_max(simd_abs(gpuTangents[vertexIndex] - expectedTangent)))
        }

        XCTAssertLessThan(maxPositionError, 1e-4, "GPU LBS positions diverge from CPU reference")
        XCTAssertLessThan(maxNormalError, 1e-4, "GPU LBS normals diverge from CPU reference")
        XCTAssertLessThan(maxTangentError, 1e-4, "GPU LBS tangents diverge from CPU reference")
    }

    /// The palette conversion must factor a rigid+scale matrix into a dual
    /// quaternion + scale that reconstructs the original transform, and
    /// single-influence DQS must match the plain matrix transform.
    func testSkinDQSSingleInfluenceMatchesMatrixTransform() throws {
        let context = try makeKernelContext()
        let paletteFunction = try XCTUnwrap(context.library.makeFunction(name: "deformDualQuatPalette"))
        let skinFunction = try XCTUnwrap(context.library.makeFunction(name: "deformSkinDQS"))
        let palettePipeline = try context.device.makeComputePipelineState(function: paletteFunction)
        let skinPipeline = try context.device.makeComputePipelineState(function: skinFunction)

        // Rigid joints with a uniform scale on one of them.
        var jointMatrices: [simd_float4x4] = []
        for jointIndex in 0 ..< 4 {
            let rotation = simd_float4x4(simd_quatf(
                angle: 0.4 + Float(jointIndex) * 0.9,
                axis: simd_normalize(simd_float3(0.3, 0.8, -0.2 + Float(jointIndex) * 0.3))
            ))
            var matrix = rotation
            if jointIndex == 2 {
                matrix.columns.0 *= 1.5
                matrix.columns.1 *= 1.5
                matrix.columns.2 *= 1.5
            }
            matrix.columns.3 = simd_float4(Float(jointIndex) * 0.4, 0.1, -0.2, 1)
            jointMatrices.append(matrix)
        }

        let vertexCount = 256
        var positions: [simd_float4] = []
        var normals: [simd_float4] = []
        var tangents: [simd_float4] = []
        var jointIndices: [simd_ushort4] = []
        var jointWeights: [simd_float4] = []
        for vertexIndex in 0 ..< vertexCount {
            let angle = Float(vertexIndex) * 0.13
            positions.append(simd_float4(cos(angle), sin(angle), Float(vertexIndex % 7) * 0.2, 1))
            let normal = simd_normalize(simd_float3(cos(angle * 1.3), 0.5, sin(angle * 0.7)))
            normals.append(simd_float4(normal, 0))
            tangents.append(simd_float4(simd_normalize(simd_cross(normal, simd_float3(0, 1, 0.1))), 1))
            jointIndices.append(simd_ushort4(UInt16(vertexIndex % 4), 0, 0, 0))
            jointWeights.append(simd_float4(1, 0, 0, 0))
        }

        let outputs = try dispatchSkinKernel(
            context: context,
            skinPipeline: skinPipeline,
            palettePipeline: palettePipeline,
            positions: positions, normals: normals, tangents: tangents,
            jointIndices: jointIndices, jointWeights: jointWeights,
            jointMatrices: jointMatrices, omegas: nil
        )

        var maxError: Float = 0
        for vertexIndex in 0 ..< vertexCount {
            let matrix = jointMatrices[Int(jointIndices[vertexIndex].x)]
            let expected = matrix * simd_float4(
                positions[vertexIndex].x, positions[vertexIndex].y, positions[vertexIndex].z, 1
            )
            maxError = max(maxError, simd_reduce_max(simd_abs(
                outputs.positions[vertexIndex] - simd_float4(expected.x, expected.y, expected.z, 1)
            )))
        }
        XCTAssertLessThan(maxError, 1e-3, "Single-influence DQS diverges from the matrix transform")
    }

    /// Direct Delta Mush must be exact for rigid motion: with every joint set
    /// to the same rigid transform, each vertex lands exactly at R*u + t
    /// (and passes through unchanged with identity matrices).
    func testSkinDDMIsRigidInvariant() throws {
        let context = try makeKernelContext()
        let function = try XCTUnwrap(context.library.makeFunction(name: "deformSkinDDM"))
        let pipeline = try context.device.makeComputePipelineState(function: function)

        // A small grid mesh split across two joints, with triangle topology
        // so the bake has a one-ring to smooth over.
        let side = 12
        var positions: [simd_float4] = []
        var normals: [simd_float4] = []
        var tangents: [simd_float4] = []
        var jointIndices: [simd_ushort4] = []
        var jointWeights: [simd_float4] = []
        for row in 0 ..< side {
            for column in 0 ..< side {
                positions.append(simd_float4(Float(column) * 0.1, Float(row) * 0.1, 0, 1))
                normals.append(simd_float4(0, 0, 1, 0))
                tangents.append(simd_float4(1, 0, 0, 1))
                let blend = Float(column) / Float(side - 1)
                jointIndices.append(simd_ushort4(0, 1, 0, 0))
                jointWeights.append(simd_float4(1 - blend, blend, 0, 0))
            }
        }
        var triangles: [UInt32] = []
        for row in 0 ..< side - 1 {
            for column in 0 ..< side - 1 {
                let i = UInt32(row * side + column)
                let right = i + 1
                let up = i + UInt32(side)
                let upRight = up + 1
                triangles.append(contentsOf: [i, right, up, right, upRight, up])
            }
        }

        let omegas = DDMPrecompute.bakeOmegas(input: DDMPrecomputeInput(
            positions: positions,
            jointIndices: jointIndices,
            jointWeights: jointWeights,
            triangleIndices: triangles
        ))

        let rotation = simd_quatf(angle: 0.7, axis: simd_normalize(simd_float3(0.2, 1, 0.4)))
        var rigid = simd_float4x4(rotation)
        rigid.columns.3 = simd_float4(0.3, -0.2, 0.5, 1)

        for (matrices, label) in [
            ([matrix_identity_float4x4, matrix_identity_float4x4], "identity"),
            ([rigid, rigid], "common rigid transform"),
        ] {
            let outputs = try dispatchSkinKernel(
                context: context,
                skinPipeline: pipeline,
                palettePipeline: nil,
                positions: positions, normals: normals, tangents: tangents,
                jointIndices: jointIndices, jointWeights: jointWeights,
                jointMatrices: matrices, omegas: omegas
            )

            var maxError: Float = 0
            for vertexIndex in 0 ..< positions.count {
                let expected = matrices[0] * simd_float4(
                    positions[vertexIndex].x, positions[vertexIndex].y, positions[vertexIndex].z, 1
                )
                maxError = max(maxError, simd_reduce_max(simd_abs(
                    outputs.positions[vertexIndex] - simd_float4(expected.x, expected.y, expected.z, 1)
                )))
            }
            XCTAssertLessThan(maxError, 1e-3, "DDM is not invariant under \(label)")
        }
    }

    /// Clear + accumulate + LBS with identity joints must yield base + delta.
    func testMorphAccumulateAppliesWeightedDeltas() throws {
        let context = try makeKernelContext()
        let clearPipeline = try context.device.makeComputePipelineState(
            function: XCTUnwrap(context.library.makeFunction(name: "deformClearMorphDeltas"))
        )
        let accumulatePipeline = try context.device.makeComputePipelineState(
            function: XCTUnwrap(context.library.makeFunction(name: "deformMorphAccumulate"))
        )
        let skinPipeline = try context.device.makeComputePipelineState(
            function: XCTUnwrap(context.library.makeFunction(name: "deformSkinLBS"))
        )

        let vertexCount = 8
        let positions = (0 ..< vertexCount).map { simd_float4(Float($0), 0, 0, 1) }
        let normals = [simd_float4](repeating: simd_float4(0, 0, 1, 0), count: vertexCount)
        let tangents = [simd_float4](repeating: simd_float4(1, 0, 0, 1), count: vertexCount)
        let jointIndices = [simd_ushort4](repeating: .init(0, 0, 0, 0), count: vertexCount)
        let jointWeights = [simd_float4](repeating: simd_float4(1, 0, 0, 0), count: vertexCount)
        let jointMatrices = [matrix_identity_float4x4]

        let delta = simd_float3(0.5, -0.25, 1.0)
        var entries = [MorphSparseEntry]()
        entries.append(MorphSparseEntry(
            vertexIndex: 3,
            dPosition: (Float16(delta.x).bitPattern, Float16(delta.y).bitPattern, Float16(delta.z).bitPattern),
            dNormal: (0, 0, 0)
        ))
        let weight: Float = 0.5

        func makeBuffer(_ data: [some Any]) throws -> MTLBuffer {
            try data.withUnsafeBytes { bytes in
                try XCTUnwrap(context.device.makeBuffer(
                    bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared
                ))
            }
        }
        let deltaLength = vertexCount * MemoryLayout<simd_float4>.stride
        let positionDeltas = try XCTUnwrap(context.device.makeBuffer(length: deltaLength, options: .storageModeShared))
        let normalDeltas = try XCTUnwrap(context.device.makeBuffer(length: deltaLength, options: .storageModeShared))
        let entryBuffer = try makeBuffer(entries)

        let inPositions = try makeBuffer(positions)
        let inNormals = try makeBuffer(normals)
        let inTangents = try makeBuffer(tangents)
        let inJointIndices = try makeBuffer(jointIndices)
        let inJointWeights = try makeBuffer(jointWeights)
        let inJointMatrices = try makeBuffer(jointMatrices)
        let outPositions = try XCTUnwrap(context.device.makeBuffer(length: deltaLength, options: .storageModeShared))
        let outNormals = try XCTUnwrap(context.device.makeBuffer(length: deltaLength, options: .storageModeShared))
        let outTangents = try XCTUnwrap(context.device.makeBuffer(length: deltaLength, options: .storageModeShared))

        let commandBuffer = try XCTUnwrap(context.commandQueue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commandBuffer.makeComputeCommandEncoder())

        encoder.setComputePipelineState(clearPipeline)
        encoder.setBuffer(positionDeltas, offset: 0, index: Int(morphPassPositionDeltaIndex.rawValue))
        encoder.setBuffer(normalDeltas, offset: 0, index: Int(morphPassNormalDeltaIndex.rawValue))
        var clearParams = MorphPassParams(entryOffset: 0, entryCount: 0, vertexCount: UInt32(vertexCount), weightTimesScale: 0)
        encoder.setBytes(&clearParams, length: MemoryLayout<MorphPassParams>.stride, index: Int(morphPassParamsIndex.rawValue))
        encoder.dispatchThreadgroups(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: vertexCount, height: 1, depth: 1)
        )

        encoder.setComputePipelineState(accumulatePipeline)
        encoder.setBuffer(entryBuffer, offset: 0, index: Int(morphPassEntriesIndex.rawValue))
        var accumulateParams = MorphPassParams(
            entryOffset: 0, entryCount: 1, vertexCount: UInt32(vertexCount), weightTimesScale: weight
        )
        encoder.setBytes(&accumulateParams, length: MemoryLayout<MorphPassParams>.stride, index: Int(morphPassParamsIndex.rawValue))
        encoder.dispatchThreadgroups(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: 1, height: 1, depth: 1)
        )

        encoder.setComputePipelineState(skinPipeline)
        encoder.setBuffer(inPositions, offset: 0, index: Int(deformationPassInPositionIndex.rawValue))
        encoder.setBuffer(inNormals, offset: 0, index: Int(deformationPassInNormalIndex.rawValue))
        encoder.setBuffer(inTangents, offset: 0, index: Int(deformationPassInTangentIndex.rawValue))
        encoder.setBuffer(inJointIndices, offset: 0, index: Int(deformationPassJointIdIndex.rawValue))
        encoder.setBuffer(inJointWeights, offset: 0, index: Int(deformationPassJointWeightsIndex.rawValue))
        encoder.setBuffer(inJointMatrices, offset: 0, index: Int(deformationPassJointTransformIndex.rawValue))
        encoder.setBuffer(positionDeltas, offset: 0, index: Int(deformationPassMorphPositionDeltaIndex.rawValue))
        encoder.setBuffer(normalDeltas, offset: 0, index: Int(deformationPassMorphNormalDeltaIndex.rawValue))
        encoder.setBuffer(outPositions, offset: 0, index: Int(deformationPassOutPositionIndex.rawValue))
        encoder.setBuffer(outNormals, offset: 0, index: Int(deformationPassOutNormalIndex.rawValue))
        encoder.setBuffer(outTangents, offset: 0, index: Int(deformationPassOutTangentIndex.rawValue))
        var skinParams = DeformationPassParams(vertexCount: UInt32(vertexCount), hasMorphDeltas: 1)
        encoder.setBytes(&skinParams, length: MemoryLayout<DeformationPassParams>.stride, index: Int(deformationPassParamsIndex.rawValue))
        encoder.dispatchThreadgroups(
            MTLSize(width: 1, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: vertexCount, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        let gpuPositions = outPositions.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        for vertexIndex in 0 ..< vertexCount {
            var expected = positions[vertexIndex]
            if vertexIndex == 3 {
                expected += simd_float4(delta * weight, 0)
            }
            XCTAssertLessThan(
                simd_reduce_max(simd_abs(gpuPositions[vertexIndex] - expected)), 2e-3,
                "vertex \(vertexIndex) morph mismatch"
            )
        }
    }

    // MARK: - Shared kernel harness

    private struct KernelContext {
        let device: MTLDevice
        let library: MTLLibrary
        let commandQueue: MTLCommandQueue
    }

    private struct SkinOutputs {
        let positions: [simd_float4]
        let normals: [simd_float4]
        let tangents: [simd_float4]
    }

    private func makeKernelContext() throws -> KernelContext {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        guard let library = try device.makeLibraryFromBundle() else {
            throw XCTSkip("Engine metallib unavailable")
        }
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        return KernelContext(device: device, library: library, commandQueue: commandQueue)
    }

    private func dispatchSkinKernel(
        context: KernelContext,
        skinPipeline: MTLComputePipelineState,
        palettePipeline: MTLComputePipelineState?,
        positions: [simd_float4],
        normals: [simd_float4],
        tangents: [simd_float4],
        jointIndices: [simd_ushort4],
        jointWeights: [simd_float4],
        jointMatrices: [simd_float4x4],
        omegas: [DDMOmegaEntry]?
    ) throws -> SkinOutputs {
        let device = context.device
        let vertexCount = positions.count

        func makeBuffer(_ data: [some Any]) throws -> MTLBuffer {
            try data.withUnsafeBytes { bytes in
                try XCTUnwrap(device.makeBuffer(
                    bytes: bytes.baseAddress!, length: bytes.count, options: .storageModeShared
                ))
            }
        }

        let inPositions = try makeBuffer(positions)
        let inNormals = try makeBuffer(normals)
        let inTangents = try makeBuffer(tangents)
        let inJointIndices = try makeBuffer(jointIndices)
        let inJointWeights = try makeBuffer(jointWeights)
        let inJointMatrices = try makeBuffer(jointMatrices)
        let omegaBuffer = try omegas.map { try makeBuffer($0) }
        let outLength = vertexCount * MemoryLayout<simd_float4>.stride
        let outPositions = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))
        let outNormals = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))
        let outTangents = try XCTUnwrap(device.makeBuffer(length: outLength, options: .storageModeShared))

        let commandBuffer = try XCTUnwrap(context.commandQueue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commandBuffer.makeComputeCommandEncoder())

        // The DQS path first converts the matrix palette to dual quaternions.
        var skinJointBuffer = inJointMatrices
        if let palettePipeline {
            let paletteLength = jointMatrices.count * MemoryLayout<JointDualQuat>.stride
            let palette = try XCTUnwrap(device.makeBuffer(length: paletteLength, options: .storageModeShared))
            encoder.setComputePipelineState(palettePipeline)
            encoder.setBuffer(inJointMatrices, offset: 0, index: Int(dualQuatPaletteJointTransformIndex.rawValue))
            encoder.setBuffer(palette, offset: 0, index: Int(dualQuatPaletteOutIndex.rawValue))
            var paletteParams = DualQuatPaletteParams(jointCount: UInt32(jointMatrices.count))
            encoder.setBytes(
                &paletteParams,
                length: MemoryLayout<DualQuatPaletteParams>.stride,
                index: Int(dualQuatPaletteParamsIndex.rawValue)
            )
            encoder.dispatchThreadgroups(
                MTLSize(width: 1, height: 1, depth: 1),
                threadsPerThreadgroup: MTLSize(width: max(jointMatrices.count, 1), height: 1, depth: 1)
            )
            skinJointBuffer = palette
        }

        encoder.setComputePipelineState(skinPipeline)
        encoder.setBuffer(inPositions, offset: 0, index: Int(deformationPassInPositionIndex.rawValue))
        encoder.setBuffer(inNormals, offset: 0, index: Int(deformationPassInNormalIndex.rawValue))
        encoder.setBuffer(inTangents, offset: 0, index: Int(deformationPassInTangentIndex.rawValue))
        encoder.setBuffer(inJointIndices, offset: 0, index: Int(deformationPassJointIdIndex.rawValue))
        encoder.setBuffer(inJointWeights, offset: 0, index: Int(deformationPassJointWeightsIndex.rawValue))
        encoder.setBuffer(skinJointBuffer, offset: 0, index: Int(deformationPassJointTransformIndex.rawValue))
        if let omegaBuffer {
            encoder.setBuffer(omegaBuffer, offset: 0, index: Int(deformationPassOmegaIndex.rawValue))
        }
        encoder.setBuffer(outPositions, offset: 0, index: Int(deformationPassOutPositionIndex.rawValue))
        encoder.setBuffer(outNormals, offset: 0, index: Int(deformationPassOutNormalIndex.rawValue))
        encoder.setBuffer(outTangents, offset: 0, index: Int(deformationPassOutTangentIndex.rawValue))
        var params = DeformationPassParams(vertexCount: UInt32(vertexCount), hasMorphDeltas: 0)
        encoder.setBytes(
            &params,
            length: MemoryLayout<DeformationPassParams>.stride,
            index: Int(deformationPassParamsIndex.rawValue)
        )
        let width = skinPipeline.threadExecutionWidth
        encoder.dispatchThreadgroups(
            MTLSize(width: (vertexCount + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        func readBack(_ buffer: MTLBuffer) -> [simd_float4] {
            let pointer = buffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            return Array(UnsafeBufferPointer(start: pointer, count: vertexCount))
        }
        return SkinOutputs(
            positions: readBack(outPositions),
            normals: readBack(outNormals),
            tangents: readBack(outTangents)
        )
    }
}
