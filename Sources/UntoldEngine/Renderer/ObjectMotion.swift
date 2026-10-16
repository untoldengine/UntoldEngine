//
//  ObjectMotion.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Where each entity was the frame before: the world transform it was drawn with, for the
/// velocity the opaque pass writes per pixel (the temporal resolve finds a moving surface's
/// history where the surface was, not where the camera's motion alone would put it).
public final class ObjectMotion: @unchecked Sendable {
    public static let shared = ObjectMotion()

    private struct Entry {
        var frame: UInt64
        var previous: simd_float4x4
        var current: simd_float4x4
    }

    private let lock = NSLock()
    private var entries: [EntityID: Entry] = [:]
    private var frame: UInt64 = 1

    /// Once per frame, before its passes: a new frame begins. Both eyes of a headset frame
    /// draw within the same one, so the second eye sees the same previous transforms.
    public func beginFrame() {
        lock.lock()
        frame &+= 1
        // Entities not drawn for a while are forgotten (they come back as newly seen).
        if frame % 600 == 0 {
            let stale = frame &- 300
            entries = entries.filter { $0.value.frame >= stale }
        }
        lock.unlock()
    }

    /// The entity's world transform of the previous frame — `current` on its first sighting,
    /// so it does not move — and `current` recorded as this frame's for the next.
    public func previousWorldTransform(of entityId: EntityID, current: simd_float4x4) -> simd_float4x4 {
        lock.lock()
        defer { lock.unlock() }
        if var entry = entries[entityId] {
            if entry.frame != frame {
                entry = Entry(frame: frame, previous: entry.current, current: current)
                entries[entityId] = entry
            }
            return entry.previous
        }
        entries[entityId] = Entry(frame: frame, previous: current, current: current)
        return current
    }

    /// Forgets every entity: the next frame moves nothing.
    public func reset() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }
}
