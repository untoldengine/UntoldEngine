//
//  GaussianSharedWorkingSet.swift
//  UntoldEngine
//
//  The per-frame working set every Gaussian splat entity compacts into: one record and one
//  depth key per splat that survived its entity's cull, sorted once and drawn once, so splats
//  of overlapping entities blend in true depth order instead of entity order.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal

final class GaussianSharedWorkingSet: @unchecked Sendable {
    static let shared = GaussianSharedWorkingSet()

    /// Bytes one record and its key take per frame in flight: 64-byte `GaussianWorkingSetSplat`
    /// plus an 8-byte key — what the removed per-entity sort-key and precomputed buffers cost.
    static let bytesPerSplatPerSlot = MemoryLayout<GaussianWorkingSetSplat>.stride + MemoryLayout<UInt64>.stride

    private let lock = NSLock()
    /// Records each frame's set can hold. Grows to the resident splat total and never shrinks;
    /// an in-flight frame keeps its old buffers alive through its command buffer. The resident
    /// total is bounded by the per-entity load cap and the memory budget, and every entity's
    /// `estimatedGPUBytes` includes its share (`bytesPerSplatPerSlot` per frame in flight), so
    /// the budget sees this set the way it saw the per-entity buffers. A budget-sized working set
    /// (proposal §4.4) is the follow-up.
    private var _capacity = 0
    private var keys: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var records: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var visibleSets: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var entityConstants: [MTLBuffer?] = Array(repeating: nil, count: totalPerMeshUniformBuffers())
    /// The entity enumeration the preprocess stamped into each slot's records, so the draw builds
    /// its constants table from the same order even when the scene changed in between or the
    /// preprocess was skipped this frame (asset loading gate) and the slot is stale.
    private var entityOrder: [[EntityID]] = Array(repeating: [], count: maxInFlightCommandBuffers)
    private var _lastVisibleCount = 0
    private var _lastOverflowCount = 0

    var capacity: Int {
        lock.lock()
        defer { lock.unlock() }
        return _capacity
    }

    /// Read back from the last completed frame: splats the shared set held, and splats the
    /// entities appended past its capacity (dropped). Profiling and tests only.
    var lastVisibleCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _lastVisibleCount
    }

    var lastOverflowCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _lastOverflowCount
    }

    /// Grows the per-slot buffers to hold `splatCount` records. Allocation is all-or-nothing: the
    /// stored buffers change only once every new one exists. Returns false when one could not be
    /// allocated (the previous buffers stay usable).
    @discardableResult
    func ensureCapacity(_ splatCount: Int, device: MTLDevice) -> Bool {
        let wanted = max(splatCount, 1)
        lock.lock()
        defer { lock.unlock() }
        let complete = visibleSets.allSatisfy { $0 != nil } && entityConstants.allSatisfy { $0 != nil } && keys.allSatisfy { $0 != nil }
        if wanted <= _capacity, complete {
            return true
        }
        let newCapacity = max(wanted, _capacity)
        var newKeys = keys
        var newRecords = records
        var newVisibleSets = visibleSets
        var newEntityConstants = entityConstants
        for slot in 0 ..< maxInFlightCommandBuffers {
            if newCapacity > _capacity || newKeys[slot] == nil || newRecords[slot] == nil {
                guard let keyBuffer = device.makeBuffer(length: MemoryLayout<UInt64>.stride * newCapacity, options: .storageModeShared),
                      let recordBuffer = device.makeBuffer(length: MemoryLayout<GaussianWorkingSetSplat>.stride * newCapacity, options: .storageModeShared)
                else { return false }
                keyBuffer.label = "Gaussian Shared Sort Keys \(slot)"
                recordBuffer.label = "Gaussian Shared Working Set \(slot)"
                newKeys[slot] = keyBuffer
                newRecords[slot] = recordBuffer
            }
            if newVisibleSets[slot] == nil {
                guard let set = device.makeBuffer(length: MemoryLayout<GaussianVisibleSet>.stride, options: .storageModeShared) else { return false }
                set.label = "Gaussian Shared Visible Set \(slot)"
                set.contents().storeBytes(of: makeGaussianVisibleSet(visibleCount: 0), as: GaussianVisibleSet.self)
                newVisibleSets[slot] = set
            }
        }
        for index in newEntityConstants.indices where newEntityConstants[index] == nil {
            guard let buffer = device.makeBuffer(
                length: MemoryLayout<GaussianEntityDrawConstants>.stride * Int(gaussianMaxEntitiesPerFrame),
                options: .storageModeShared
            ) else { return false }
            buffer.label = "Gaussian Entity Draw Constants \(index)"
            newEntityConstants[index] = buffer
        }
        keys = newKeys
        records = newRecords
        visibleSets = newVisibleSets
        entityConstants = newEntityConstants
        _capacity = newCapacity
        return true
    }

    func keys(slot: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return keys[min(slot, keys.count - 1)]
    }

    func records(slot: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return records[min(slot, records.count - 1)]
    }

    func visibleSet(slot: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return visibleSets[min(slot, visibleSets.count - 1)]
    }

    /// Per-entity draw constants for one uniform ring index (`currentUniformBufferIndex()`:
    /// frame slot and eye), so both eyes of a frame keep their own matrices.
    func entityConstants(uniformIndex: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return entityConstants[min(uniformIndex, entityConstants.count - 1)]
    }

    /// The preprocess records which entity each index in `slot`'s records refers to.
    func setEntityOrder(_ entities: [EntityID], slot: Int) {
        lock.lock()
        entityOrder[min(slot, entityOrder.count - 1)] = entities
        lock.unlock()
    }

    /// The enumeration `slot`'s records were stamped with; the draw builds its table from this.
    func entityOrder(slot: Int) -> [EntityID] {
        lock.lock()
        defer { lock.unlock() }
        return entityOrder[min(slot, entityOrder.count - 1)]
    }

    func recordCompletedFrame(visibleCount: Int, overflowCount: Int) {
        lock.lock()
        _lastVisibleCount = visibleCount
        _lastOverflowCount = overflowCount
        lock.unlock()
    }

    /// Resident bytes of the per-frame buffers, for the profile line.
    var residentBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return (keys + records + visibleSets + entityConstants).reduce(0) { $0 + ($1?.length ?? 0) }
    }

    /// Tests: fills one slot's key buffer and visible set as if `keys.count` splats had been
    /// compacted, so `executeRadixSort` can be driven without a cull or preprocess.
    func seedForTesting(keys seeded: [UInt64], slot: Int, device: MTLDevice) -> Bool {
        guard ensureCapacity(seeded.count, device: device), let keyBuffer = keys(slot: slot), let set = visibleSet(slot: slot) else { return false }
        seeded.withUnsafeBytes { bytes in
            keyBuffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        }
        set.contents().storeBytes(of: makeGaussianVisibleSet(visibleCount: UInt32(seeded.count)), as: GaussianVisibleSet.self)
        return true
    }
}

extension GaussianWorkingSetSplat {
    /// Index into the frame's `GaussianEntityDrawConstants` table, stored as float bits.
    var entityIndex: UInt32 {
        positionAndEntity.w.bitPattern
    }

    var position: SIMD3<Float> {
        SIMD3(positionAndEntity.x, positionAndEntity.y, positionAndEntity.z)
    }

    var axis1: SIMD2<Float> {
        SIMD2(axes.x, axes.y)
    }

    var axis2: SIMD2<Float> {
        SIMD2(axes.z, axes.w)
    }
}
