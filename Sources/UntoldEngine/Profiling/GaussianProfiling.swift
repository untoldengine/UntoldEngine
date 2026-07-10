//
//  GaussianProfiling.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import QuartzCore

struct GaussianProfileTotals {
    var entityCount: Int = 0
    var splatCount: Int = 0
    var drawCallCount: Int = 0
    var dispatchCount: Int = 0
    var radixPassCount: Int = 0
    var encodedBytes: Int = 0
    var sortedIndexBytes: Int = 0
    var visibleIndexBytes: Int = 0
    var visibleCountBytes: Int = 0
    var sphericalHarmonicsBytes: Int = 0
    var uniformBytes: Int = 0
    var scratchBytes: Int = 0
    var maxSphericalHarmonicsDegree: UInt32 = 0
    var higherOrderCoefficientsPerSplat: UInt32 = 0

    var totalResidentBytes: Int {
        encodedBytes + sortedIndexBytes + visibleIndexBytes + visibleCountBytes + sphericalHarmonicsBytes + uniformBytes + scratchBytes
    }

    mutating func include(component: GaussianComponent) {
        entityCount += 1
        splatCount += Int(component.splatCount)
        encodedBytes += component.encodedSplatData?.length ?? 0
        sortedIndexBytes += component.gaussianSortedIndices?.length ?? 0
        visibleIndexBytes += component.gaussianVisibleIndices?.length ?? 0
        visibleCountBytes += component.gaussianVisibleCount?.length ?? 0
        if let shBuffer = component.sphericalHarmonicsData {
            sphericalHarmonicsBytes += shBuffer.length
        }
        uniformBytes += component.spaceUniform.reduce(0) { total, buffer in
            total + (buffer?.length ?? 0)
        }
        if let metadata = component.sphericalHarmonicsMetadata {
            maxSphericalHarmonicsDegree = max(maxSphericalHarmonicsDegree, metadata.degree)
            higherOrderCoefficientsPerSplat = max(
                higherOrderCoefficientsPerSplat,
                metadata.higherOrderCoefficientsPerSplat
            )
        }
    }
}

@inline(__always)
func gaussianProfilingStartTime() -> CFTimeInterval? {
    guard Logger.isEnabled(category: .gaussian) else { return nil }
    return CACurrentMediaTime()
}

func logGaussianProfile(
    stage: String,
    startTime: CFTimeInterval?,
    totals: GaussianProfileTotals,
    extra: String = ""
) {
    guard let startTime else { return }

    let elapsedMs = (CACurrentMediaTime() - startTime) * 1000.0
    let bytesPerSplat = totals.splatCount > 0
        ? Double(totals.totalResidentBytes) / Double(totals.splatCount)
        : 0.0
    let suffix = extra.isEmpty ? "" : " \(extra)"

    Logger.log(
        message: String(
            format: "[Gaussian][%@] cpuEncodeMs=%.3f entities=%d splats=%d draws=%d dispatches=%d radixPasses=%d shDegree=%u shRestCoeffsPerSplat=%u memory=%@ bytesPerSplat=%.1f encoded=%@ sorted=%@ visible=%@ sh=%@ uniforms=%@ scratch=%@%@",
            stage,
            elapsedMs,
            totals.entityCount,
            totals.splatCount,
            totals.drawCallCount,
            totals.dispatchCount,
            totals.radixPassCount,
            totals.maxSphericalHarmonicsDegree,
            totals.higherOrderCoefficientsPerSplat,
            gaussianFormatBytes(totals.totalResidentBytes),
            bytesPerSplat,
            gaussianFormatBytes(totals.encodedBytes),
            gaussianFormatBytes(totals.sortedIndexBytes),
            gaussianFormatBytes(totals.visibleIndexBytes + totals.visibleCountBytes),
            gaussianFormatBytes(totals.sphericalHarmonicsBytes),
            gaussianFormatBytes(totals.uniformBytes),
            gaussianFormatBytes(totals.scratchBytes),
            suffix
        ),
        category: LogCategory.gaussian.rawValue
    )
}

func gaussianFormatBytes(_ bytes: Int) -> String {
    let value = Double(bytes)
    if bytes >= 1024 * 1024 {
        return String(format: "%.2fMiB", value / 1_048_576.0)
    }
    if bytes >= 1024 {
        return String(format: "%.2fKiB", value / 1024.0)
    }
    return "\(bytes)B"
}
