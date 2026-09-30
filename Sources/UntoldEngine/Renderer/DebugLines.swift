//
//  DebugLines.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// One world-space line of the debug overlay.
public struct DebugLineSegment: Sendable, Equatable {
    public var start: simd_float3
    public var end: simd_float3
    public var color: simd_float4

    public init(from start: simd_float3, to end: simd_float3, color: simd_float4) {
        self.start = start
        self.end = end
        self.color = color
    }
}

/// Named sets of world-space lines drawn by the debug overlay pass over the
/// lit scene, never depth-tested (see `RenderPasses.muscleDebugExecution`).
/// A caller replaces a whole set at a time, usually once per frame, from any
/// thread; the pass reads a snapshot when it encodes.
final class DebugLineStore: @unchecked Sendable {
    static let shared = DebugLineStore()

    private let lock = NSLock()
    private var sets: [String: [DebugLineSegment]] = [:]

    var isEmpty: Bool {
        lock.withLock { sets.isEmpty }
    }

    func set(_ segments: [DebugLineSegment], named name: String) {
        lock.withLock {
            if segments.isEmpty {
                sets[name] = nil
            } else {
                sets[name] = segments
            }
        }
    }

    func remove(named name: String) {
        lock.withLock { sets[name] = nil }
    }

    func removeAll() {
        lock.withLock { sets.removeAll() }
    }

    func snapshot() -> [[DebugLineSegment]] {
        lock.withLock { sets.sorted { $0.key < $1.key }.map(\.value) }
    }
}

/// Replaces the debug lines of set `name` (an empty list removes the set).
/// Lines are in world space and drawn over everything until replaced or
/// cleared; a tuning and diagnostics aid, not a shipping feature.
public func setDebugLines(_ segments: [DebugLineSegment], named name: String) {
    DebugLineStore.shared.set(segments, named: name)
}

public func clearDebugLines(named name: String) {
    DebugLineStore.shared.remove(named: name)
}

public func clearDebugLines() {
    DebugLineStore.shared.removeAll()
}
