//
//  UntoldGSCookerFootprintTests.swift
//  UntoldEngineTests
//
//  Pins the memory shape of the streamed cook: the budget's compaction moves
//  the splats within the store the read pass built, so the cook phase adds
//  only its selection scratch to the footprint, never a second store.
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
@testable import UntoldEngine
import XCTest

final class UntoldGSCookerFootprintTests: XCTestCase {
    /// The process's physical footprint — what `footprint` in Activity Monitor and
    /// `/usr/bin/time -l`'s "peak memory footprint" count.
    private static func physicalFootprint() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        precondition(result == KERN_SUCCESS, "task_info failed: \(result)")
        return Int(info.phys_footprint)
    }

    /// A degree-3 asset of `count` splats with every array allocated once at its final size, so
    /// nothing freed during its construction sits in malloc's cache for the cook to reuse.
    private static func asset(count: Int) -> GaussianSplatAsset {
        var rng = SplitMix64(seed: 0xF00D_F00D)
        var splats: [GaussianSplat] = []
        splats.reserveCapacity(count)
        let perChannel = 16
        var coefficients = [Float](repeating: 0, count: count * perChannel * 3)
        for index in 0 ..< count {
            let scale = 0.01 + rng.unit() * 0.05
            splats.append(GaussianSplat(
                center: [rng.unit() * 10 - 5, rng.unit() * 2, rng.unit() * 10 - 5, 1],
                scale: [scale, scale * 0.8, scale * 1.2, 1],
                color: [rng.unit(), rng.unit(), rng.unit(), 1],
                quat: [1, 0, 0, 0],
                opacity: 0.05 + rng.unit() * 0.9
            ))
            let base = index * perChannel * 3
            for term in 0 ..< perChannel * 3 {
                coefficients[base + term] = rng.unit() - 0.5
            }
        }
        return GaussianSplatAsset(
            splats: splats,
            sphericalHarmonics: GaussianSphericalHarmonics(degree: 3, coefficientsPerChannel: perChannel, coefficients: coefficients)
        )
    }

    func testBudgetCompactionDoesNotDuplicateTheStore() throws {
        // 400 k degree-3 splats: a 40 MB store (56 B of floats plus 45 SH bytes per splat).
        // The budget selection allocates an importance per splat, its sorted copy and the
        // survivor indices — about 20 B per splat — while a copy of the store on the first
        // write of the compaction would add the whole 101 B per splat again.
        let count = 400_000
        let storeBytes = count * (56 + 45)
        let asset = Self.asset(count: count)
        var options = UntoldGSCookOptions()
        options.maxSplatCount = count / 2
        options.log2ChunkSplats = 10

        let samples = FootprintSamples()
        let control = UntoldGSCookControl(progress: { report in
            if report.phase == .read, report.fraction == 1 {
                samples.afterRead = Self.physicalFootprint()
            } else if report.phase == .cook, report.fraction == 0.25 {
                samples.afterBudget = Self.physicalFootprint()
            }
        })
        let progress = UntoldGSCookProgressSink(control: control, tierCount: 1)
        let cooked = try UntoldGSCooker.cookStore(from: asset, options: options, emptySourceDescription: "empty", progress: progress)
        XCTAssertEqual(cooked.store.count, count / 2)
        XCTAssertEqual(cooked.report.prunedByBudget, count / 2)

        let afterRead = try XCTUnwrap(samples.afterRead, "the read phase reported its end")
        let afterBudget = try XCTUnwrap(samples.afterBudget, "the cook phase reported past the budget")
        let grew = afterBudget - afterRead
        XCTAssertLessThan(
            grew, storeBytes / 2,
            "the budget's compaction added \(grew / 1_000_000) MB to the footprint over a \(storeBytes / 1_000_000) MB store: a second copy of the store"
        )
    }
}

private final class FootprintSamples: @unchecked Sendable {
    private let lock = NSLock()
    private var read: Int?
    private var budget: Int?

    var afterRead: Int? {
        get { lock.withLock { read } }
        set { lock.withLock { read = newValue } }
    }

    var afterBudget: Int? {
        get { lock.withLock { budget } }
        set { lock.withLock { budget = newValue } }
    }
}

private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}
