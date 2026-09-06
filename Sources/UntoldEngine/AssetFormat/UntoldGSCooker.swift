//
//  UntoldGSCooker.swift
//  UntoldEngine
//
//  Prepares an imported Gaussian splat capture for baking: bakes a
//  registration transform into every splat, drops near-transparent and
//  degenerate splats, crops to a box, and selects the spherical-harmonics
//  degree. Works on the importer's structs so `bakeGaussianSplatProgressiveTiers`
//  can rank, box and tier the result exactly as before. The `export` command's
//  `--splat-*` flags map onto `UntoldGSCookOptions`.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd

/// Which axis points up in the capture. Captures are rotated to the engine's Y-up frame
/// before any other transform, so a cooked file never needs a correction in the scene.
public enum UntoldGSCaptureUpAxis: String, CaseIterable, Sendable {
    /// Already the engine convention: +Y up, −Z forward. No rotation.
    case y
    /// Scanner and CAD convention (+Z up): rotated −90° about X, (x, y, z) → (x, z, −y).
    case z
    /// The 3DGS training convention (−Y up, +Z forward): rotated 180° about X, (x, y, z) → (x, −y, −z).
    case negativeY = "-y"

    /// Rotation that brings this convention to Y-up.
    public var rotation: simd_float4x4 {
        switch self {
        case .y:
            matrix_identity_float4x4
        case .z:
            simd_float4x4(simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0)))
        case .negativeY:
            simd_float4x4(diagonal: SIMD4<Float>(1, -1, -1, 1))
        }
    }
}

public struct UntoldGSCookOptions: Sendable {
    /// Similarity transform (rotation, uniform scale, translation) from capture space to the
    /// space the payload is used in. Baked into every splat and recorded in the header.
    /// Build it with `UntoldGSCookOptions.transform(upAxis:scale:yawDegrees:translation:)`
    /// to compose the common cases in the right order.
    public var transform: simd_float4x4 = matrix_identity_float4x4
    /// Optional crop box in the transformed space; splats whose centre falls outside are dropped.
    public var cropMin: SIMD3<Float>?
    public var cropMax: SIMD3<Float>?
    /// Grows the crop box on every side.
    public var cropMargin: Float = 0
    /// Splats with a lower post-sigmoid opacity are dropped.
    public var minimumOpacity: Float = 0.005
    /// Keeps at most this many splats after the other pruning steps, the most important first
    /// (opacity times the geometric mean of the three scales, in the transformed space). `nil`
    /// keeps every survivor. The runtime refuses to load an entity above
    /// `GaussianRuntimeLimits.maxSplatsPerEntity`, so a capture meant for every platform is
    /// cooked with `splatBudgetMobile`; one that only has to load on a Mac may use `splatBudgetMac`.
    public var maxSplatCount: Int?

    /// The per-entity splat cap of Apple Vision Pro, iPhone, iPad and Apple TV.
    public static let splatBudgetMobile = GaussianRuntimeLimits.maxSplatsPerEntityMobile
    /// The per-entity splat cap of the Mac.
    public static let splatBudgetMac = GaussianRuntimeLimits.maxSplatsPerEntityMac
    /// Spherical-harmonics degree to keep. `nil` keeps the source degree (capped at 3); 0 drops SH.
    public var shDegree: UInt8?
    /// log2 of the maximum splat count per chunk. 10 (1024) for objects, 12 (4096) for environments.
    public var log2ChunkSplats: UInt8 = UntoldGSFormat.defaultLog2ChunkSplats
    public var antialiased = false
    public var isEnvironment = false
    public var captureExposureEV: Float = 0
    public var captureWhiteBalance = SIMD3<Float>(repeating: 1)

    public init() {}

    /// Composes the registration transform the cookers expose: up-axis fix first, then
    /// uniform scale, then yaw about the engine's +Y, then translation.
    public static func transform(
        upAxis: UntoldGSCaptureUpAxis = .y,
        scale: Float = 1,
        yawDegrees: Float = 0,
        translation: SIMD3<Float> = .zero
    ) -> simd_float4x4 {
        var transform = simd_mul(simd_float4x4(diagonal: SIMD4<Float>(scale, scale, scale, 1)), upAxis.rotation)
        if yawDegrees != 0 {
            let yaw = simd_quatf(angle: yawDegrees * .pi / 180, axis: SIMD3<Float>(0, 1, 0))
            transform = simd_mul(simd_float4x4(yaw), transform)
        }
        transform.columns.3 = SIMD4<Float>(translation, 1)
        return transform
    }
}

public struct UntoldGSCookReport: Sendable, Equatable {
    public var inputSplatCount: Int
    public var keptSplatCount: Int
    public var prunedByOpacity: Int
    public var prunedByDegenerateGeometry: Int
    public var prunedByCrop: Int
    /// Splats dropped to meet `UntoldGSCookOptions.maxSplatCount`, the least important first.
    public var prunedByBudget: Int
    public var shDegree: UInt8

    public init(inputSplatCount: Int, keptSplatCount: Int, prunedByOpacity: Int, prunedByDegenerateGeometry: Int, prunedByCrop: Int, shDegree: UInt8, prunedByBudget: Int = 0) {
        self.inputSplatCount = inputSplatCount
        self.keptSplatCount = keptSplatCount
        self.prunedByOpacity = prunedByOpacity
        self.prunedByDegenerateGeometry = prunedByDegenerateGeometry
        self.prunedByCrop = prunedByCrop
        self.prunedByBudget = prunedByBudget
        self.shDegree = shDegree
    }

    /// A cook that changed nothing: every splat kept at the source degree.
    public static func passthrough(splatCount: Int, shDegree: UInt8) -> UntoldGSCookReport {
        UntoldGSCookReport(inputSplatCount: splatCount, keptSplatCount: splatCount, prunedByOpacity: 0, prunedByDegenerateGeometry: 0, prunedByCrop: 0, shDegree: shDegree)
    }
}

public enum UntoldGSCookError: Error, Equatable, CustomStringConvertible {
    /// The transform mirrors, shears or scales non-uniformly; splat covariances need a similarity.
    case transformIsNotASimilarity
    case requestedSHDegreeExceedsSource(requested: UInt8, source: UInt8)
    case noSplatsLeftAfterPruning(UntoldGSCookReport)

    public var description: String {
        switch self {
        case .transformIsNotASimilarity:
            "the splat transform must be a rotation, a uniform scale and a translation"
        case let .requestedSHDegreeExceedsSource(requested, source):
            "requested spherical-harmonics degree \(requested) but the source has degree \(source)"
        case let .noSplatsLeftAfterPruning(report):
            "no splats left after pruning: \(report.prunedByOpacity) below the opacity floor, "
                + "\(report.prunedByDegenerateGeometry) degenerate, \(report.prunedByCrop) outside the crop box"
        }
    }
}

public enum UntoldGSCooker {
    /// Applies the options to an imported asset and returns the asset to bake plus a report.
    public static func cook(asset: GaussianSplatAsset, options: UntoldGSCookOptions = .init()) throws -> (asset: GaussianSplatAsset, report: UntoldGSCookReport) {
        let similarity = try Similarity(options.transform)
        let sourceDegree = UInt8(clamping: asset.sphericalHarmonics?.degree ?? 0)
        let targetDegree = min(options.shDegree ?? sourceDegree, UntoldGSFormat.maxSHDegree)
        guard targetDegree <= sourceDegree else {
            throw UntoldGSCookError.requestedSHDegreeExceedsSource(requested: targetDegree, source: sourceDegree)
        }

        let crop: (min: SIMD3<Float>, max: SIMD3<Float>)? = {
            guard let cropMin = options.cropMin, let cropMax = options.cropMax else { return nil }
            let margin = SIMD3<Float>(repeating: options.cropMargin)
            return (cropMin - margin, cropMax + margin)
        }()

        var kept: [GaussianSplat] = []
        kept.reserveCapacity(asset.splats.count)
        var keptIndices: [Int] = []
        keptIndices.reserveCapacity(asset.splats.count)
        var prunedByOpacity = 0
        var prunedByDegenerate = 0
        var prunedByCrop = 0

        for (index, splat) in asset.splats.enumerated() {
            guard splat.opacity >= options.minimumOpacity else {
                prunedByOpacity += 1
                continue
            }
            let scale = SIMD3<Float>(splat.scale.x, splat.scale.y, splat.scale.z)
            let center = SIMD3<Float>(splat.center.x, splat.center.y, splat.center.z)
            guard isFinite(center), isFinite(scale), scale.min() > 0,
                  splat.quat.x.isFinite, splat.quat.y.isFinite, splat.quat.z.isFinite, splat.quat.w.isFinite,
                  simd_length_squared(splat.quat) > 0
            else {
                prunedByDegenerate += 1
                continue
            }
            let transformed = similarity.apply(to: splat)
            if let crop {
                let p = SIMD3<Float>(transformed.center.x, transformed.center.y, transformed.center.z)
                guard p.x >= crop.min.x, p.y >= crop.min.y, p.z >= crop.min.z,
                      p.x <= crop.max.x, p.y <= crop.max.y, p.z <= crop.max.z
                else {
                    prunedByCrop += 1
                    continue
                }
            }
            kept.append(transformed)
            keptIndices.append(index)
        }

        var prunedByBudget = 0
        if let budget = options.maxSplatCount, budget > 0, kept.count > budget {
            let survivors = selectMostImportant(kept, count: budget)
            prunedByBudget = kept.count - survivors.count
            kept = survivors.map { kept[$0] }
            keptIndices = survivors.map { keptIndices[$0] }
        }

        let report = UntoldGSCookReport(
            inputSplatCount: asset.splats.count,
            keptSplatCount: kept.count,
            prunedByOpacity: prunedByOpacity,
            prunedByDegenerateGeometry: prunedByDegenerate,
            prunedByCrop: prunedByCrop,
            shDegree: targetDegree,
            prunedByBudget: prunedByBudget
        )
        guard !kept.isEmpty else {
            throw UntoldGSCookError.noSplatsLeftAfterPruning(report)
        }

        let harmonics = reduceSphericalHarmonics(asset.sphericalHarmonics, keeping: keptIndices, toDegree: targetDegree)
        return (GaussianSplatAsset(splats: kept, sphericalHarmonics: harmonics), report)
    }

    /// How much a splat is worth keeping: its opacity times the geometric mean of its scales,
    /// a proxy for the light it contributes over the area it covers. Cheap, view independent
    /// and enough to shed the faint, tiny splats a budget has to drop first.
    static func importance(of splat: GaussianSplat) -> Float {
        let volume = max(splat.scale.x * splat.scale.y * splat.scale.z, 0)
        return splat.opacity * cbrt(volume)
    }

    /// Indices (ascending, so the source order survives) of the `count` most important splats.
    /// Ties at the cut-off keep the earlier splats.
    static func selectMostImportant(_ splats: [GaussianSplat], count: Int) -> [Int] {
        guard count < splats.count else { return Array(splats.indices) }
        let importance = splats.map(importance(of:))
        let threshold = importance.sorted(by: >)[count - 1]
        var selected: [Int] = []
        selected.reserveCapacity(count)
        var tiesLeft = count - importance.filter { $0 > threshold }.count
        for (index, value) in importance.enumerated() {
            if value > threshold {
                selected.append(index)
            } else if value == threshold, tiesLeft > 0 {
                selected.append(index)
                tiesLeft -= 1
            }
        }
        return selected
    }

    /// Write options that carry the cook's chunk size, flags, transform and capture lighting.
    public static func writeOptions(for options: UntoldGSCookOptions) -> UntoldGSWriteOptions {
        var write = UntoldGSWriteOptions()
        write.log2ChunkSplats = options.log2ChunkSplats
        write.antialiased = options.antialiased
        write.isEnvironment = options.isEnvironment
        write.splatToMesh = options.transform
        write.captureExposureEV = options.captureExposureEV
        write.captureWhiteBalance = options.captureWhiteBalance
        return write
    }

    // MARK: - Spherical harmonics

    /// Keeps the DC term and the low orders of each channel for `degree`, in the importer's
    /// channel-major layout; `nil` for degree 0.
    static func reduceSphericalHarmonics(_ harmonics: GaussianSphericalHarmonics?, keeping indices: [Int], toDegree degree: UInt8) -> GaussianSphericalHarmonics? {
        guard let harmonics, degree > 0 else { return nil }
        let targetPerChannel = Int(degree + 1) * Int(degree + 1)
        let sourcePerChannel = harmonics.coefficientsPerChannel
        let sourcePerSplat = sourcePerChannel * 3
        var reduced: [Float] = []
        reduced.reserveCapacity(indices.count * targetPerChannel * 3)
        for index in indices {
            let base = index * sourcePerSplat
            for channel in 0 ..< 3 {
                let start = base + channel * sourcePerChannel
                reduced.append(contentsOf: harmonics.coefficients[start ..< start + targetPerChannel])
            }
        }
        return GaussianSphericalHarmonics(degree: Int(degree), coefficientsPerChannel: targetPerChannel, coefficients: reduced)
    }

    // MARK: - Transform

    /// Rotation, uniform scale and translation extracted from a similarity matrix.
    struct Similarity {
        var rotation: simd_quatf
        var scale: Float
        var matrix: simd_float4x4
        var isIdentity: Bool

        init(_ matrix: simd_float4x4) throws {
            self.matrix = matrix
            isIdentity = matrix == matrix_identity_float4x4
            let c0 = SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)
            let c1 = SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)
            let c2 = SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z)
            let lengths = SIMD3<Float>(simd_length(c0), simd_length(c1), simd_length(c2))
            let scale = (lengths.x + lengths.y + lengths.z) / 3
            let determinant = simd_dot(c0, simd_cross(c1, c2))
            let tolerance = scale * 0.01
            guard scale > 0, determinant > 0,
                  abs(lengths.x - scale) <= tolerance, abs(lengths.y - scale) <= tolerance, abs(lengths.z - scale) <= tolerance,
                  abs(simd_dot(c0, c1)) <= scale * tolerance,
                  abs(simd_dot(c1, c2)) <= scale * tolerance,
                  abs(simd_dot(c0, c2)) <= scale * tolerance
            else {
                throw UntoldGSCookError.transformIsNotASimilarity
            }
            rotation = simd_normalize(simd_quatf(simd_float3x3(c0 / scale, c1 / scale, c2 / scale)))
            self.scale = scale
        }

        func apply(to splat: GaussianSplat) -> GaussianSplat {
            guard !isIdentity else { return splat }
            var result = splat
            let center = matrix * SIMD4<Float>(splat.center.x, splat.center.y, splat.center.z, 1)
            result.center = SIMD4<Float>(center.x, center.y, center.z, 1)
            result.scale = SIMD4<Float>(splat.scale.x * scale, splat.scale.y * scale, splat.scale.z * scale, 1)
            // The importer keeps the PLY order (w, x, y, z).
            let q = simd_quatf(ix: splat.quat.y, iy: splat.quat.z, iz: splat.quat.w, r: splat.quat.x)
            let rotated = simd_normalize(rotation * q)
            result.quat = SIMD4<Float>(rotated.real, rotated.imag.x, rotated.imag.y, rotated.imag.z)
            return result
        }
    }

    static func isFinite(_ v: SIMD3<Float>) -> Bool {
        v.x.isFinite && v.y.isFinite && v.z.isFinite
    }
}
