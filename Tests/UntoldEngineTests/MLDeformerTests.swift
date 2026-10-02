//
//  MLDeformerTests.swift
//  UntoldEngineTests
//
//  Payload round trip, network evaluation, GPU decode parity and a headless
//  bake on a synthetic arm.
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

final class MLDeformerTests: XCTestCase {
    /// One joint (6 features), 2 hidden units, 2 components, 3 active
    /// vertices over two meshes, with hand-made weights.
    static func makePayload() -> MLDeformerPayload {
        let channels = MLDeformerPayload.channelsPerVertex
        let active = 3
        let k = 2
        var mean: [UInt16] = []
        var basis: [UInt16] = []
        for a in 0 ..< active {
            for c in 0 ..< channels {
                mean.append(Float16(Float(a) * 0.01 + Float(c) * 0.001).bitPattern)
            }
        }
        for component in 0 ..< k {
            for a in 0 ..< active {
                for c in 0 ..< channels {
                    basis.append(Float16(Float(component + 1) * 0.1 + Float(a) * 0.01 - Float(c) * 0.002).bitPattern)
                }
            }
        }
        return MLDeformerPayload(
            jointPaths: ["/root/upperArm/forearm"],
            meshes: [
                MLDeformerPayload.MeshRange(name: "meshA", vertexCount: 10, activeStart: 0, activeCount: 2),
                MLDeformerPayload.MeshRange(name: "meshB", vertexCount: 4, activeStart: 2, activeCount: 1),
            ],
            activeIndices: [3, 7, 1],
            inputMean: [Float](repeating: 0, count: 6),
            inputStd: [Float](repeating: 1, count: 6),
            hiddenCount: 2,
            weights1: [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0], // h0 = silu(f0), h1 = silu(f4)
            bias1: [0, 0],
            weights2: [1, 0, 0, 1], // identity
            bias2: [0, 0],
            weights3: [1, 0, 0, 1],
            bias3: [0.5, -0.25],
            coefficientScale: [2, 4],
            deltaMean: mean,
            basis: basis
        )
    }

    func testPayloadRoundTripsAndValidates() throws {
        let payload = Self.makePayload()
        try payload.validate()
        let data = payload.encode()
        let decoded = try MLDeformerPayload(data: data)
        XCTAssertEqual(decoded, payload)
        XCTAssertEqual(decoded.featureCount, 6)
        XCTAssertEqual(decoded.componentCount, 2)
        XCTAssertEqual(decoded.activeCount, 3)

        var truncated = data
        truncated.removeLast(8)
        XCTAssertThrowsError(try MLDeformerPayload(data: truncated))

        var bad = payload
        bad.activeIndices = [3, 12, 1] // out of range for meshA
        XCTAssertThrowsError(try bad.validate())
    }

    func testFeaturesAndEvaluation() {
        let payload = Self.makePayload()
        let identity = MLDeformerPayload.features(rotations: [simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))])
        XCTAssertEqual(identity, [1, 0, 0, 0, 1, 0])

        /// f0 = 1, f4 = 1 → layer 1 gives silu(1) on both units, the identity
        /// layer 2 applies SiLU again → outputs silu(silu(1)) + bias, scaled.
        func silu(_ x: Float) -> Float {
            x / (1 + exp(-x))
        }
        let hidden = silu(silu(1))
        let coefficients = payload.evaluate(features: identity)
        XCTAssertEqual(coefficients.count, 2)
        XCTAssertEqual(coefficients[0], (hidden + 0.5) * 2, accuracy: 1e-5)
        XCTAssertEqual(coefficients[1], (hidden - 0.25) * 4, accuracy: 1e-5)

        // A quarter turn about Z rotates the first column to (0, 1, 0).
        let quarter = MLDeformerPayload.features(rotations: [simd_quatf(angle: .pi / 2, axis: simd_float3(0, 0, 1))])
        XCTAssertEqual(quarter[0], 0, accuracy: 1e-6)
        XCTAssertEqual(quarter[1], 1, accuracy: 1e-6)
        XCTAssertEqual(quarter[3], -1, accuracy: 1e-6)
    }

    func testGPUDecodeMatchesCPUReference() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device") }
        guard let library = try device.makeLibraryFromBundle(),
              let function = library.makeFunction(name: "deformMLDecode"),
              let queue = device.makeCommandQueue()
        else { throw XCTSkip("deformMLDecode missing — regenerate the metallib") }
        let pipeline = try device.makeComputePipelineState(function: function)

        let payload = Self.makePayload()
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        let model = try XCTUnwrap(MLDeformerModel(payload: payload, skeleton: skeleton, device: device, label: "test"))
        XCTAssertEqual(model.jointIndices, [2])

        let coefficients: [Float] = [0.7, -1.3]
        // Write coefficients straight into the ring (bypassing the network).
        let pointer = model.currentCoefficients.contents().bindMemory(to: Float.self, capacity: 2)
        pointer[0] = coefficients[0]
        pointer[1] = coefficients[1]

        // Mesh A: 10 vertices at 1,2,3..., normals +Z.
        let vertexCount = 10
        let positionBuffer = device.makeBuffer(length: vertexCount * 16, options: .storageModeShared)!
        let normalBuffer = device.makeBuffer(length: vertexCount * 16, options: .storageModeShared)!
        let positions = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let normals = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        for v in 0 ..< vertexCount {
            positions[v] = simd_float4(Float(v), 0, 0, 1)
            normals[v] = simd_float4(0, 0, 1, 0)
        }

        let tables = try XCTUnwrap(model.tablesForTesting(name: "meshA"))
        var params = MLDecodeParams(activeCount: UInt32(tables.activeCount), vertexCount: UInt32(vertexCount), componentCount: 2, weight: 1)
        let commandBuffer = try XCTUnwrap(queue.makeCommandBuffer())
        let encoder = try XCTUnwrap(commandBuffer.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(positionBuffer, offset: 0, index: Int(mlDecodePositionsIndex.rawValue))
        encoder.setBuffer(normalBuffer, offset: 0, index: Int(mlDecodeNormalsIndex.rawValue))
        encoder.setBuffer(tables.activeIndices, offset: 0, index: Int(mlDecodeActiveIndicesIndex.rawValue))
        encoder.setBuffer(tables.deltaMean, offset: 0, index: Int(mlDecodeDeltaMeanIndex.rawValue))
        encoder.setBuffer(tables.basis, offset: 0, index: Int(mlDecodeBasisIndex.rawValue))
        encoder.setBuffer(model.currentCoefficients, offset: 0, index: Int(mlDecodeCoefficientsIndex.rawValue))
        encoder.setBytes(&params, length: MemoryLayout<MLDecodeParams>.stride, index: Int(mlDecodeParamsIndex.rawValue))
        encoder.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: 2, height: 1, depth: 1))
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Active vertices 3 and 7 of mesh A are payload actives 0 and 1.
        for (active, vertex) in [(0, 3), (1, 7)] {
            let expected = payload.decodedDelta(activeIndex: active, coefficients: coefficients)
            let position = positions[vertex]
            XCTAssertEqual(position.x, Float(vertex) + expected[0], accuracy: 2e-3)
            XCTAssertEqual(position.y, expected[1], accuracy: 2e-3)
            XCTAssertEqual(position.z, expected[2], accuracy: 2e-3)
            let normal = normals[vertex]
            let bent = simd_normalize(simd_float3(expected[3], expected[4], 1 + expected[5]))
            XCTAssertEqual(normal.x, bent.x, accuracy: 2e-3)
            XCTAssertEqual(normal.z, bent.z, accuracy: 2e-3)
        }
        // Untouched vertex.
        XCTAssertEqual(positions[5].x, 5, accuracy: 1e-6)
    }

    /// Synthetic upper-arm sleeve (a cylinder skinned to the upper arm)
    /// baked over a curl clip: the dataset files exist, the sleeve vertices
    /// near the biceps are active, and the deltas are not all zero.
    func testBakeProducesDatasetOnSyntheticArm() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("No Metal device") }
        let skeleton = MuscleGeometryTests.makeArmSkeleton()
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: skeleton.jointPaths, parentIndices: skeleton.parentIndices,
            bindTransforms: skeleton.bindTransform, restTransforms: skeleton.restTransform
        )

        // Sleeve: 12 rings × 16 around the upper arm axis (x from 0.02 to 0.28 at y = 1), radius 0.05.
        var vertexWriter = UntoldBinaryWriter()
        var jointIndexData = Data()
        var jointWeightData = Data()
        var vertexCount = 0
        for ring in 0 ..< 12 {
            let x = 0.02 + 0.26 * Float(ring) / 11
            for segment in 0 ..< 16 {
                let angle = 2 * Float.pi * Float(segment) / 16
                let normal = simd_float3(0, cos(angle), sin(angle))
                let position = simd_float3(x, 1 + 0.05 * cos(angle), 0.05 * sin(angle))
                UntoldPBRStaticVertexV1(
                    position: position,
                    normalPacked: UntoldVertexPacking.packNormal(normal),
                    tangentPacked: UntoldVertexPacking.packTangent(simd_float3(1, 0, 0), handedness: 1)
                ).encode(to: vertexWriter)
                var joints = simd_ushort4(0, 0, 0, 0) // skin joint 0 → upperArm
                var weights = simd_float4(1, 0, 0, 0)
                jointIndexData.append(Data(bytes: &joints, count: 8))
                jointWeightData.append(Data(bytes: &weights, count: 16))
                vertexCount += 1
            }
        }
        let bounds = RuntimeAABB(min: simd_float3(0, 0.9, -0.1), max: simd_float3(0.3, 1.1, 0.1))
        let primitive = RuntimeMeshPrimitive(
            name: "sleeve",
            localBounds: bounds, worldBounds: bounds,
            vertexLayout: .pbrStaticV1,
            vertexData: vertexWriter.data,
            indexData: Data(),
            indexFormat: .uint16,
            vertexCount: vertexCount,
            indexCount: 0,
            skin: RuntimeSkinBinding(skeletonEntityID: 0, skinToSkeletonMap: [1], jointIndexData: jointIndexData, jointWeightData: jointWeightData)
        )
        let node = RuntimeAssetNode(
            id: 0, parentID: nil, name: "arm", localTransform: matrix_identity_float4x4, worldTransform: matrix_identity_float4x4,
            localBounds: bounds, worldBounds: bounds, skeleton: runtimeSkeleton, primitives: [primitive]
        )
        let asset = RuntimeAsset(
            sourceURL: URL(fileURLWithPath: "/tmp/arm.untold"), sourceKind: .untold, assetName: "arm",
            rootTransform: matrix_identity_float4x4, worldBounds: bounds, nodes: [node],
            lights: [], cameras: [], colorManagement: nil, colorGradeLUT: nil, animationClips: [], meshGroups: []
        )

        // Curl clip: the forearm rotates 0 → 110° about +Z over 1.5 s.
        let curl = RuntimeAnimationClip(name: "curl", duration: 1.5, channels: [
            RuntimeAnimationChannel(
                jointPath: "/root/upperArm/forearm",
                translations: [RuntimeTranslationKeyframe(time: 0, value: simd_float3(0.3, 0, 0))],
                rotations: [
                    RuntimeRotationKeyframe(time: 0, value: simd_float4(0, 0, 0, 1)),
                    RuntimeRotationKeyframe(time: 1.5, value: simd_quatf(angle: 1.92, axis: simd_float3(0, 0, 1)).vector),
                ]
            ),
        ])

        var options = MLDeformerBakeOptions()
        options.augmentationPasses = 1
        options.sampleEveryFrames = 3
        options.settleFrames = 6
        options.frameRate = 60
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("mlbake-\(UUID().uuidString)/arm")
        let summary = try MLDeformerBaker.bake(
            asset: asset, clips: [curl], rig: MuscleGeometryTests.makeBicepsRig(), options: options, outputBase: base
        )
        XCTAssertGreaterThan(summary.sampleCount, 20)
        XCTAssertGreaterThan(summary.activeVertexCount, 0)
        XCTAssertLessThan(summary.activeVertexCount, vertexCount)
        XCTAssertEqual(summary.jointPaths, ["/root/upperArm", "/root/upperArm/forearm"])
        XCTAssertEqual(summary.featureCount, 12)

        let header = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: base.path + ".json"))) as? [String: Any]
        XCTAssertEqual(header?["sampleCount"] as? Int, summary.sampleCount)
        let features = try Data(contentsOf: URL(fileURLWithPath: base.path + ".features.f32"))
        XCTAssertEqual(features.count, summary.sampleCount * summary.featureCount * 4)
        let deltas = try Data(contentsOf: URL(fileURLWithPath: base.path + ".deltas.f16"))
        XCTAssertEqual(deltas.count, summary.sampleCount * summary.activeVertexCount * 6 * 2)
        let magnitudes = deltas.withUnsafeBytes { raw in
            raw.bindMemory(to: UInt16.self).map { abs(Float(Float16(bitPattern: $0))) }
        }
        XCTAssertGreaterThan(magnitudes.max() ?? 0, 1e-4, "the curl must move the sleeve")
        try? FileManager.default.removeItem(at: base.deletingLastPathComponent())
    }

    func testMuscleRigJSONRoundTrip() throws {
        let rig = MuscleGeometryTests.makeBicepsRig()
        let data = try rig.jsonData()
        let decoded = try MuscleRig(jsonData: data)
        XCTAssertEqual(decoded, rig)

        // The exporter's schema: degrees, optional fields, defaults.
        let json = """
        {"forwardReference": {"from": "foot", "to": "toe"},
         "muscles": [{"name": "x", "origin": {"joint": "a", "fraction": 0.1, "offset": [0, 0, 0.02]},
                      "insertion": {"joint": "b", "tip": "c"}, "bellyRadius": 0.04, "tendonRadius": 0.01,
                      "driver": {"joint": "b", "startAngle": 10, "fullAngle": 110}}]}
        """
        let parsed = try MuscleRig(jsonData: Data(json.utf8))
        XCTAssertEqual(parsed.muscles.count, 1)
        XCTAssertEqual(parsed.muscles[0].insertion.tipJointName, "c")
        XCTAssertEqual(parsed.muscles[0].insertion.fraction, 0.5)
        XCTAssertEqual(parsed.muscles[0].rings, 7)
        XCTAssertEqual(parsed.muscles[0].driver?.fullAngle ?? 0, 110 * .pi / 180, accuracy: 1e-6)
    }
}
