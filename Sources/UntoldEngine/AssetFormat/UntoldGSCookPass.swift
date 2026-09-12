//
//  UntoldGSCookPass.swift
//  UntoldEngine
//
//  The streamed cook: every window of the source is parsed, pruned,
//  transformed and reduced to the target spherical-harmonics degree inside
//  the reader's parallel work items, and committed in source order into one
//  `UntoldGSSplatStore`. Nothing of the source survives the pass but the
//  store, the counts and the bounds — no file copy, no importer arrays, no
//  writer copy.
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

/// What the streamed cook produced: the store and the facts the bake needs around it.
struct UntoldGSCookedStore {
    var store: UntoldGSSplatStore
    var report: UntoldGSCookReport
    /// Store indices (source order, after the budget) of splats whose transformed data or
    /// harmonics are not finite. The writer refuses them exactly as it refused a non-finite
    /// `UntoldGSSplat`; they are kept here so the refusal names the same splat it always did.
    var nonFiniteIndices: [Int]
    /// Bounds of the cooked centres.
    var centerBounds: (min: SIMD3<Float>, max: SIMD3<Float>)
    /// The asset-level box: centres grown by their major axis.
    var boundingBox: (min: SIMD3<Float>, max: SIMD3<Float>)
}

extension UntoldGSCooker {
    /// One window after the cook: its store, its counts and the local indices of its
    /// non-finite splats.
    struct CookedWindow {
        var store: UntoldGSSplatStore
        var counts = PruneCounts()
        var culledCount = 0
        var nonFiniteLocal: [Int] = []
    }

    /// Cooks a `.ply` into a store: pass A of the bake. `emptySourceDescription` is the
    /// `.sizeMismatch` reason when the file loads no splat at all.
    static func cookStore(
        from source: PLYGaussianSource,
        options: UntoldGSCookOptions,
        emptySourceDescription: String,
        progress: UntoldGSCookProgressSink
    ) throws -> UntoldGSCookedStore {
        let sourceDegree = source.shSchema?.degree ?? 0
        let kernel = try Kernel(options: options, sourceDegree: sourceDegree)
        let sourcePerChannel = source.shSchema?.coefficientsPerChannel ?? 0
        var store = UntoldGSSplatStore(shDegree: kernel.targetDegree)
        store.reserveCapacity(source.vertexCount)
        var counts = PruneCounts()
        var culled = 0
        var nonFinite: [Int] = []

        try progress.report(.read, fraction: 0)
        try source.forEachWindow(
            map: { window in cookWindow(window, kernel: kernel, sourcePerChannel: sourcePerChannel) },
            afterBatch: { fraction in try progress.report(.read, fraction: fraction) }
        ) { cooked in
            commit(cooked, into: &store, counts: &counts, culled: &culled, nonFinite: &nonFinite)
        }
        if culled > 0 {
            logNegligibleOpacityCull(culled: culled, of: source.vertexCount, sourceTag: "PLY")
        }
        guard source.vertexCount - culled > 0 else {
            throw UntoldGSError.sizeMismatch(emptySourceDescription)
        }
        return try finishCook(
            store: &store, inputCount: source.vertexCount - culled, counts: counts, nonFinite: nonFinite,
            kernel: kernel, options: options, progress: progress
        )
    }

    /// Cooks an asset already in memory (`.spz`, tests) into a store, the same way.
    static func cookStore(
        from asset: GaussianSplatAsset,
        options: UntoldGSCookOptions,
        emptySourceDescription: String,
        progress: UntoldGSCookProgressSink
    ) throws -> UntoldGSCookedStore {
        guard !asset.splats.isEmpty else {
            throw UntoldGSError.sizeMismatch(emptySourceDescription)
        }
        let kernel = try Kernel(options: options, sourceDegree: asset.sphericalHarmonics?.degree ?? 0)
        let sourcePerChannel = asset.sphericalHarmonics?.coefficientsPerChannel ?? 0
        var store = UntoldGSSplatStore(shDegree: kernel.targetDegree)
        var counts = PruneCounts()
        var culled = 0
        var nonFinite: [Int] = []
        try progress.report(.read, fraction: 0)
        let window = PLYGaussianWindow(splats: asset.splats, shCoefficients: asset.sphericalHarmonics?.coefficients ?? [], culledCount: 0)
        let cooked = cookWindow(window, kernel: kernel, sourcePerChannel: sourcePerChannel)
        commit(cooked, into: &store, counts: &counts, culled: &culled, nonFinite: &nonFinite)
        try progress.report(.read, fraction: 1)
        return try finishCook(
            store: &store, inputCount: asset.splats.count, counts: counts, nonFinite: nonFinite,
            kernel: kernel, options: options, progress: progress
        )
    }

    /// The per-window cook, run inside the reader's parallel work item: prune, transform, crop,
    /// reduce the harmonics to the target degree and quantise them. Pure.
    static func cookWindow(_ window: PLYGaussianWindow, kernel: Kernel, sourcePerChannel: Int) -> CookedWindow {
        var cooked = CookedWindow(store: UntoldGSSplatStore(shDegree: kernel.targetDegree))
        cooked.culledCount = window.culledCount
        cooked.store.reserveCapacity(window.splats.count)
        let targetPerChannel = Int(kernel.targetDegree + 1) * Int(kernel.targetDegree + 1)
        let higherOrder = kernel.targetDegree > 0 ? targetPerChannel - 1 : 0
        let sourcePerSplat = sourcePerChannel * 3
        var shBytes = [UInt8](repeating: 0, count: higherOrder * 3)

        window.shCoefficients.withUnsafeBufferPointer { coefficients in
            for (index, splat) in window.splats.enumerated() {
                guard let transformed = kernel.process(splat, counts: &cooked.counts) else { continue }
                let writerSplat = UntoldGSSplat(transformed)
                var finite = writerSplat.isFinite
                if higherOrder > 0 {
                    let base = index * sourcePerSplat
                    var slot = 0
                    for channel in 0 ..< 3 {
                        let start = base + channel * sourcePerChannel + 1
                        for offset in start ..< start + higherOrder {
                            let coefficient = coefficients[offset]
                            finite = finite && coefficient.isFinite
                            shBytes[slot] = quantizeGaussianSHCoefficient(coefficient)
                            slot += 1
                        }
                    }
                }
                if !finite {
                    cooked.nonFiniteLocal.append(cooked.store.count)
                }
                cooked.store.append(writerSplat, shBytes: shBytes)
            }
        }
        return cooked
    }

    /// Appends a cooked window to the store, in source order.
    private static func commit(_ cooked: CookedWindow, into store: inout UntoldGSSplatStore, counts: inout PruneCounts, culled: inout Int, nonFinite: inout [Int]) {
        let base = store.count
        for local in cooked.nonFiniteLocal {
            nonFinite.append(base + local)
        }
        store.append(contentsOf: cooked.store)
        counts.opacity += cooked.counts.opacity
        counts.degenerate += cooked.counts.degenerate
        counts.crop += cooked.counts.crop
        culled += cooked.culledCount
    }

    /// The budget, the report and the whole-store facts: the first half of the `cook` phase; the
    /// tiering reports the second half over the progressive ranking, or at once. The store is taken `inout` so the
    /// budget's compaction moves the splats within the caller's own arrays: a copy of the
    /// parameter would leave the caller's reference alive and the first write would duplicate
    /// the whole store — a gigabyte for a 10 M-splat degree-3 capture.
    private static func finishCook(
        store: inout UntoldGSSplatStore,
        inputCount: Int,
        counts: PruneCounts,
        nonFinite: [Int],
        kernel: Kernel,
        options: UntoldGSCookOptions,
        progress: UntoldGSCookProgressSink
    ) throws -> UntoldGSCookedStore {
        var nonFinite = nonFinite
        try progress.report(.cook, fraction: 0)

        var prunedByBudget = 0
        if let budget = options.maxSplatCount, budget > 0, store.count > budget {
            var importance = [Float](repeating: 0, count: store.count)
            for index in 0 ..< store.count {
                importance[index] = store.budgetImportance(index)
            }
            let survivors = selectMostImportant(importance: importance, count: budget)
            prunedByBudget = store.count - survivors.count
            if !nonFinite.isEmpty {
                // `survivors` is ascending: a surviving splat's new index is its rank in it.
                nonFinite = nonFinite.compactMap { old in
                    var low = 0
                    var high = survivors.count
                    while low < high {
                        let mid = (low + high) / 2
                        if survivors[mid] < old { low = mid + 1 } else { high = mid }
                    }
                    return low < survivors.count && survivors[low] == old ? low : nil
                }
            }
            store.compact(keeping: survivors)
        }
        try progress.report(.cook, fraction: 0.25)

        let report = UntoldGSCookReport(
            inputSplatCount: inputCount,
            keptSplatCount: store.count,
            prunedByOpacity: counts.opacity,
            prunedByDegenerateGeometry: counts.degenerate,
            prunedByCrop: counts.crop,
            shDegree: kernel.targetDegree,
            prunedByBudget: prunedByBudget
        )
        guard store.count > 0 else {
            throw UntoldGSCookError.noSplatsLeftAfterPruning(report)
        }
        let cooked = UntoldGSCookedStore(
            store: store,
            report: report,
            nonFiniteIndices: nonFinite,
            centerBounds: store.centerBounds(),
            boundingBox: store.expandedBoundingBox()
        )
        try progress.report(.cook, fraction: 0.5)
        return cooked
    }
}
