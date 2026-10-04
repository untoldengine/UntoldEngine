//
//  LockCensusTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os
import simd
@testable import UntoldEngine
import XCTest

/// Counts every `NSLock` / `NSRecursiveLock` acquisition made while a frame runs and
/// attributes it to the engine function that took the lock.
///
/// Opt-in: runs only with `UNTOLD_LOCK_CENSUS=1`. Pipe the output through
/// `xcrun swift-demangle` to read the function names.
///
///     UNTOLD_LOCK_CENSUS=1 UNTOLD_LOCK_CENSUS_ENTITIES=1000 \
///         swift test --filter LockCensusTests 2>&1 | xcrun swift-demangle
enum LockCensus {
    private struct Storage {
        var counts: [[UInt]: Int] = [:]
        var total = 0
        var offMain = 0
    }

    private static let storage = OSAllocatedUnfairLock(initialState: Storage())
    nonisolated(unsafe) static var enabled = false
    private nonisolated(unsafe) static var installed = false
    private static let depth = 10

    private typealias LockIMP = @convention(c) (AnyObject, Selector) -> Void

    /// Replaces `-[NSLock lock]` and `-[NSRecursiveLock lock]` for the rest of the process. There is
    /// no uninstall on purpose: with `enabled` false the hook costs one flag check per lock, and the
    /// test that installs it is opt-in.
    static func install() {
        guard !installed else { return }
        installed = true
        for cls in [NSLock.self, NSRecursiveLock.self] as [AnyClass] {
            let selector = #selector(NSLocking.lock)
            guard let method = class_getInstanceMethod(cls, selector) else { continue }
            let original = unsafeBitCast(method_getImplementation(method), to: LockIMP.self)
            let block: @convention(block) (AnyObject) -> Void = { object in
                if enabled {
                    record()
                }
                original(object, selector)
            }
            method_setImplementation(method, imp_implementationWithBlock(block))
        }
    }

    private static func record() {
        var frames = [UnsafeMutableRawPointer?](repeating: nil, count: depth)
        let n = Int(backtrace(&frames, Int32(depth)))
        let key = frames.prefix(n).map { UInt(bitPattern: $0) }
        let isMain = Thread.isMainThread
        storage.withLock {
            $0.counts[key, default: 0] += 1
            $0.total += 1
            if !isMain {
                $0.offMain += 1
            }
        }
    }

    static func reset() {
        storage.withLock { $0 = Storage() }
    }

    private static func symbol(_ address: UInt) -> String? {
        var info = Dl_info()
        guard dladdr(UnsafeRawPointer(bitPattern: address), &info) != 0, let name = info.dli_sname else { return nil }
        return String(cString: name)
    }

    /// Returns `(total, offMain, rows)` where each row is `(owner, caller, count)`.
    static func report() -> (total: Int, offMain: Int, rows: [(owner: String, caller: String, count: Int)]) {
        let snapshot = storage.withLock { $0 }
        var merged: [String: Int] = [:]
        for (frames, count) in snapshot.counts {
            // Skip the hook itself, its block thunk (`...TR`) and the Foundation `withLock`
            // helpers: the first two engine symbols are the function taking the lock and
            // the one that called it. The thunk suffix is a detail of Swift's name mangling,
            // so the test checks this attribution on a known lock before it reports.
            let names = frames.compactMap(symbol).filter {
                !$0.contains("LockCensus") && !$0.contains("NSLocking") && !$0.hasPrefix("__") && !$0.hasSuffix("TR")
            }
            let owner = names.first ?? "?"
            let caller = names.dropFirst().first ?? "?"
            merged[owner + "\t" + caller, default: 0] += count
        }
        let rows = merged.map { key, count -> (owner: String, caller: String, count: Int) in
            let parts = key.split(separator: "\t", maxSplits: 1).map(String.init)
            return (parts[0], parts.count > 1 ? parts[1] : "?", count)
        }.sorted { $0.count > $1.count }
        return (snapshot.total, snapshot.offMain, rows)
    }

    static func printReport(_ title: String, per divisor: Int, unit: String, top: Int = 30) {
        let (total, offMain, rows) = report()
        print("\n=== LOCK CENSUS: \(title)")
        print(String(format: "total %.1f lock acquisitions per %@ (%d total, %d off the main thread)", Double(total) / Double(divisor), unit, total, offMain))
        var byOwner: [String: Int] = [:]
        for row in rows {
            byOwner[row.owner, default: 0] += row.count
        }
        print("--- by function taking the lock")
        for (owner, count) in byOwner.sorted(by: { $0.value > $1.value }).prefix(top) {
            print(String(format: "%10.1f  %5.1f%%  %@", Double(count) / Double(divisor), 100 * Double(count) / Double(max(total, 1)), owner))
        }
        print("--- by function taking the lock <- its caller")
        for row in rows.prefix(top) {
            print(String(format: "%10.1f  %@  <-  %@", Double(row.count) / Double(divisor), row.owner, row.caller))
        }
    }
}

/// A lock taken a known number of times from `censusProbeOwner`, itself called from
/// `censusProbeCaller`: the census checks its owner and caller attribution against them before it
/// reports. Neither name may contain "LockCensus", which the report filters out as the hook's own.
private let censusProbeLock = NSLock()

@inline(never)
private func censusProbeOwner(times: Int) -> Int {
    var taken = 0
    for _ in 0 ..< times {
        censusProbeLock.lock()
        taken += 1
        censusProbeLock.unlock()
    }
    return taken
}

@inline(never)
private func censusProbeCaller(times: Int) -> Int {
    // The addition keeps the call out of tail position, so this frame stays on the stack in an
    // optimised build.
    censusProbeOwner(times: times) &+ 1
}

final class LockCensusTests: BaseRenderSetup {
    /// Same rule as the other benchmarks' helper: a missing, malformed, zero or negative value
    /// falls back to the default.
    private func intEnv(_ name: String, default defaultValue: Int) -> Int {
        guard let raw = ProcessInfo.processInfo.environment[name], let value = Int(raw), value > 0 else {
            return defaultValue
        }
        return value
    }

    func test_lockCensus_perFrame() throws {
        guard ProcessInfo.processInfo.environment["UNTOLD_LOCK_CENSUS"] == "1" else {
            throw XCTSkip("Set UNTOLD_LOCK_CENSUS=1 to run the lock census")
        }
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }

        let entityCount = intEnv("UNTOLD_LOCK_CENSUS_ENTITIES", default: 1000)
        let frames = intEnv("UNTOLD_LOCK_CENSUS_FRAMES", default: 30)

        // A grid of cubes in front of the camera.
        let cube = BasicPrimitives.createCube(extent: 0.2)
        let side = Int(Double(entityCount).squareRoot().rounded(.up))
        var entities: [EntityID] = []
        for i in 0 ..< entityCount {
            let entity = createEntity()
            setEntityMeshDirect(entityId: entity, meshes: cube, assetName: "Cube")
            translateTo(entityId: entity, position: simd_float3(Float(i % side) * 0.4 - Float(side) * 0.2, Float(i / side) * 0.4 - Float(side) * 0.2, -20))
            entities.append(entity)
        }
        setVisibleEntities()

        for _ in 0 ..< 30 {
            renderer.draw(in: renderer.metalView)
        }

        var start = DispatchTime.now().uptimeNanoseconds
        for _ in 0 ..< frames {
            renderer.draw(in: renderer.metalView)
        }
        let plainMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(frames)

        LockCensus.install()

        // 0. Self-check. A lock taken a known number of times from a known function must come back
        // attributed to that function and to its caller. If a toolchain changed how the hook's own
        // frames are named, the report would otherwise blame the wrong functions without a sign.
        let probeCount = 100
        LockCensus.reset()
        LockCensus.enabled = true
        _ = censusProbeCaller(times: probeCount)
        LockCensus.enabled = false
        let probeRows = LockCensus.report().rows.filter { $0.owner.contains("censusProbeOwner") }
        XCTAssertEqual(
            probeRows.reduce(0) { $0 + $1.count }, probeCount,
            "the census did not attribute the probe's lock to the function that took it"
        )
        XCTAssertTrue(
            !probeRows.isEmpty && probeRows.allSatisfy { $0.caller.contains("censusProbeCaller") },
            "the census did not attribute the probe's lock to its caller: \(probeRows.map(\.caller))"
        )

        // 1. The frame itself.
        LockCensus.reset()
        start = DispatchTime.now().uptimeNanoseconds
        LockCensus.enabled = true
        for _ in 0 ..< frames {
            renderer.draw(in: renderer.metalView)
        }
        LockCensus.enabled = false
        let hookedMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(frames)
        LockCensus.printReport("renderer.draw, \(entityCount) cubes + test scene", per: frames, unit: "frame", top: 40)

        print(String(format: "renderer.draw wall time per frame: %.2f ms, %.2f ms with the census hook", plainMs, hookedMs))

        // 2. Game code moving entities through the public API.
        LockCensus.reset()
        LockCensus.enabled = true
        for (i, entity) in entities.enumerated() {
            translateTo(entityId: entity, position: simd_float3(Float(i % side) * 0.4, Float(i / side) * 0.4, -21))
        }
        LockCensus.enabled = false
        LockCensus.printReport("translateTo(entityId:position:)", per: entities.count, unit: "call", top: 12)

        // 3. Game code reading a component through the public API.
        LockCensus.reset()
        LockCensus.enabled = true
        var sum: Float = 0
        for entity in entities {
            if let transform = scene.get(component: LocalTransformComponent.self, for: entity) {
                sum += transform.position.x
            }
        }
        LockCensus.enabled = false
        XCTAssertFalse(sum.isNaN)
        LockCensus.printReport("scene.get(component:for:)", per: entities.count, unit: "call", top: 12)
    }
}
