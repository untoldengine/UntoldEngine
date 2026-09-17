//
//  RoomSurfaceStore.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Broad category of a reconstructed real-world surface, independent of any
/// particular AR framework's own classification enum.
public enum RoomSurfaceKind: Hashable, Sendable {
    case floor
    case ceiling
    case wall
    case table
    case seat
    case door
    case window
    case unknown
}

/// A bounded, reconstructed real-world surface (e.g. from AR plane or mesh
/// detection): a rectangle in world space, in metres.
public struct RoomSurface: Sendable {
    public var center: simd_float3
    public var normal: simd_float3
    public var tangentU: simd_float3
    public var tangentV: simd_float3
    public var extentU: Float
    public var extentV: Float
    public var kind: RoomSurfaceKind

    public init(
        center: simd_float3,
        normal: simd_float3,
        tangentU: simd_float3,
        tangentV: simd_float3,
        extentU: Float,
        extentV: Float,
        kind: RoomSurfaceKind = .unknown
    ) {
        self.center = center
        self.normal = normal
        self.tangentU = tangentU
        self.tangentV = tangentV
        self.extentU = extentU
        self.extentV = extentV
        self.kind = kind
    }
}

/// A surface as currently held by a `RoomSurfaceStore`: the geometry plus
/// enough lifecycle state for a consumer to reason about confidence.
public struct RoomSurfaceRecord: Sendable {
    public let id: UUID
    public var surface: RoomSurface
    /// False once the source tracker has stopped confirming this surface.
    /// The record is retained, not deleted, until `purgeStale` drops it.
    public var isTracked: Bool
    public var lastConfirmed: TimeInterval
}

/// Reconstructs a persistent view of room geometry from a live, flickering
/// anchor stream. AR plane/mesh detection loses and re-finds surfaces
/// constantly — merges, confidence changes, anything not currently in
/// view — and reports each of those as an ordinary removal. A source
/// tracker feeds that stream in through `upsert`/`markUnconfirmed`, keyed by
/// its own anchor IDs; the store keeps surfaces alive across "unconfirmed"
/// gaps instead of deleting them the instant the tracker stops asserting
/// them, and folds a re-detected surface into an existing record when they
/// occupy roughly the same place, so a merge or reacquisition under a new
/// anchor ID doesn't stack a duplicate collider on top of the original.
///
/// Framework-agnostic by design: it knows nothing about ARKit. A platform
/// adapter (e.g. a visionOS `PlaneAnchor`/`MeshAnchor` stream) translates
/// its updates into calls here.
public final class RoomSurfaceStore: @unchecked Sendable {
    private let lock = NSLock()
    private var records: [UUID: RoomSurfaceRecord] = [:]
    /// Maps a source tracker's anchor ID to the store's stable record ID —
    /// distinct from the record ID when a re-detected surface was folded
    /// into an existing record instead of minted as new.
    private var sourceToRecord: [UUID: UUID] = [:]

    /// How long an unconfirmed surface is kept before it's dropped for
    /// good. Long relative to a head turn: real rooms don't rearrange
    /// themselves in seconds, and this only needs to outlast normal
    /// tracking gaps, not detect genuine remodeling quickly.
    public let staleTimeout: TimeInterval
    /// Two surfaces closer than this and with normals aligned past
    /// `mergeNormalAlignment` are treated as the same physical surface.
    public let mergeDistance: Float
    public let mergeNormalAlignment: Float

    public init(
        staleTimeout: TimeInterval = 120,
        mergeDistance: Float = 0.35,
        mergeNormalAlignment: Float = 0.85
    ) {
        self.staleTimeout = staleTimeout
        self.mergeDistance = mergeDistance
        self.mergeNormalAlignment = mergeNormalAlignment
    }

    /// The tracker confirmed `sourceID` at `surface` (an add or an update).
    /// Returns the stable record ID `sourceID` now resolves to.
    @discardableResult
    public func upsert(sourceID: UUID, surface: RoomSurface, at timestamp: TimeInterval) -> UUID {
        lock.withLock {
            if let recordID = sourceToRecord[sourceID] {
                records[recordID]?.surface = surface
                records[recordID]?.isTracked = true
                records[recordID]?.lastConfirmed = timestamp
                return recordID
            }
            if let matchID = bestMatch(for: surface) {
                sourceToRecord[sourceID] = matchID
                records[matchID]?.surface = surface
                records[matchID]?.isTracked = true
                records[matchID]?.lastConfirmed = timestamp
                return matchID
            }
            sourceToRecord[sourceID] = sourceID
            records[sourceID] = RoomSurfaceRecord(
                id: sourceID, surface: surface, isTracked: true, lastConfirmed: timestamp
            )
            return sourceID
        }
    }

    /// The tracker stopped confirming `sourceID` (ARKit's `.removed`).
    /// Retained, not deleted — see `purgeStale`.
    public func markUnconfirmed(sourceID: UUID) {
        lock.withLock {
            guard let recordID = sourceToRecord[sourceID] else { return }
            records[recordID]?.isTracked = false
        }
    }

    /// Drops records unconfirmed for longer than `staleTimeout`. Cheap
    /// enough to call on every anchor-stream update — no separate timer
    /// needed.
    public func purgeStale(now: TimeInterval) {
        lock.withLock {
            let expiredIDs = records.values
                .filter { !$0.isTracked && now - $0.lastConfirmed > staleTimeout }
                .map(\.id)
            guard !expiredIDs.isEmpty else { return }
            let expired = Set(expiredIDs)
            for id in expired { records.removeValue(forKey: id) }
            sourceToRecord = sourceToRecord.filter { !expired.contains($0.value) }
        }
    }

    /// All currently retained surfaces — tracked and not-yet-stale — the
    /// physics-facing snapshot.
    public var currentSurfaces: [RoomSurface] {
        lock.withLock { records.values.map(\.surface) }
    }

    public var recordCount: Int {
        lock.withLock { records.count }
    }

    /// Drops all retained surfaces, e.g. on session teardown.
    public func removeAll() {
        lock.withLock {
            records.removeAll()
            sourceToRecord.removeAll()
        }
    }

    // MARK: - Merge matching (lock held by caller)

    private func bestMatch(for surface: RoomSurface) -> UUID? {
        var best: (id: UUID, distance: Float)?
        for (id, record) in records {
            guard simd_dot(record.surface.normal, surface.normal) >= mergeNormalAlignment else { continue }
            let distance = simd_length(record.surface.center - surface.center)
            guard distance <= mergeDistance else { continue }
            if best == nil || distance < best!.distance {
                best = (id, distance)
            }
        }
        return best?.id
    }
}
