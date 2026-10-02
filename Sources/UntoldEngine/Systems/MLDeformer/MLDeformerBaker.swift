//
//  MLDeformerBaker.swift
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

/// Sampling options of an ML deformer bake.
public struct MLDeformerBakeOptions: Sendable {
    /// Simulation rate; the muscle sim is stepped every frame.
    public var frameRate: Float = 90
    /// A sample is recorded every this many simulated frames.
    public var sampleEveryFrames = 4
    /// Extra plays of each clip with smooth random joint offsets.
    public var augmentationPasses = 6
    /// Largest augmentation rotation per joint, radians.
    public var maxAugmentationAngle: Float = 0.45
    /// Frames the simulation settles before the first sample of a play.
    public var settleFrames = 24
    public var seed: UInt64 = 1

    public init() {}
}

public struct MLDeformerBakeSummary: Sendable {
    public let sampleCount: Int
    public let activeVertexCount: Int
    public let featureCount: Int
    public let jointPaths: [String]
    public let meshNames: [String]
    public let outputBase: URL
}

public enum MLDeformerBakeError: Error, Equatable {
    case noSkeleton
    case noSkinnedMesh
    case noMuscles
    case noClips
    case noMetalDevice
    case kernelsUnavailable
    case io(String)
}

/// Headless data generation for the ML deformer: plays animation clips
/// (plus smooth random augmentations) through the XPBD muscle simulation
/// and records, every few frames, the pose features and the skin deltas the
/// muscles produced on top of linear blend skinning. Writes
/// `<base>.json` (header), `<base>.features.f32` and `<base>.deltas.f16`
/// for `scripts/train_mldeformer.py`.
public enum MLDeformerBaker {
    public static func bake(
        asset: RuntimeAsset,
        clips: [RuntimeAnimationClip],
        rig: MuscleRig,
        options: MLDeformerBakeOptions = MLDeformerBakeOptions(),
        outputBase: URL,
        progress: ((String) -> Void)? = nil
    ) throws -> MLDeformerBakeSummary {
        guard !clips.isEmpty else { throw MLDeformerBakeError.noClips }
        guard let runtimeSkeleton = resolveSkeleton(in: asset),
              let skeleton = Skeleton(runtimeSkeleton: runtimeSkeleton)
        else { throw MLDeformerBakeError.noSkeleton }
        let primitives = asset.nodes.flatMap(\.primitives).filter { $0.skin != nil }
        guard !primitives.isEmpty else { throw MLDeformerBakeError.noSkinnedMesh }
        guard let geometry = MuscleGeometryBuilder.bake(rig: rig, skeleton: skeleton) else {
            throw MLDeformerBakeError.noMuscles
        }
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw MLDeformerBakeError.noMetalDevice
        }
        guard let library = try? device.makeLibraryFromBundle(),
              let predict = library.makeFunction(name: "musclePredict"),
              let gradient = library.makeFunction(name: "muscleVolumeGradient"),
              let solve = library.makeFunction(name: "muscleSolve"),
              let wrap = library.makeFunction(name: "muscleSkinWrap"),
              let pipelines = try? MusclePipelines(
                  predict: device.makeComputePipelineState(function: predict),
                  volumeGradient: device.makeComputePipelineState(function: gradient),
                  solve: device.makeComputePipelineState(function: solve),
                  skinWrap: device.makeComputePipelineState(function: wrap)
              ),
              let state = MuscleSimState(geometry: geometry, device: device, label: asset.assetName)
        else { throw MLDeformerBakeError.kernelsUnavailable }

        // Skinned meshes: rest streams, skin data, muscle binding, GPU buffers.
        var meshes: [BakeMesh] = []
        for primitive in primitives {
            guard let mesh = try BakeMesh(primitive: primitive, geometry: geometry, device: device) else { continue }
            meshes.append(mesh)
        }
        let activeTotal = meshes.reduce(0) { $0 + $1.activeIndices.count }
        guard activeTotal > 0 else { throw MLDeformerBakeError.noMuscles }
        progress?("\(meshes.count) skinned mesh(es), \(activeTotal) active vertices, \(geometry.muscles.count) muscles")

        // Pose features: every joint a muscle attaches to or is driven by.
        var jointSet = Set<Int>()
        for muscle in geometry.muscles {
            jointSet.insert(muscle.originJoint)
            jointSet.insert(muscle.insertionJoint)
            if let driver = muscle.driverJoint {
                jointSet.insert(driver)
            }
        }
        let featureJoints = jointSet.sorted()
        let jointPaths = featureJoints.map { skeleton.jointPaths[$0] }
        let featureCount = featureJoints.count * MLDeformerPayload.featuresPerJoint

        let writer = try DatasetWriter(base: outputBase)
        var random = BakeRandom(seed: options.seed)
        let frameDelta = 1 / options.frameRate
        let substepDelta = frameDelta / Float(muscleSubstepsPerFrame)
        var sampleCount = 0
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        for runtimeClip in clips {
            let clip = AnimationClip(runtimeClip: runtimeClip)
            let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
            let frameCount = max(Int((clip.duration * options.frameRate).rounded(.up)), options.settleFrames + 1)

            for pass in 0 ... max(options.augmentationPasses, 0) {
                let augmentation = pass == 0 ? nil : Augmentation(joints: featureJoints, maxAngle: options.maxAugmentationAngle, random: &random)
                for index in 0 ..< state.activations.count {
                    state.activations[index] = 0
                }
                var passSamples = 0

                for frame in 0 ..< frameCount {
                    let time = Float(frame) * frameDelta
                    sampler.sample(compiled, time: time, duration: clip.duration, speed: clip.speed, into: &pose)
                    augmentation?.apply(to: &pose, time: time)
                    skeleton.updateWorldPose(from: pose, localScales: compiled.restScales)

                    let targets = geometry.muscles.map { muscle in
                        MuscleSimulator.activationTarget(
                            muscle: muscle, localRotations: pose.rotations,
                            restTransforms: skeleton.restTransform, override: nil, manual: [:]
                        )
                    }
                    MuscleSimulator.smoothActivations(state: state, targets: targets, frameDelta: frameDelta)
                    let frameParams = MuscleSimulator.frameParams(
                        state: state, currentPose: skeleton.currentPose, disabledMuscles: [], substepDelta: substepDelta
                    )

                    let record = frame >= options.settleFrames && (frame - options.settleFrames) % max(options.sampleEveryFrames, 1) == 0
                    if record {
                        for mesh in meshes {
                            mesh.skin(currentPose: skeleton.currentPose)
                        }
                    }

                    guard let commandBuffer = queue.makeCommandBuffer(),
                          let encoder = commandBuffer.makeComputeCommandEncoder()
                    else { throw MLDeformerBakeError.noMetalDevice }
                    MuscleSimulator.encodeFrame(
                        encoder: encoder, pipelines: pipelines, state: state, frameParams: frameParams,
                        substepDelta: substepDelta, gravity: simd_float3(0, -2, 0), reset: frame == 0
                    )
                    if record {
                        for mesh in meshes {
                            MuscleSimulator.encodeSkinWrap(
                                encoder: encoder, pipeline: pipelines.skinWrap, state: state, bindings: mesh.bindingBuffer,
                                positions: mesh.positionBuffer, normals: mesh.normalBuffer, tangents: mesh.tangentBuffer,
                                vertexCount: mesh.vertexCount
                            )
                        }
                    }
                    encoder.endEncoding()
                    commandBuffer.commit()
                    commandBuffer.waitUntilCompleted()

                    if record {
                        let features = MLDeformerPayload.features(rotations: featureJoints.map { joint in
                            PoseDriverEvaluation.restRotation(from: skeleton.restTransform[joint]).inverse * pose.rotations[joint]
                        })
                        try writer.append(features: features)
                        for mesh in meshes {
                            try writer.append(deltas: mesh.readDeltas())
                        }
                        sampleCount += 1
                        passSamples += 1
                    }
                }
                progress?("clip \(clip.name) pass \(pass): \(passSamples) samples")
            }
        }

        var activeStart = 0
        var meshRanges: [[String: Any]] = []
        var activeIndices: [Int] = []
        for mesh in meshes {
            meshRanges.append([
                "name": mesh.name, "vertexCount": mesh.vertexCount,
                "activeStart": activeStart, "activeCount": mesh.activeIndices.count,
            ])
            activeIndices.append(contentsOf: mesh.activeIndices.map(Int.init))
            activeStart += mesh.activeIndices.count
        }
        try writer.finish(header: [
            "version": 1,
            "sampleCount": sampleCount,
            "featureCount": featureCount,
            "activeCount": activeTotal,
            "channels": MLDeformerPayload.channelsPerVertex,
            "frameRate": options.frameRate,
            "jointPaths": jointPaths,
            "meshes": meshRanges,
            "activeIndices": activeIndices,
            "clips": clips.map(\.name),
            "features": writer.featuresURL.lastPathComponent,
            "deltas": writer.deltasURL.lastPathComponent,
        ])

        return MLDeformerBakeSummary(
            sampleCount: sampleCount,
            activeVertexCount: activeTotal,
            featureCount: featureCount,
            jointPaths: jointPaths,
            meshNames: meshes.map(\.name),
            outputBase: outputBase
        )
    }

    static func resolveSkeleton(in asset: RuntimeAsset) -> RuntimeSkeleton? {
        if let skeleton = asset.nodes.first(where: { $0.skeleton != nil })?.skeleton {
            return skeleton
        }
        let nodesByID = Dictionary(asset.nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for node in asset.nodes {
            for primitive in node.primitives {
                if let id = primitive.skin?.skeletonEntityID, let skeleton = nodesByID[id]?.skeleton {
                    return skeleton
                }
            }
        }
        return nil
    }

    // MARK: - Per-mesh state

    /// One skinned primitive: rest streams and skin data on the CPU, the
    /// muscle binding, and shared GPU buffers the wrap kernel deforms.
    final class BakeMesh {
        let name: String
        let vertexCount: Int
        let restPositions: [simd_float3]
        let restNormals: [simd_float3]
        let restTangents: [simd_float4]
        let jointIndices: [simd_ushort4]
        let jointWeights: [simd_float4]
        let skinToSkeleton: [Int]
        let activeIndices: [UInt32]
        let bindingBuffer: MTLBuffer
        let positionBuffer: MTLBuffer
        let normalBuffer: MTLBuffer
        let tangentBuffer: MTLBuffer
        private var skinnedPositions: [simd_float3]
        private var skinnedNormals: [simd_float3]

        init?(primitive: RuntimeMeshPrimitive, geometry: MuscleBakedGeometry, device: MTLDevice) throws {
            guard let skin = primitive.skin, primitive.vertexCount > 0 else { return nil }
            let count = primitive.vertexCount
            name = primitive.name
            vertexCount = count

            let reader = UntoldBinaryReader(data: primitive.vertexData)
            var positions: [simd_float3] = []
            var normals: [simd_float3] = []
            var tangents: [simd_float4] = []
            positions.reserveCapacity(vertexCount)
            for _ in 0 ..< count {
                let vertex = try UntoldPBRStaticVertexV1.decode(from: reader)
                positions.append(vertex.position)
                normals.append(UntoldVertexPacking.unpackNormal(vertex.normalPacked))
                let tangent = UntoldVertexPacking.unpackTangent(vertex.tangentPacked)
                tangents.append(simd_float4(tangent.vector, tangent.handedness))
            }
            restPositions = positions
            restNormals = normals
            restTangents = tangents
            jointIndices = skin.jointIndexData.withUnsafeBytes { Array($0.bindMemory(to: simd_ushort4.self).prefix(count)) }
            jointWeights = skin.jointWeightData.withUnsafeBytes { Array($0.bindMemory(to: simd_float4.self).prefix(count)) }
            guard jointIndices.count == count, jointWeights.count == count else { return nil }
            skinToSkeleton = skin.skinToSkeletonMap

            let bindings = MuscleGeometryBuilder.bindSkin(
                positions: positions.map { simd_float4($0, 1) }, geometry: geometry
            )
            activeIndices = bindings.enumerated().compactMap { $0.element.tetIndex == MUSCLE_SKIN_UNBOUND ? nil : UInt32($0.offset) }
            guard !activeIndices.isEmpty else { return nil }

            let bindingLength = bindings.count * MemoryLayout<MuscleSkinBinding>.stride
            let streamLength = count * MemoryLayout<simd_float4>.stride
            guard let bindingBuffer = bindings.withUnsafeBytes({ bytes -> MTLBuffer? in
                guard let base = bytes.baseAddress else { return nil }
                return device.makeBuffer(bytes: base, length: bindingLength, options: .storageModeShared)
            }),
                let positionBuffer = device.makeBuffer(length: streamLength, options: .storageModeShared),
                let normalBuffer = device.makeBuffer(length: streamLength, options: .storageModeShared),
                let tangentBuffer = device.makeBuffer(length: streamLength, options: .storageModeShared)
            else { return nil }
            self.bindingBuffer = bindingBuffer
            self.positionBuffer = positionBuffer
            self.normalBuffer = normalBuffer
            self.tangentBuffer = tangentBuffer
            skinnedPositions = positions
            skinnedNormals = normals
        }

        /// Linear blend skinning of the rest streams into the GPU buffers.
        func skin(currentPose: [simd_float4x4]) {
            let positions = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            let normals = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            let tangents = tangentBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            for vertex in 0 ..< vertexCount {
                let joints = jointIndices[vertex]
                let weights = jointWeights[vertex]
                var matrix = simd_float4x4(0)
                let weightSum = weights.x + weights.y + weights.z + weights.w
                if weightSum > 1e-4 {
                    let ids = [joints.x, joints.y, joints.z, joints.w]
                    let ws = [weights.x, weights.y, weights.z, weights.w]
                    for slot in 0 ..< 4 where ws[slot] > 0 {
                        let skinJoint = Int(ids[slot])
                        guard skinJoint < skinToSkeleton.count, skinToSkeleton[skinJoint] < currentPose.count else { continue }
                        matrix += ws[slot] * currentPose[skinToSkeleton[skinJoint]]
                    }
                } else {
                    matrix = matrix_identity_float4x4
                }
                let rotation = simd_float3x3(
                    simd_float3(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z),
                    simd_float3(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z),
                    simd_float3(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
                )
                let cofactor = simd_float3x3(
                    simd_cross(rotation.columns.1, rotation.columns.2),
                    simd_cross(rotation.columns.2, rotation.columns.0),
                    simd_cross(rotation.columns.0, rotation.columns.1)
                )
                let position = MuscleSimulator.transformPoint(matrix, restPositions[vertex])
                var normal = cofactor * restNormals[vertex]
                let normalLength = simd_length(normal)
                normal = normalLength > 1e-8 ? normal / normalLength : restNormals[vertex]
                let tangent = restTangents[vertex]
                var tangentVector = rotation * simd_float3(tangent.x, tangent.y, tangent.z)
                let tangentLength = simd_length(tangentVector)
                tangentVector = tangentLength > 1e-8 ? tangentVector / tangentLength : simd_float3(tangent.x, tangent.y, tangent.z)

                skinnedPositions[vertex] = position
                skinnedNormals[vertex] = normal
                positions[vertex] = simd_float4(position, 1)
                normals[vertex] = simd_float4(normal, 0)
                tangents[vertex] = simd_float4(tangentVector, tangent.w)
            }
        }

        /// Deltas of the active vertices after the wrap kernel ran: six
        /// float16 channels each (position, normal).
        func readDeltas() -> [UInt16] {
            let positions = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            let normals = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
            var deltas: [UInt16] = []
            deltas.reserveCapacity(activeIndices.count * MLDeformerPayload.channelsPerVertex)
            for active in activeIndices {
                let vertex = Int(active)
                let wrapped = positions[vertex]
                let normal = normals[vertex]
                let dp = simd_float3(wrapped.x, wrapped.y, wrapped.z) - skinnedPositions[vertex]
                let dn = simd_float3(normal.x, normal.y, normal.z) - skinnedNormals[vertex]
                for value in [dp.x, dp.y, dp.z, dn.x, dn.y, dn.z] {
                    deltas.append(Float16(value).bitPattern)
                }
            }
            return deltas
        }
    }

    // MARK: - Augmentation

    /// Smooth random rotation offsets per joint: a sine per joint with a
    /// random axis, amplitude, frequency and phase.
    struct Augmentation {
        struct JointOffset {
            let joint: Int
            let axis: simd_float3
            let amplitude: Float
            let frequency: Float
            let phase: Float
        }

        let offsets: [JointOffset]

        init(joints: [Int], maxAngle: Float, random: inout BakeRandom) {
            offsets = joints.map { joint in
                let axis = simd_normalize(simd_float3(
                    random.unit() * 2 - 1, random.unit() * 2 - 1, random.unit() * 2 - 1
                ) + simd_float3(1e-4, 0, 0))
                return JointOffset(
                    joint: joint,
                    axis: axis,
                    amplitude: random.unit() * maxAngle,
                    frequency: 0.15 + random.unit() * 0.45,
                    phase: random.unit() * 2 * .pi
                )
            }
        }

        func apply(to pose: inout PoseBuffer, time: Float) {
            for offset in offsets where offset.joint < pose.rotations.count {
                let angle = offset.amplitude * sin(2 * .pi * offset.frequency * time + offset.phase)
                pose.rotations[offset.joint] = simd_normalize(
                    pose.rotations[offset.joint] * simd_quatf(angle: angle, axis: offset.axis)
                )
            }
        }
    }

    struct BakeRandom {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }

        mutating func unit() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(state >> 40) / Float(1 << 24)
        }
    }

    // MARK: - Dataset files

    final class DatasetWriter {
        let base: URL
        let featuresURL: URL
        let deltasURL: URL
        private let featuresHandle: FileHandle
        private let deltasHandle: FileHandle

        init(base: URL) throws {
            self.base = base
            let directory = base.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            featuresURL = URL(fileURLWithPath: base.path + ".features.f32")
            deltasURL = URL(fileURLWithPath: base.path + ".deltas.f16")
            for url in [featuresURL, deltasURL] {
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                    throw MLDeformerBakeError.io("cannot create \(url.path)")
                }
            }
            featuresHandle = try FileHandle(forWritingTo: featuresURL)
            deltasHandle = try FileHandle(forWritingTo: deltasURL)
        }

        func append(features: [Float]) throws {
            try featuresHandle.write(contentsOf: features.withUnsafeBytes { Data($0) })
        }

        func append(deltas: [UInt16]) throws {
            try deltasHandle.write(contentsOf: deltas.withUnsafeBytes { Data($0) })
        }

        func finish(header: [String: Any]) throws {
            try featuresHandle.close()
            try deltasHandle.close()
            let data = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
            try data.write(to: URL(fileURLWithPath: base.path + ".json"))
        }
    }
}
