//
//  MLDeformerModel.swift
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

/// A loaded ML deformer bound to one skeleton: the payload, its joints
/// resolved to skeleton indices, per-mesh GPU tables and a ring of
/// coefficient buffers written once per frame.
final class MLDeformerModel: @unchecked Sendable {
    struct MeshTables {
        let activeIndices: MTLBuffer
        let deltaMean: MTLBuffer
        let basis: MTLBuffer
        let activeCount: Int
        let vertexCount: Int
    }

    let payload: MLDeformerPayload
    /// Skeleton joint index per payload joint (nil when the rig lacks it).
    let jointIndices: [Int?]
    private let tablesByMeshName: [String: MeshTables]
    private let coefficientRing: [MTLBuffer]
    private var ringIndex = 0

    var currentCoefficients: MTLBuffer {
        coefficientRing[ringIndex]
    }

    init?(payload: MLDeformerPayload, skeleton: Skeleton, device: MTLDevice, label: String) {
        self.payload = payload
        jointIndices = payload.jointPaths.map { skeleton.muscleJointIndex(named: $0) }

        let channels = MLDeformerPayload.channelsPerVertex
        let k = payload.componentCount
        let totalActive = payload.activeCount
        var tables: [String: MeshTables] = [:]
        for mesh in payload.meshes where mesh.activeCount > 0 {
            let range = mesh.activeStart ..< mesh.activeStart + mesh.activeCount
            let indices = Array(payload.activeIndices[range])
            let mean = Array(payload.deltaMean[range.lowerBound * channels ..< range.upperBound * channels])
            var basis: [UInt16] = []
            basis.reserveCapacity(k * mesh.activeCount * channels)
            for component in 0 ..< k {
                let base = (component * totalActive + range.lowerBound) * channels
                basis.append(contentsOf: payload.basis[base ..< base + mesh.activeCount * channels])
            }
            guard let indexBuffer = Self.makeBuffer(indices, device: device, label: "\(label) ML active indices"),
                  let meanBuffer = Self.makeBuffer(mean, device: device, label: "\(label) ML delta mean"),
                  let basisBuffer = Self.makeBuffer(basis, device: device, label: "\(label) ML basis")
            else { return nil }
            tables[mesh.name] = MeshTables(
                activeIndices: indexBuffer, deltaMean: meanBuffer, basis: basisBuffer,
                activeCount: mesh.activeCount, vertexCount: mesh.vertexCount
            )
        }
        tablesByMeshName = tables

        var ring: [MTLBuffer] = []
        let length = max(k, 1) * MemoryLayout<Float>.stride
        for slot in 0 ..< (maxInFlightCommandBuffers + 1) {
            guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else { return nil }
            buffer.label = "\(label) ML coefficients \(slot)"
            ring.append(buffer)
        }
        coefficientRing = ring
    }

    private static func makeBuffer<T>(_ values: [T], device: MTLDevice, label: String) -> MTLBuffer? {
        let length = values.count * MemoryLayout<T>.stride
        guard length > 0 else { return nil }
        let buffer = values.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: baseAddress, length: length, options: .storageModeShared)
        }
        buffer?.label = label
        return buffer
    }

    func tablesForTesting(name: String) -> MeshTables? {
        tablesByMeshName[name]
    }

    /// Tables for a runtime mesh, matched by the primitive name the baker
    /// recorded and the vertex count.
    func tables(for mesh: Mesh) -> MeshTables? {
        let candidates = [mesh.assetName, mesh.name]
        for name in candidates {
            if let tables = tablesByMeshName[name], tables.vertexCount == mesh.metalKitMesh.vertexCount {
                return tables
            }
        }
        return nil
    }

    /// Predicts this pose's coefficients and stores them in the next ring
    /// slot. `localRotations` are the sampled local joint rotations.
    func updateCoefficients(localRotations: [simd_quatf], restTransforms: [simd_float4x4]) {
        let rotations: [simd_quatf?] = jointIndices.map { index in
            guard let index, index < localRotations.count, index < restTransforms.count else { return nil }
            let rest = PoseDriverEvaluation.restRotation(from: restTransforms[index])
            return rest.inverse * localRotations[index]
        }
        let coefficients = payload.evaluate(features: MLDeformerPayload.features(rotations: rotations))
        ringIndex = (ringIndex + 1) % coefficientRing.count
        let pointer = coefficientRing[ringIndex].contents().bindMemory(to: Float.self, capacity: coefficients.count)
        for (index, value) in coefficients.enumerated() {
            pointer[index] = value
        }
    }

    /// Adds the decoded deltas to one mesh's deformed streams in place.
    func encodeDecode(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        mesh: Mesh,
        output: MeshDeformationBuffers,
        weight: Float
    ) {
        guard let tables = tables(for: mesh), weight > 0 else { return }
        var params = MLDecodeParams(
            activeCount: UInt32(tables.activeCount),
            vertexCount: UInt32(output.vertexCount),
            componentCount: UInt32(payload.componentCount),
            weight: min(weight, 1)
        )
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(output.positions, offset: 0, index: Int(mlDecodePositionsIndex.rawValue))
        encoder.setBuffer(output.normals, offset: 0, index: Int(mlDecodeNormalsIndex.rawValue))
        encoder.setBuffer(tables.activeIndices, offset: 0, index: Int(mlDecodeActiveIndicesIndex.rawValue))
        encoder.setBuffer(tables.deltaMean, offset: 0, index: Int(mlDecodeDeltaMeanIndex.rawValue))
        encoder.setBuffer(tables.basis, offset: 0, index: Int(mlDecodeBasisIndex.rawValue))
        encoder.setBuffer(currentCoefficients, offset: 0, index: Int(mlDecodeCoefficientsIndex.rawValue))
        encoder.setBytes(&params, length: MemoryLayout<MLDecodeParams>.stride, index: Int(mlDecodeParamsIndex.rawValue))
        let width = pipeline.threadExecutionWidth
        encoder.dispatchThreadgroups(
            MTLSize(width: (tables.activeCount + width - 1) / width, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
    }
}

/// What the background load takes across to its queue: the skeleton, which
/// it only reads joint names from, and the component, whose load state it
/// writes under the component's own lock.
private struct MLDeformerLoadRequest: @unchecked Sendable {
    let component: DeformationComponent
    let skeleton: Skeleton
}

/// Background load state of an entity's ML deformer.
enum MLDeformerLoadState {
    case loading
    case ready(MLDeformerModel)
    case failed
}

extension DeformationSystem {
    static let mlDeformerLoadQueue = DispatchQueue(label: "com.untoldengine.mldeformer-load", qos: .utility)

    /// The entity's ML deformer, kicking off the payload load on first use.
    /// Nil until it is ready (or when there is no payload to load).
    func mlDeformerModel(
        for component: DeformationComponent,
        skeleton: Skeleton,
        device: MTLDevice,
        label: String
    ) -> MLDeformerModel? {
        switch component.mlDeformerState {
        case let .ready(model):
            return model
        case .loading, .failed:
            return nil
        case nil:
            break
        }
        guard let url = component.mlDeformerURL ?? skeleton.mlDeformerURL else {
            component.mlDeformerState = .failed
            Logger.logWarning(message: "No ML deformer payload for \(label)")
            return nil
        }
        component.mlDeformerState = .loading
        let lock = component.mlDeformerLock
        let request = MLDeformerLoadRequest(component: component, skeleton: skeleton)
        Self.mlDeformerLoadQueue.async {
            do {
                let payload = try MLDeformerPayload(contentsOf: url)
                guard let model = MLDeformerModel(payload: payload, skeleton: request.skeleton, device: device, label: label) else {
                    throw MLDeformerPayloadError.inconsistent("GPU tables")
                }
                lock.lock()
                request.component.mlDeformerState = .ready(model)
                lock.unlock()
                Logger.log(message: "ML deformer loaded for \(label): \(payload.jointPaths.count) joints, \(payload.componentCount) components, \(payload.activeCount) active vertices")
            } catch {
                lock.lock()
                request.component.mlDeformerState = .failed
                lock.unlock()
                Logger.logWarning(message: "ML deformer payload \(url.lastPathComponent) failed to load: \(error)")
            }
        }
        return nil
    }
}

// MARK: - Public API

/// Enables or disables the ML deformer on `entityId`: a trained network
/// (`.untoldml` next to the asset, or set with `setEntityMLDeformerPayload`)
/// that predicts the muscle skin deltas from the pose and applies them after
/// skinning. Requires a DeformationComponent.
public func setEntityMLDeformer(entityId: EntityID, enabled: Bool) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.mlDeformerEnabled = enabled
    }
}

/// Points `entityId` at an explicit `.untoldml` payload (nil returns to the
/// asset's own), reloading on next use.
public func setEntityMLDeformerPayload(entityId: EntityID, url: URL?) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.mlDeformerURL = url
        component.mlDeformerState = nil
    }
}

/// Blend of the ML deformer's delta (0 = off, 1 = full).
public func setEntityMLDeformerWeight(entityId: EntityID, weight: Float) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else { continue }
        component.mlDeformerWeight = min(max(weight, 0), 1)
    }
}

/// Whether `entityId`'s skeleton has an ML deformer payload to load.
public func entityHasMLDeformerPayload(entityId: EntityID) -> Bool {
    guard scene.exists(entityId) else { return false }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        if let url = scene.get(component: DeformationComponent.self, for: targetEntityId)?.mlDeformerURL,
           FileManager.default.fileExists(atPath: url.path)
        {
            return true
        }
        if let url = scene.get(component: SkeletonComponent.self, for: targetEntityId)?.skeleton?.mlDeformerURL,
           FileManager.default.fileExists(atPath: url.path)
        {
            return true
        }
    }
    return false
}
