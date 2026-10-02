//
//  MLDeformerPayload.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// The `.untoldml` payload of a trained ML deformer: a small MLP that maps
/// the rest-relative rotations of a few joints (6D each) to the
/// coefficients of a PCA basis of skin deltas (position + normal, over the
/// "active" vertices that the simulation ever moved), plus the per-mesh
/// active vertex lists the runtime scatters the decoded deltas through.
///
/// Written by `scripts/train_mldeformer.py` from a `MLDeformerBaker`
/// dataset; found next to a `.untold` by name (`<asset>.untoldml`) or via
/// the asset's `mlDeformerTable` record.
///
/// Layout (little-endian): magic "UNTOLDML", version, featureCount F,
/// hiddenCount H, componentCount K, jointCount J, meshCount M,
/// activeCount A, flags; J joint paths; M mesh ranges; A active vertex
/// indices; inputMean[F], inputStd[F]; W1[H×F], b1[H], W2[H×H], b2[H],
/// W3[K×H], b3[K]; coefficientScale[K]; deltaMean[A×6] and basis[K×A×6] as
/// float16. Strings are a UInt32 byte length followed by UTF-8.
public struct MLDeformerPayload: Sendable, Equatable {
    public static let magic = "UNTOLDML"
    public static let version: UInt32 = 1
    /// Floats per active vertex: position delta xyz, normal delta xyz.
    public static let channelsPerVertex = 6
    /// Features per joint: the first two columns of the rotation matrix.
    public static let featuresPerJoint = 6

    public struct MeshRange: Sendable, Equatable {
        public var name: String
        public var vertexCount: Int
        public var activeStart: Int
        public var activeCount: Int

        public init(name: String, vertexCount: Int, activeStart: Int, activeCount: Int) {
            self.name = name
            self.vertexCount = vertexCount
            self.activeStart = activeStart
            self.activeCount = activeCount
        }
    }

    public var jointPaths: [String]
    public var meshes: [MeshRange]
    /// Mesh-local vertex index of every active vertex, mesh ranges concatenated.
    public var activeIndices: [UInt32]
    public var inputMean: [Float]
    public var inputStd: [Float]
    public var hiddenCount: Int
    /// Row-major [out × in].
    public var weights1: [Float]
    public var bias1: [Float]
    public var weights2: [Float]
    public var bias2: [Float]
    public var weights3: [Float]
    public var bias3: [Float]
    /// The network predicts normalized coefficients; multiply by this.
    public var coefficientScale: [Float]
    /// [A × 6] float16 bit patterns.
    public var deltaMean: [UInt16]
    /// [K × A × 6] float16 bit patterns.
    public var basis: [UInt16]

    public var featureCount: Int {
        jointPaths.count * Self.featuresPerJoint
    }

    public var componentCount: Int {
        coefficientScale.count
    }

    public var activeCount: Int {
        activeIndices.count
    }

    public init(
        jointPaths: [String],
        meshes: [MeshRange],
        activeIndices: [UInt32],
        inputMean: [Float],
        inputStd: [Float],
        hiddenCount: Int,
        weights1: [Float],
        bias1: [Float],
        weights2: [Float],
        bias2: [Float],
        weights3: [Float],
        bias3: [Float],
        coefficientScale: [Float],
        deltaMean: [UInt16],
        basis: [UInt16]
    ) {
        self.jointPaths = jointPaths
        self.meshes = meshes
        self.activeIndices = activeIndices
        self.inputMean = inputMean
        self.inputStd = inputStd
        self.hiddenCount = hiddenCount
        self.weights1 = weights1
        self.bias1 = bias1
        self.weights2 = weights2
        self.bias2 = bias2
        self.weights3 = weights3
        self.bias3 = bias3
        self.coefficientScale = coefficientScale
        self.deltaMean = deltaMean
        self.basis = basis
    }

    /// Checks every array against the header counts.
    public func validate() throws {
        let f = featureCount, h = hiddenCount, k = componentCount, a = activeCount
        guard f > 0, h > 0, k > 0 else { throw MLDeformerPayloadError.inconsistent("empty network") }
        guard inputMean.count == f, inputStd.count == f else { throw MLDeformerPayloadError.inconsistent("input normalization") }
        guard weights1.count == h * f, bias1.count == h else { throw MLDeformerPayloadError.inconsistent("layer 1") }
        guard weights2.count == h * h, bias2.count == h else { throw MLDeformerPayloadError.inconsistent("layer 2") }
        guard weights3.count == k * h, bias3.count == k else { throw MLDeformerPayloadError.inconsistent("layer 3") }
        guard deltaMean.count == a * Self.channelsPerVertex else { throw MLDeformerPayloadError.inconsistent("delta mean") }
        guard basis.count == k * a * Self.channelsPerVertex else { throw MLDeformerPayloadError.inconsistent("basis") }
        var cursor = 0
        for mesh in meshes {
            guard mesh.activeStart == cursor, mesh.activeCount >= 0 else { throw MLDeformerPayloadError.inconsistent("mesh ranges") }
            cursor += mesh.activeCount
            for index in activeIndices[mesh.activeStart ..< mesh.activeStart + mesh.activeCount] where Int(index) >= mesh.vertexCount {
                throw MLDeformerPayloadError.inconsistent("active index out of range in \(mesh.name)")
            }
        }
        guard cursor == a else { throw MLDeformerPayloadError.inconsistent("mesh ranges do not cover the active set") }
    }

    // MARK: - Network evaluation

    /// Pose features of the payload's joints: the first two columns of each
    /// joint's rest-relative local rotation (`rest⁻¹ ∘ current`), 6 floats
    /// per joint. Missing joints contribute the identity.
    public static func features(rotations: [simd_quatf?]) -> [Float] {
        var features: [Float] = []
        features.reserveCapacity(rotations.count * featuresPerJoint)
        for rotation in rotations {
            let matrix = simd_float3x3(rotation ?? simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)))
            features.append(contentsOf: [
                matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z,
                matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z,
            ])
        }
        return features
    }

    /// Runs the MLP: normalized features → SiLU hidden layers → scaled
    /// PCA coefficients.
    public func evaluate(features: [Float]) -> [Float] {
        let f = featureCount, h = hiddenCount, k = componentCount
        guard features.count == f else { return [Float](repeating: 0, count: k) }
        var input = [Float](repeating: 0, count: f)
        for index in 0 ..< f {
            let std = inputStd[index]
            input[index] = (features[index] - inputMean[index]) / (abs(std) > 1e-8 ? std : 1)
        }
        let hidden1 = Self.dense(input: input, weights: weights1, bias: bias1, outputs: h, activate: true)
        let hidden2 = Self.dense(input: hidden1, weights: weights2, bias: bias2, outputs: h, activate: true)
        var output = Self.dense(input: hidden2, weights: weights3, bias: bias3, outputs: k, activate: false)
        for index in 0 ..< k {
            output[index] *= coefficientScale[index]
        }
        return output
    }

    private static func dense(input: [Float], weights: [Float], bias: [Float], outputs: Int, activate: Bool) -> [Float] {
        let inputs = input.count
        var result = [Float](repeating: 0, count: outputs)
        weights.withUnsafeBufferPointer { w in
            input.withUnsafeBufferPointer { x in
                for row in 0 ..< outputs {
                    var sum = bias[row]
                    let base = row * inputs
                    for column in 0 ..< inputs {
                        sum += w[base + column] * x[column]
                    }
                    result[row] = activate ? sum / (1 + exp(-sum)) : sum
                }
            }
        }
        return result
    }

    /// CPU reference of the decode kernel for one active vertex: the six
    /// channels of `mean + Σ coefficient[k] · basis[k]`.
    public func decodedDelta(activeIndex: Int, coefficients: [Float]) -> [Float] {
        let channels = Self.channelsPerVertex
        var delta = (0 ..< channels).map { Float(Float16(bitPattern: deltaMean[activeIndex * channels + $0])) }
        for k in 0 ..< componentCount {
            let base = (k * activeCount + activeIndex) * channels
            for c in 0 ..< channels {
                delta[c] += coefficients[k] * Float(Float16(bitPattern: basis[base + c]))
            }
        }
        return delta
    }

    // MARK: - Binary form

    public func encode() -> Data {
        var writer = LittleEndianWriter()
        writer.append(Array(Self.magic.utf8))
        writer.append(Self.version)
        writer.append(UInt32(featureCount))
        writer.append(UInt32(hiddenCount))
        writer.append(UInt32(componentCount))
        writer.append(UInt32(jointPaths.count))
        writer.append(UInt32(meshes.count))
        writer.append(UInt32(activeCount))
        writer.append(UInt32(0))
        for path in jointPaths {
            writer.append(string: path)
        }
        for mesh in meshes {
            writer.append(string: mesh.name)
            writer.append(UInt32(mesh.vertexCount))
            writer.append(UInt32(mesh.activeStart))
            writer.append(UInt32(mesh.activeCount))
        }
        writer.append(activeIndices)
        writer.append(inputMean)
        writer.append(inputStd)
        writer.append(weights1)
        writer.append(bias1)
        writer.append(weights2)
        writer.append(bias2)
        writer.append(weights3)
        writer.append(bias3)
        writer.append(coefficientScale)
        writer.append(deltaMean)
        writer.append(basis)
        return writer.data
    }

    public init(data: Data) throws {
        var reader = LittleEndianReader(data: data)
        let magic = try reader.readBytes(8)
        guard String(decoding: magic, as: UTF8.self) == Self.magic else { throw MLDeformerPayloadError.badMagic }
        let version = try reader.readUInt32()
        guard version == Self.version else { throw MLDeformerPayloadError.unsupportedVersion(version) }
        let f = try Int(reader.readUInt32())
        let h = try Int(reader.readUInt32())
        let k = try Int(reader.readUInt32())
        let j = try Int(reader.readUInt32())
        let m = try Int(reader.readUInt32())
        let a = try Int(reader.readUInt32())
        _ = try reader.readUInt32()
        guard f == j * Self.featuresPerJoint else { throw MLDeformerPayloadError.inconsistent("feature count") }

        var jointPaths: [String] = []
        for _ in 0 ..< j {
            try jointPaths.append(reader.readString())
        }
        var meshes: [MeshRange] = []
        for _ in 0 ..< m {
            let name = try reader.readString()
            let vertexCount = try Int(reader.readUInt32())
            let activeStart = try Int(reader.readUInt32())
            let activeCount = try Int(reader.readUInt32())
            meshes.append(MeshRange(name: name, vertexCount: vertexCount, activeStart: activeStart, activeCount: activeCount))
        }
        let channels = Self.channelsPerVertex
        try self.init(
            jointPaths: jointPaths,
            meshes: meshes,
            activeIndices: reader.readUInt32Array(a),
            inputMean: reader.readFloatArray(f),
            inputStd: reader.readFloatArray(f),
            hiddenCount: h,
            weights1: reader.readFloatArray(h * f),
            bias1: reader.readFloatArray(h),
            weights2: reader.readFloatArray(h * h),
            bias2: reader.readFloatArray(h),
            weights3: reader.readFloatArray(k * h),
            bias3: reader.readFloatArray(k),
            coefficientScale: reader.readFloatArray(k),
            deltaMean: reader.readUInt16Array(a * channels),
            basis: reader.readUInt16Array(k * a * channels)
        )
        try validate()
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }
}

public enum MLDeformerPayloadError: Error, Equatable {
    case badMagic
    case unsupportedVersion(UInt32)
    case truncated
    case inconsistent(String)
}

// MARK: - Little-endian helpers

struct LittleEndianWriter {
    private(set) var data = Data()

    mutating func append(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }

    mutating func append(_ value: UInt32) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    mutating func append(string: String) {
        let bytes = Array(string.utf8)
        append(UInt32(bytes.count))
        append(bytes)
    }

    mutating func append(_ values: [UInt32]) {
        values.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: UInt8.self) { data.append(contentsOf: $0) }
        }
    }

    mutating func append(_ values: [UInt16]) {
        values.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: UInt8.self) { data.append(contentsOf: $0) }
        }
    }

    mutating func append(_ values: [Float]) {
        values.withUnsafeBufferPointer { buffer in
            buffer.withMemoryRebound(to: UInt8.self) { data.append(contentsOf: $0) }
        }
    }
}

struct LittleEndianReader {
    let data: Data
    private var cursor = 0

    init(data: Data) {
        self.data = data
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard count >= 0, cursor + count <= data.count else { throw MLDeformerPayloadError.truncated }
        let bytes = Array(data[data.startIndex + cursor ..< data.startIndex + cursor + count])
        cursor += count
        return bytes
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readBytes(4)
        return UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
    }

    mutating func readString() throws -> String {
        let length = try Int(readUInt32())
        return try String(decoding: readBytes(length), as: UTF8.self)
    }

    mutating func readUInt32Array(_ count: Int) throws -> [UInt32] {
        let bytes = try readBytes(count * 4)
        return (0 ..< count).map { index in
            let base = index * 4
            return UInt32(bytes[base]) | UInt32(bytes[base + 1]) << 8 | UInt32(bytes[base + 2]) << 16 | UInt32(bytes[base + 3]) << 24
        }
    }

    mutating func readUInt16Array(_ count: Int) throws -> [UInt16] {
        let bytes = try readBytes(count * 2)
        return (0 ..< count).map { index in
            UInt16(bytes[index * 2]) | UInt16(bytes[index * 2 + 1]) << 8
        }
    }

    mutating func readFloatArray(_ count: Int) throws -> [Float] {
        try readUInt32Array(count).map { Float(bitPattern: $0) }
    }
}
