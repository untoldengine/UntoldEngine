//
//  MuscleSimulation.swift
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

/// Substeps per frame; one Jacobi iteration each (XPBD small steps).
let muscleSubstepsPerFrame = 8
/// Relaxation applied to each particle's per-family averaged constraint
/// correction (1 = plain averaged Jacobi).
let muscleRelaxation: Float = 1.0
/// Activation smoothing time constant (seconds).
let muscleActivationSmoothing: Float = 0.08

/// GPU state of one entity's muscle rig: particle buffers (ping-pong),
/// constraint/adjacency buffers, a ring of per-muscle frame parameters and the
/// per-mesh skin bindings (baked in the background).
final class MuscleSimState: @unchecked Sendable {
    enum BindingState {
        case building
        case ready(MTLBuffer)
    }

    let geometry: MuscleBakedGeometry
    let particleCount: Int
    let muscleCount: Int

    private(set) var positions: [MTLBuffer]
    let prevPositions: MTLBuffer
    let particleInfo: MTLBuffer
    let edges: MTLBuffer
    let tets: MTLBuffer
    let triangles: MTLBuffer
    let edgeOffsets: MTLBuffer
    let edgeList: MTLBuffer
    let triOffsets: MTLBuffer
    let triList: MTLBuffer
    let gradients: MTLBuffer
    private let muscleParamsRing: [MTLBuffer]
    private var ringIndex = 0
    private(set) var currentIndex = 0
    var activations: [Float]
    var needsReset = true
    private var bindings: [ObjectIdentifier: BindingState] = [:]
    private let bindingLock = NSLock()

    static let bakeQueue = DispatchQueue(label: "com.untoldengine.muscle-bind", qos: .utility)

    var currentPositions: MTLBuffer {
        positions[currentIndex]
    }

    var nextPositions: MTLBuffer {
        positions[1 - currentIndex]
    }

    var currentMuscleParams: MTLBuffer {
        muscleParamsRing[ringIndex]
    }

    init?(geometry: MuscleBakedGeometry, device: MTLDevice, label: String) {
        guard geometry.particleCount > 0, !geometry.tets.isEmpty, !geometry.edges.isEmpty, !geometry.triangles.isEmpty else { return nil }
        self.geometry = geometry
        particleCount = geometry.particleCount
        muscleCount = geometry.muscles.count

        func makeBuffer<T>(_ values: [T], _ name: String) -> MTLBuffer? {
            let length = values.count * MemoryLayout<T>.stride
            let buffer = values.withUnsafeBytes { bytes -> MTLBuffer? in
                guard let baseAddress = bytes.baseAddress else { return nil }
                return device.makeBuffer(bytes: baseAddress, length: length, options: .storageModeShared)
            }
            buffer?.label = "\(label) muscle \(name)"
            return buffer
        }

        guard let positionsA = makeBuffer(geometry.initialPositions, "positions A"),
              let positionsB = makeBuffer(geometry.initialPositions, "positions B"),
              let prevPositions = makeBuffer(geometry.initialPositions, "previous positions"),
              let particleInfo = makeBuffer(geometry.particleInfos, "particle info"),
              let edges = makeBuffer(geometry.edges, "edges"),
              let tets = makeBuffer(geometry.tets, "tets"),
              let triangles = makeBuffer(geometry.triangles, "triangles"),
              let edgeOffsets = makeBuffer(geometry.edgeOffsets, "edge offsets"),
              let edgeList = makeBuffer(geometry.edgeList, "edge list"),
              let triOffsets = makeBuffer(geometry.triOffsets, "triangle offsets"),
              let triList = makeBuffer(geometry.triList, "triangle list"),
              let gradients = device.makeBuffer(
                  length: geometry.particleCount * MemoryLayout<simd_float4>.stride, options: .storageModePrivate
              )
        else { return nil }
        gradients.label = "\(label) muscle volume gradients"

        var ring: [MTLBuffer] = []
        let paramsLength = geometry.muscles.count * MemoryLayout<MuscleFrameParams>.stride
        for slot in 0 ..< (maxInFlightCommandBuffers + 1) {
            guard let buffer = device.makeBuffer(length: paramsLength, options: .storageModeShared) else { return nil }
            buffer.label = "\(label) muscle frame params \(slot)"
            ring.append(buffer)
        }

        positions = [positionsA, positionsB]
        self.prevPositions = prevPositions
        self.particleInfo = particleInfo
        self.edges = edges
        self.tets = tets
        self.triangles = triangles
        self.edgeOffsets = edgeOffsets
        self.edgeList = edgeList
        self.triOffsets = triOffsets
        self.triList = triList
        self.gradients = gradients
        muscleParamsRing = ring
        activations = [Float](repeating: 0, count: geometry.muscles.count)
    }

    /// Rotates to the next frame-params slot and fills it.
    func writeMuscleParams(_ fill: (UnsafeMutablePointer<MuscleFrameParams>) -> Void) {
        ringIndex = (ringIndex + 1) % muscleParamsRing.count
        let pointer = muscleParamsRing[ringIndex].contents().bindMemory(to: MuscleFrameParams.self, capacity: muscleCount)
        fill(pointer)
    }

    func swapPositions() {
        currentIndex = 1 - currentIndex
    }

    /// Writes `values` into both position buffers and the previous-position
    /// buffer (a rest start with zero velocity).
    func resetPositions(_ values: [simd_float4]) {
        precondition(values.count == particleCount)
        for buffer in positions + [prevPositions] {
            let pointer = buffer.contents().bindMemory(to: simd_float4.self, capacity: particleCount)
            for index in 0 ..< particleCount {
                pointer[index] = values[index]
            }
        }
        needsReset = false
    }

    func bindingState(for key: ObjectIdentifier) -> BindingState? {
        bindingLock.lock()
        defer { bindingLock.unlock() }
        return bindings[key]
    }

    func setBindingState(_ state: BindingState?, for key: ObjectIdentifier) {
        bindingLock.lock()
        bindings[key] = state
        bindingLock.unlock()
    }
}

/// Compute pipelines of the muscle kernels, resolved once per encode.
struct MusclePipelines {
    let predict: MTLComputePipelineState
    let volumeGradient: MTLComputePipelineState
    let solve: MTLComputePipelineState
    let skinWrap: MTLComputePipelineState
}

/// ECS-free muscle simulation steps shared by the deformation pass, the
/// headless tests and the ML deformer baker: activation, per-frame
/// parameters, the substep encode and the skin wrap encode.
enum MuscleSimulator {
    /// Activation target of one muscle for a pose: the global override wins,
    /// then a manual value, then the joint-angle driver, else zero.
    static func activationTarget(
        muscle: MuscleBakedMuscle,
        localRotations: [simd_quatf]?,
        restTransforms: [simd_float4x4],
        override: Float?,
        manual: [String: Float]
    ) -> Float {
        if let override {
            return min(max(override, 0), 1)
        }
        if let manual = manual[muscle.definition.name] {
            return min(max(manual, 0), 1)
        }
        guard let driver = muscle.definition.driver,
              let joint = muscle.driverJoint,
              let localRotations,
              localRotations.count == restTransforms.count
        else { return 0 }
        let rest = PoseDriverEvaluation.restRotation(from: restTransforms[joint])
        let delta = rest.inverse * localRotations[joint]
        let angle = 2 * acos(min(abs(delta.real), 1))
        let span = driver.fullAngle - driver.startAngle
        guard abs(span) > 1e-5 else { return 0 }
        return min(max((angle - driver.startAngle) / span, 0), 1)
    }

    /// Exponentially smooths `state.activations` toward `targets`.
    static func smoothActivations(state: MuscleSimState, targets: [Float], frameDelta: Float) {
        let blend = 1 - exp(-frameDelta / muscleActivationSmoothing)
        for index in 0 ..< min(targets.count, state.activations.count) {
            state.activations[index] += (targets[index] - state.activations[index]) * blend
        }
    }

    /// Per-muscle frame parameters for the skeleton's current model-space
    /// joint palette (`Skeleton.currentPose`).
    static func frameParams(
        state: MuscleSimState,
        currentPose: [simd_float4x4],
        disabledMuscles: Set<String>,
        substepDelta: Float
    ) -> [MuscleFrameParams] {
        let dt2 = substepDelta * substepDelta
        return state.geometry.muscles.enumerated().map { index, muscle in
            let originJoint = currentPose[muscle.originJoint]
            let insertionJoint = currentPose[muscle.insertionJoint]
            let originCurrent = transformPoint(originJoint, muscle.originRest)
            let insertionCurrent = transformPoint(insertionJoint, muscle.insertionRest)
            var currentAxis = insertionCurrent - originCurrent
            if simd_length_squared(currentAxis) < 1e-12 {
                currentAxis = muscle.restAxis
            }
            let rotation = simd_quatf(from: muscle.restAxis, to: simd_normalize(currentAxis))
            let definition = muscle.definition
            let boneRadius = definition.boneRadius
            let activation = state.activations[index]
            return MuscleFrameParams(
                originJoint: originJoint,
                insertionJoint: insertionJoint,
                referenceRotation: simd_float4x4(rotation),
                originCurrent: simd_float4(originCurrent, muscle.restLength),
                insertionCurrent: simd_float4(insertionCurrent, simd_length(currentAxis)),
                capsuleA0: simd_float4(transformPoint(originJoint, muscle.originBone.start), boneRadius),
                capsuleA1: simd_float4(transformPoint(originJoint, muscle.originBone.end), 0),
                capsuleB0: simd_float4(transformPoint(insertionJoint, muscle.insertionBone.start), boneRadius),
                capsuleB1: simd_float4(transformPoint(insertionJoint, muscle.insertionBone.end), 0),
                fiberScale: 1 - definition.maxContraction * activation,
                fiberAlpha: definition.fiberCompliance / dt2,
                crossAlpha: definition.crossCompliance / dt2,
                volumeAlpha: definition.volumeCompliance / dt2,
                damping: definition.damping,
                skinWeight: disabledMuscles.contains(definition.name) ? 0 : 1,
                restVolume: muscle.restVolume,
                pad0: 0,
                particleStart: UInt32(muscle.particleRange.lowerBound),
                particleCount: UInt32(muscle.particleRange.count),
                pad1: 0, pad2: 0
            )
        }
    }

    /// Passive reference positions for every particle under the given frame
    /// parameters (the CPU twin of the kernel's `muscleReferencePosition`),
    /// used to start the simulation at rest in the current pose.
    static func referencePositions(state: MuscleSimState, frameParams: [MuscleFrameParams]) -> [simd_float4] {
        state.geometry.particleInfos.enumerated().map { index, info in
            let params = frameParams[Int(info.muscleIndex)]
            let rest = simd_float3(info.restPosition.x, info.restPosition.y, info.restPosition.z)
            let inverseMass = state.geometry.initialPositions[index].w
            switch info.attachment {
            case UInt32(MUSCLE_ATTACHMENT_ORIGIN):
                return simd_float4(transformPoint(params.originJoint, rest), inverseMass)
            case UInt32(MUSCLE_ATTACHMENT_INSERTION):
                return simd_float4(transformPoint(params.insertionJoint, rest), inverseMass)
            default:
                let t = info.restPosition.w
                let radial = simd_float3(info.restRadial.x, info.restRadial.y, info.restRadial.z)
                let rotated = params.referenceRotation * simd_float4(radial, 0)
                let origin = simd_float3(params.originCurrent.x, params.originCurrent.y, params.originCurrent.z)
                let insertion = simd_float3(params.insertionCurrent.x, params.insertionCurrent.y, params.insertionCurrent.z)
                let position = origin + (insertion - origin) * t + simd_float3(rotated.x, rotated.y, rotated.z)
                return simd_float4(position, inverseMass)
            }
        }
    }

    /// Writes `frameParams` into the state's next ring slot, resets the
    /// particles to the passive reference when requested, and encodes the
    /// frame's substeps (predict → volume gradient → solve, ping-ponging the
    /// position buffers).
    static func encodeFrame(
        encoder: MTLComputeCommandEncoder,
        pipelines: MusclePipelines,
        state: MuscleSimState,
        frameParams: [MuscleFrameParams],
        substepDelta: Float,
        gravity: simd_float3,
        reset: Bool
    ) {
        state.writeMuscleParams { pointer in
            for (index, params) in frameParams.enumerated() {
                pointer[index] = params
            }
        }
        if reset || state.needsReset {
            state.resetPositions(referencePositions(state: state, frameParams: frameParams))
        }

        var simParams = MuscleSimParams(
            particleCount: UInt32(state.particleCount),
            skinVertexCount: 0,
            dt: substepDelta,
            relaxation: muscleRelaxation,
            gravity: simd_float4(gravity, 0),
            maxVelocity: 8,
            pad0: 0, pad1: 0, pad2: 0
        )
        let width = pipelines.solve.threadExecutionWidth
        let threadgroups = MTLSize(width: (state.particleCount + width - 1) / width, height: 1, depth: 1)
        let threadsPerGroup = MTLSize(width: width, height: 1, depth: 1)

        for _ in 0 ..< muscleSubstepsPerFrame {
            encoder.setComputePipelineState(pipelines.predict)
            encoder.setBuffer(state.currentPositions, offset: 0, index: Int(musclePassPositionsIndex.rawValue))
            encoder.setBuffer(state.prevPositions, offset: 0, index: Int(musclePassPrevPositionsIndex.rawValue))
            encoder.setBuffer(state.particleInfo, offset: 0, index: Int(musclePassParticleInfoIndex.rawValue))
            encoder.setBuffer(state.currentMuscleParams, offset: 0, index: Int(musclePassMuscleParamsIndex.rawValue))
            encoder.setBytes(&simParams, length: MemoryLayout<MuscleSimParams>.stride, index: Int(musclePassParamsIndex.rawValue))
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)

            encoder.setComputePipelineState(pipelines.volumeGradient)
            encoder.setBuffer(state.currentPositions, offset: 0, index: Int(musclePassPositionsIndex.rawValue))
            encoder.setBuffer(state.triangles, offset: 0, index: Int(musclePassTrianglesIndex.rawValue))
            encoder.setBuffer(state.triOffsets, offset: 0, index: Int(musclePassParticleTriOffsetsIndex.rawValue))
            encoder.setBuffer(state.triList, offset: 0, index: Int(musclePassParticleTriListIndex.rawValue))
            encoder.setBuffer(state.gradients, offset: 0, index: Int(musclePassGradientsIndex.rawValue))
            encoder.setBytes(&simParams, length: MemoryLayout<MuscleSimParams>.stride, index: Int(musclePassParamsIndex.rawValue))
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)

            encoder.setComputePipelineState(pipelines.solve)
            encoder.setBuffer(state.currentPositions, offset: 0, index: Int(musclePassPositionsIndex.rawValue))
            encoder.setBuffer(state.nextPositions, offset: 0, index: Int(musclePassPositionsOutIndex.rawValue))
            encoder.setBuffer(state.prevPositions, offset: 0, index: Int(musclePassPrevPositionsIndex.rawValue))
            encoder.setBuffer(state.particleInfo, offset: 0, index: Int(musclePassParticleInfoIndex.rawValue))
            encoder.setBuffer(state.edges, offset: 0, index: Int(musclePassEdgesIndex.rawValue))
            encoder.setBuffer(state.edgeOffsets, offset: 0, index: Int(musclePassParticleEdgeOffsetsIndex.rawValue))
            encoder.setBuffer(state.edgeList, offset: 0, index: Int(musclePassParticleEdgeListIndex.rawValue))
            encoder.setBuffer(state.gradients, offset: 0, index: Int(musclePassGradientsIndex.rawValue))
            encoder.setBuffer(state.currentMuscleParams, offset: 0, index: Int(musclePassMuscleParamsIndex.rawValue))
            encoder.setBytes(&simParams, length: MemoryLayout<MuscleSimParams>.stride, index: Int(musclePassParamsIndex.rawValue))
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)

            state.swapPositions()
        }
    }

    /// Applies the muscle deltas of `state` to skinned vertex streams in
    /// place through `bindings`.
    static func encodeSkinWrap(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        state: MuscleSimState,
        bindings: MTLBuffer,
        positions: MTLBuffer,
        normals: MTLBuffer,
        tangents: MTLBuffer,
        vertexCount: Int
    ) {
        var simParams = MuscleSimParams(
            particleCount: UInt32(state.particleCount),
            skinVertexCount: UInt32(vertexCount),
            dt: 0,
            relaxation: 0,
            gravity: simd_float4(0, 0, 0, 0),
            maxVelocity: 0,
            pad0: 0, pad1: 0, pad2: 0
        )
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(positions, offset: 0, index: Int(musclePassSkinPositionsIndex.rawValue))
        encoder.setBuffer(normals, offset: 0, index: Int(musclePassSkinNormalsIndex.rawValue))
        encoder.setBuffer(tangents, offset: 0, index: Int(musclePassSkinTangentsIndex.rawValue))
        encoder.setBuffer(bindings, offset: 0, index: Int(musclePassSkinBindingIndex.rawValue))
        encoder.setBuffer(state.currentPositions, offset: 0, index: Int(musclePassPositionsIndex.rawValue))
        encoder.setBuffer(state.particleInfo, offset: 0, index: Int(musclePassParticleInfoIndex.rawValue))
        encoder.setBuffer(state.tets, offset: 0, index: Int(musclePassTetsIndex.rawValue))
        encoder.setBuffer(state.currentMuscleParams, offset: 0, index: Int(musclePassMuscleParamsIndex.rawValue))
        encoder.setBytes(&simParams, length: MemoryLayout<MuscleSimParams>.stride, index: Int(musclePassParamsIndex.rawValue))
        let width = pipeline.threadExecutionWidth
        encoder.dispatchThreadgroups(
            MTLSize(width: (vertexCount + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
    }

    /// Bakes the skin binding of `positions` (bind-pose model space) into a
    /// GPU buffer. Returns nil when the buffer cannot be allocated.
    static func makeSkinBindingBuffer(positions: [simd_float4], geometry: MuscleBakedGeometry, device: MTLDevice, label: String) -> (buffer: MTLBuffer, boundCount: Int)? {
        let bindings = MuscleGeometryBuilder.bindSkin(positions: positions, geometry: geometry)
        let length = bindings.count * MemoryLayout<MuscleSkinBinding>.stride
        let buffer = bindings.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: baseAddress, length: length, options: .storageModeShared)
        }
        guard let buffer else { return nil }
        buffer.label = "\(label) muscle skin binding"
        return (buffer, bindings.filter { $0.tetIndex != MUSCLE_SKIN_UNBOUND }.count)
    }

    static func transformPoint(_ matrix: simd_float4x4, _ point: simd_float3) -> simd_float3 {
        let transformed = matrix * simd_float4(point, 1)
        return simd_float3(transformed.x, transformed.y, transformed.z)
    }
}

extension DeformationSystem {
    var musclePipelines: MusclePipelines? {
        guard let predict = musclePredictPipeline.pipelineState,
              let gradient = muscleVolumeGradientPipeline.pipelineState,
              let solve = muscleSolvePipeline.pipelineState,
              let skinWrap = muscleSkinWrapPipeline.pipelineState
        else { return nil }
        return MusclePipelines(predict: predict, volumeGradient: gradient, solve: solve, skinWrap: skinWrap)
    }

    /// Returns the entity's live muscle state, baking the rig on first use.
    /// Nil when the skeleton carries no rig or nothing in it resolves.
    func muscleState(
        for component: DeformationComponent,
        skeleton: Skeleton,
        device: MTLDevice,
        label: String
    ) -> MuscleSimState? {
        if let existing = component.muscleSim {
            return existing
        }
        guard let rig = skeleton.muscleRig, !component.muscleBakeFailed else { return nil }
        guard let geometry = MuscleGeometryBuilder.bake(rig: rig, skeleton: skeleton),
              let state = MuscleSimState(geometry: geometry, device: device, label: label)
        else {
            component.muscleBakeFailed = true
            Logger.logWarning(message: "Muscle rig for \(label) could not be built")
            return nil
        }
        component.muscleSim = state
        Logger.log(message: "Muscle rig built for \(label): \(geometry.muscles.count) muscles, \(geometry.particleCount) particles, \(geometry.tets.count) tets")
        return state
    }

    /// Advances the entity's muscle simulation one frame from the current
    /// pose: activation, frame parameters, substeps.
    func encodeMuscleSimulation(
        encoder: MTLComputeCommandEncoder,
        state: MuscleSimState,
        component: DeformationComponent,
        entityId: EntityID,
        skeleton: Skeleton
    ) {
        guard let pipelines = musclePipelines,
              skeleton.currentPose.count == skeleton.jointPaths.count
        else { return }

        let frameDelta = min(max(timeSinceLastUpdate ?? (1.0 / 90.0), 1.0 / 240.0), 1.0 / 30.0)
        let substepDelta = frameDelta / Float(muscleSubstepsPerFrame)
        let animationComponent = scene.get(component: AnimationComponent.self, for: entityId)
        let localRotations = animationComponent?.hasSampledPose == true ? animationComponent?.localPose.rotations : nil

        let targets = state.geometry.muscles.map { muscle in
            MuscleSimulator.activationTarget(
                muscle: muscle,
                localRotations: localRotations,
                restTransforms: skeleton.restTransform,
                override: component.muscleActivationOverride,
                manual: component.muscleActivations
            )
        }
        MuscleSimulator.smoothActivations(state: state, targets: targets, frameDelta: frameDelta)
        let frameParams = MuscleSimulator.frameParams(
            state: state,
            currentPose: skeleton.currentPose,
            disabledMuscles: component.disabledMuscles,
            substepDelta: substepDelta
        )
        MuscleSimulator.encodeFrame(
            encoder: encoder,
            pipelines: pipelines,
            state: state,
            frameParams: frameParams,
            substepDelta: substepDelta,
            gravity: component.muscleGravity,
            reset: component.muscleResetRequested
        )
        component.muscleResetRequested = false
    }

    /// Applies the muscle deltas to one mesh's deformed streams. Kicks off the
    /// mesh's skin-binding bake on first use and skips the mesh until it is
    /// ready.
    func encodeMuscleSkinWrap(
        encoder: MTLComputeCommandEncoder,
        state: MuscleSimState,
        mesh: Mesh,
        output: MeshDeformationBuffers,
        device: MTLDevice
    ) {
        guard let pipeline = muscleSkinWrapPipeline.pipelineState else { return }
        let key = ObjectIdentifier(mesh.metalKitMesh)
        let bindingBuffer: MTLBuffer
        switch state.bindingState(for: key) {
        case let .ready(buffer):
            bindingBuffer = buffer
        case .building:
            return
        case nil:
            startSkinBindingBake(state: state, mesh: mesh, key: key, device: device)
            return
        }
        MuscleSimulator.encodeSkinWrap(
            encoder: encoder,
            pipeline: pipeline,
            state: state,
            bindings: bindingBuffer,
            positions: output.positions,
            normals: output.normals,
            tangents: output.tangents,
            vertexCount: output.vertexCount
        )
    }

    private func startSkinBindingBake(state: MuscleSimState, mesh: Mesh, key: ObjectIdentifier, device: MTLDevice) {
        let vertexCount = mesh.metalKitMesh.vertexCount
        let buffer = mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer
        let pointer = buffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let positions = Array(UnsafeBufferPointer(start: pointer, count: vertexCount))
        let geometry = state.geometry
        let meshName = mesh.name

        state.setBindingState(.building, for: key)
        MuscleSimState.bakeQueue.async {
            if let result = MuscleSimulator.makeSkinBindingBuffer(positions: positions, geometry: geometry, device: device, label: meshName) {
                state.setBindingState(.ready(result.buffer), for: key)
                Logger.log(message: "Muscle skin binding finished for mesh \(meshName): \(result.boundCount)/\(positions.count) vertices bound")
            } else {
                state.setBindingState(nil, for: key)
            }
        }
    }
}

// MARK: - Public API

/// Replaces the muscle rig of `entityId`'s skeleton (resolved through the
/// hierarchy like `setEntityDeformation`). Passing nil removes the rig. Any
/// running simulation is rebuilt from the new rig on the next frame.
public func setEntityMuscleRig(entityId: EntityID, rig: MuscleRig?) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: targetEntityId),
              let skeleton = skeletonComponent.skeleton
        else { continue }
        skeleton.muscleRig = rig
        if let component = scene.get(component: DeformationComponent.self, for: targetEntityId) {
            component.muscleSim = nil
            component.muscleBakeFailed = false
        }
    }
}

/// Enables or disables the volumetric muscle simulation on `entityId`.
/// Requires a DeformationComponent (a compute skinning path) and a muscle rig
/// on the skeleton (from the asset or `setEntityMuscleRig`).
public func setEntityMuscleSimulation(entityId: EntityID, enabled: Bool) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.musclesEnabled = enabled
        if enabled {
            component.muscleResetRequested = true
        }
    }
}

/// Manual activation (0...1) of a named muscle. While set it takes precedence
/// over the muscle's pose driver; zero clears it and returns control to the
/// driver. The override set by `setEntityMuscleActivationOverride` beats both.
public func setEntityMuscleActivation(entityId: EntityID, name: String, activation: Float) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        if activation > 1e-4 {
            component.muscleActivations[name] = min(activation, 1)
        } else {
            component.muscleActivations.removeValue(forKey: name)
        }
    }
}

/// Shows or hides one muscle of `entityId`: a disabled muscle keeps
/// simulating (and stays in the debug overlay, greyed) but no longer moves
/// the skin.
public func setEntityMuscleEnabled(entityId: EntityID, name: String, enabled: Bool) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        if enabled {
            component.disabledMuscles.remove(name)
        } else {
            component.disabledMuscles.insert(name)
        }
    }
}

/// Forces every muscle of `entityId` to the given activation (0...1); nil
/// returns control to the drivers and manual activations.
public func setEntityMuscleActivationOverride(entityId: EntityID, activation: Float?) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.muscleActivationOverride = activation.map { min(max($0, 0), 1) }
    }
}

/// Model-space gravity applied to free muscle particles (jiggle); the default
/// is a fraction of Earth gravity.
public func setEntityMuscleGravity(entityId: EntityID, gravity: simd_float3) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.muscleGravity = gravity
    }
}

/// Names of the muscles in `entityId`'s rig, in definition order.
public func entityMuscleNames(entityId: EntityID) -> [String] {
    guard scene.exists(entityId) else { return [] }
    var names: [String] = []
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let skeleton = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton,
              let rig = skeleton.muscleRig
        else { continue }
        for muscle in rig.muscles where !names.contains(muscle.name) {
            names.append(muscle.name)
        }
    }
    return names
}
