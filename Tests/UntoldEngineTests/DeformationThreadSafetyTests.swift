//
//  DeformationThreadSafetyTests.swift
//  UntoldEngineTests
//
//  The deformation state other threads touch: the override a simulation
//  writes while the pass reads it, and the ML deformer's load state the
//  background load writes while the pass reads it.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

/// Takes a value the engine guards with its own lock across threads.
private struct Shared<Value>: @unchecked Sendable {
    let value: Value
}

/// The tokens handed out across threads.
private final class Tokens: @unchecked Sendable {
    private let lock = NSLock()
    private var tokens: [Int] = []

    func add(_ token: Int) {
        lock.withLock { tokens.append(token) }
    }

    var all: [Int] {
        lock.withLock { tokens }
    }
}

final class DeformationThreadSafetyTests: XCTestCase {
    // MARK: - Override

    func testAnOverrideWrittenFromManyThreadsIsAlwaysReadWhole() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }
        let capacity = 64
        let override = try XCTUnwrap(MeshDeformationOverride(device: device, capacity: capacity, label: "test"))
        XCTAssertEqual(override.current().count, 0)
        let shared = Shared(value: override)

        // Every write fills its slot with one value, and as many entries
        // as that value: a slot read whole holds `count` copies of `count`.
        DispatchQueue.concurrentPerform(iterations: 400) { iteration in
            if iteration.isMultiple(of: 2) {
                let count = 1 + iteration % capacity
                shared.value.write(
                    indices: [UInt32](repeating: UInt32(count), count: count),
                    positions: [simd_float3](repeating: simd_float3(repeating: Float(count)), count: count),
                    normals: [simd_float3](repeating: simd_float3(0, 1, 0), count: count)
                )
            } else {
                let (slot, count) = shared.value.current()
                XCTAssertTrue((0 ..< MeshDeformationOverride.ringCount).contains(slot))
                XCTAssertTrue((0 ... capacity).contains(count))
            }
        }

        let (slot, count) = override.current()
        XCTAssertGreaterThan(count, 0)
        let indices = override.indices[slot].contents().bindMemory(to: UInt32.self, capacity: capacity)
        for index in 0 ..< count {
            XCTAssertEqual(indices[index], UInt32(count))
        }
    }

    func testAWriteBeyondTheCapacityIsCut() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("Metal device unavailable")
        }
        let override = try XCTUnwrap(MeshDeformationOverride(device: device, capacity: 4, label: "test"))
        override.write(
            indices: [UInt32](0 ..< 9), positions: [simd_float3](repeating: .zero, count: 9),
            normals: [simd_float3](repeating: .zero, count: 9)
        )

        XCTAssertEqual(override.current().count, 4)
        XCTAssertEqual(override.current().slot, 1)
    }

    // MARK: - ML deformer load state

    func testOnlyOneCallerStartsTheLoad() {
        let component = DeformationComponent()
        XCTAssertNil(component.mlDeformerLoadState)

        let started = Tokens()
        let shared = Shared(value: component)
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            if let token = shared.value.beginMLDeformerLoad() {
                started.add(token)
            }
        }
        let tokens = started.all

        XCTAssertEqual(tokens.count, 1)
        guard case .loading = component.mlDeformerLoadState else {
            return XCTFail("the load should be under way")
        }
        // Loading, failed or ready: nobody starts another.
        XCTAssertNil(component.beginMLDeformerLoad())
        XCTAssertTrue(component.finishMLDeformerLoad(tokens[0], as: .failed))
        XCTAssertNil(component.beginMLDeformerLoad())
    }

    func testALoadThatFinishesAfterAResetIsDropped() {
        let component = DeformationComponent()
        let stale = component.beginMLDeformerLoad()
        XCTAssertNotNil(stale)

        // Another payload is set while the first still loads.
        component.resetMLDeformerLoad()
        XCTAssertNil(component.mlDeformerLoadState)
        let fresh = component.beginMLDeformerLoad()
        XCTAssertNotNil(fresh)
        XCTAssertNotEqual(stale, fresh)

        XCTAssertFalse(component.finishMLDeformerLoad(stale ?? -1, as: .failed))
        guard case .loading = component.mlDeformerLoadState else {
            return XCTFail("the stale load must not end the fresh one")
        }
        XCTAssertTrue(component.finishMLDeformerLoad(fresh ?? -1, as: .failed))
        guard case .failed = component.mlDeformerLoadState else {
            return XCTFail("the fresh load ends the state")
        }
    }

    func testTheStateIsReadWhileItIsWritten() {
        let component = DeformationComponent()
        let shared = Shared(value: component)
        DispatchQueue.concurrentPerform(iterations: 2000) { iteration in
            switch iteration % 4 {
            case 0:
                shared.value.resetMLDeformerLoad()
            case 1:
                if let token = shared.value.beginMLDeformerLoad() {
                    shared.value.finishMLDeformerLoad(token, as: .failed)
                }
            default:
                _ = shared.value.mlDeformerLoadState
            }
        }
        component.cleanUp()
        XCTAssertNil(component.mlDeformerLoadState)
    }
}
