//
//  GaussianSharedWorkingSet.swift
//  UntoldEngine
//
//  The per-frame working set every Gaussian splat entity compacts into: one record and one
//  depth key per splat that survived its entity's cull, sorted once and drawn once, so splats
//  of overlapping entities blend in true depth order instead of entity order. Sized to a budget
//  (`GaussianRuntimeLimits.workingSetSplats`, clamped by the memory budget and by the resident
//  total, never below the whole-buffer entities' resident total) rather than to what is loaded;
//  the frame's chunked entities are fitted to what the whole-buffer entities leave of it through
//  per-chunk quotas whose state (`GaussianBudgetState`) lives here too.
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

    /// The fraction of `MemoryBudgetManager`'s geometry budget the default working set may take.
    static let memoryBudgetFraction = 0.25

    private let lock = NSLock()
    /// Records each frame's set can hold: `fitCapacity` sizes it to min(budget, resident total),
    /// growing as entities load and shrinking only when the budget itself drops, so a streaming
    /// scene does not reallocate on every unload; an in-flight frame keeps its old buffers alive
    /// through its command buffer. The bytes are one `MemoryBudgetManager` ledger entry
    /// (`setGaussianWorkingSetBytes`), not a share of each entity's estimate.
    private var _capacity = 0
    private var keys: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var records: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var visibleSets: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var entityConstants: [MTLBuffer?] = Array(repeating: nil, count: totalPerMeshUniformBuffers())
    /// The frame's budget state (`GaussianBudgetState`): one persistent buffer the budget kernels
    /// carry from frame to frame (the previous scale for the hysteresis), and a copy per in-flight
    /// slot the frame publishes for the CPU readback.
    private var _budgetState: MTLBuffer?
    private var budgetReadbacks: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    private var _lastBudgetState = GaussianBudgetState()
    /// The entity enumeration the preprocess stamped into each slot's records, so the draw builds
    /// its constants table from the same order even when the scene changed in between or the
    /// preprocess was skipped this frame (asset loading gate) and the slot is stale.
    private var entityOrder: [[EntityID]] = Array(repeating: [], count: maxInFlightCommandBuffers)
    private var _lastVisibleCount = 0
    private var _lastOverflowCount = 0
    /// Set by a frame that found no splat entity, consumed by the next frame that has some: the
    /// scale the previous scene settled at must not fade the new one in.
    private var _hysteresisResetPending = false

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

    /// The budget state of the last completed frame (`recordCompletedFrame`): what the chunked
    /// entities asked for, what they were granted, the scale and its target.
    var lastBudgetState: GaussianBudgetState {
        lock.lock()
        defer { lock.unlock() }
        return _lastBudgetState
    }

    /// The working-set budget in splats for this platform: the override when set, otherwise the
    /// default clamped so the set (`bytesPerSplatPerSlot` per frame in flight) takes at most
    /// `memoryBudgetFraction` of the geometry budget.
    static func budgetSplats(geometryBudgetBytes: Int = MemoryBudgetManager.shared.geometryBudget) -> Int {
        if let override = GaussianRuntimeLimits.workingSetSplatsOverride {
            return max(1, override)
        }
        let bytesPerSplat = bytesPerSplatPerSlot * maxInFlightCommandBuffers
        let fromMemory = Int(Double(geometryBudgetBytes) * memoryBudgetFraction) / bytesPerSplat
        return max(1, min(GaussianRuntimeLimits.workingSetSplats, fromMemory))
    }

    /// Sizes the set for a frame: at least min(`budget`, `residentSplats`) records — no frame can
    /// compact more than is loaded — and never below `wholeBufferSplats`, the resident total of
    /// the whole-buffer (`.ply`) entities, which are not budgeted and must always fit; growing
    /// when that rises and shrinking only when the set is above the budget (an override or the
    /// debug switch changed). Returns the capacity the frame runs with, or nil when a buffer
    /// could not be allocated.
    func fitCapacity(residentSplats: Int, budget: Int, wholeBufferSplats: Int = 0, device: MTLDevice) -> Int? {
        let cap = max(1, budget, min(wholeBufferSplats, residentSplats))
        let wanted = max(1, min(residentSplats, cap))
        let current = capacity
        let target = current > cap ? wanted : max(current, wanted)
        guard ensureCapacity(target, device: device, exact: true) else { return nil }
        // The ledger entry is written when the buffers change; a `MemoryBudgetManager.clear()`
        // (scene unload) zeroes it while the set, which is not scene-owned, lives on.
        let bytes = residentBytes
        if MemoryBudgetManager.shared.gaussianWorkingSetBytesTracked != bytes {
            MemoryBudgetManager.shared.setGaussianWorkingSetBytes(bytes)
        }
        return capacity
    }

    /// A frame without any splat entity: the next frame with some takes its budget scale
    /// directly instead of climbing from the one the previous scene settled at.
    func noteFrameWithoutEntities() {
        lock.lock()
        _hysteresisResetPending = true
        lock.unlock()
    }

    /// Whether the frame being encoded should take its target scale as a first frame would;
    /// clears the flag.
    func takeHysteresisReset() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let pending = _hysteresisResetPending
        _hysteresisResetPending = false
        return pending
    }

    /// Grows the per-slot buffers to hold `splatCount` records (`exact` also shrinks them to it).
    /// Allocation is all-or-nothing: the stored buffers change only once every new one exists.
    /// Returns false when one could not be allocated (the previous buffers stay usable). The
    /// budget state buffers are allocated here too. A change of capacity forgets every slot's
    /// entity order: the other slots' records and visible sets were written for the old
    /// buffers, and a frame that reuses one without re-running the preprocess (asset-loading
    /// gate) must not draw its old count over the new, possibly smaller, buffers.
    @discardableResult
    func ensureCapacity(_ splatCount: Int, device: MTLDevice, exact: Bool = false) -> Bool {
        let wanted = max(splatCount, 1)
        lock.lock()
        defer { lock.unlock() }
        let complete = visibleSets.allSatisfy { $0 != nil } && entityConstants.allSatisfy { $0 != nil } && keys.allSatisfy { $0 != nil }
            && _budgetState != nil && budgetReadbacks.allSatisfy { $0 != nil }
        if complete, exact ? wanted == _capacity : wanted <= _capacity {
            return true
        }
        let newCapacity = exact ? wanted : max(wanted, _capacity)
        var newKeys = keys
        var newRecords = records
        var newVisibleSets = visibleSets
        var newEntityConstants = entityConstants
        var newBudgetState = _budgetState
        var newBudgetReadbacks = budgetReadbacks
        for slot in 0 ..< maxInFlightCommandBuffers {
            if newCapacity != _capacity || newKeys[slot] == nil || newRecords[slot] == nil {
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
            if newBudgetReadbacks[slot] == nil {
                guard let readback = device.makeBuffer(length: MemoryLayout<GaussianBudgetState>.stride, options: .storageModeShared) else { return false }
                readback.label = "Gaussian Budget State Readback \(slot)"
                readback.contents().storeBytes(of: GaussianBudgetState(), as: GaussianBudgetState.self)
                newBudgetReadbacks[slot] = readback
            }
        }
        if newBudgetState == nil {
            guard let state = device.makeBuffer(length: MemoryLayout<GaussianBudgetState>.stride, options: .storageModeShared) else { return false }
            state.label = "Gaussian Budget State"
            state.contents().storeBytes(of: GaussianBudgetState(), as: GaussianBudgetState.self)
            newBudgetState = state
        }
        for index in newEntityConstants.indices where newEntityConstants[index] == nil {
            guard let buffer = device.makeBuffer(
                length: MemoryLayout<GaussianEntityDrawConstants>.stride * Int(gaussianMaxEntitiesPerFrame),
                options: .storageModeShared
            ) else { return false }
            buffer.label = "Gaussian Entity Draw Constants \(index)"
            newEntityConstants[index] = buffer
        }
        if newCapacity != _capacity {
            entityOrder = Array(repeating: [], count: maxInFlightCommandBuffers)
        }
        keys = newKeys
        records = newRecords
        visibleSets = newVisibleSets
        entityConstants = newEntityConstants
        _budgetState = newBudgetState
        budgetReadbacks = newBudgetReadbacks
        _capacity = newCapacity
        MemoryBudgetManager.shared.setGaussianWorkingSetBytes(residentBytesLocked)
        return true
    }

    /// The persistent budget state the frame's budget kernels read and write.
    var budgetState: MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return _budgetState
    }

    /// The copy of the budget state the frame publishes for `slot`'s readback.
    func budgetReadback(slot: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return budgetReadbacks[min(slot, budgetReadbacks.count - 1)]
    }

    /// Forgets the previous frames' scale, so the next frame takes its target directly. For
    /// tests that want to start from a known state with no frame in flight; a running scene
    /// resets through `noteFrameWithoutEntities` on the GPU's own timeline instead.
    func resetBudgetHysteresis() {
        lock.lock()
        defer { lock.unlock() }
        _budgetState?.contents().storeBytes(of: GaussianBudgetState(), as: GaussianBudgetState.self)
        _hysteresisResetPending = false
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

    func recordCompletedFrame(visibleCount: Int, overflowCount: Int, budgetState: GaussianBudgetState? = nil) {
        lock.lock()
        _lastVisibleCount = visibleCount
        _lastOverflowCount = overflowCount
        if let budgetState {
            _lastBudgetState = budgetState
        }
        lock.unlock()
    }

    /// Resident bytes of the per-frame buffers, for the profile line and the memory ledger.
    var residentBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return residentBytesLocked
    }

    private var residentBytesLocked: Int {
        (keys + records + visibleSets + entityConstants + budgetReadbacks + [_budgetState]).reduce(0) { $0 + ($1?.length ?? 0) }
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
