//
//  TransformTrack.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// How a track moves from one key to the next.
public enum TrackEasing: Sendable, Equatable {
    /// At a constant rate.
    case linear
    /// Slowly away from the key, faster towards the next.
    case easeIn
    /// Fast away from the key, slowing into the next.
    case easeOut
    /// Slowly away and slowly in (a smoothstep).
    case easeInOut

    /// The progress through a segment, 0 to 1, for a fraction of its duration.
    public func progress(_ fraction: Float) -> Float {
        let t = min(max(fraction, 0), 1)
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return 1 - (1 - t) * (1 - t)
        case .easeInOut:
            return t * t * (3 - 2 * t)
        }
    }
}

/// A transform at a time on a track, and how the track leaves it for the next key.
public struct TransformKey: Sendable, Equatable {
    /// Seconds from the track's start.
    public var time: TimeInterval
    public var position: simd_float3
    public var rotation: simd_quatf
    public var scale: simd_float3
    /// How the track moves from this key to the next.
    public var easing: TrackEasing

    public init(
        time: TimeInterval,
        position: simd_float3,
        rotation: simd_quatf = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
        scale: simd_float3 = simd_float3(repeating: 1),
        easing: TrackEasing = .linear
    ) {
        self.time = time
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.easing = easing
    }
}

/// A position, rotation and scale sampled from a track.
public struct TransformPose: Sendable, Equatable {
    public var position: simd_float3
    public var rotation: simd_quatf
    public var scale: simd_float3

    public init(position: simd_float3, rotation: simd_quatf, scale: simd_float3) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

/// Transform keys sampled at an absolute time: a frame's pose is a function of the frame's
/// presentation time alone, with no state carried over from the frame before, so a frame the
/// display skipped lands where the timeline says and the frames after it step by one period
/// again. Sample it at `FrameTime.presentationTime` less the time the track started.
public struct TransformTrack: Sendable, Equatable {
    /// The keys in time order.
    public let keys: [TransformKey]
    /// Whether the track starts again after its last key, or holds the last key.
    public let loops: Bool

    public init(keys: [TransformKey], loops: Bool = false) {
        self.keys = keys.sorted { $0.time < $1.time }
        self.loops = loops
    }

    /// The time of the last key: the length of one pass.
    public var duration: TimeInterval { keys.last?.time ?? 0 }

    /// The pose `time` seconds into the track: before the first key the first key's, after the
    /// last the last's (or, looping, the pose that far into the next pass). Nil without keys.
    public func pose(at time: TimeInterval) -> TransformPose? {
        guard let first = keys.first, let last = keys.last else { return nil }
        var t = time
        if loops, duration > 0 {
            t = t.truncatingRemainder(dividingBy: duration)
            if t < 0 { t += duration }
        }
        if t <= first.time { return pose(of: first) }
        if t >= last.time { return pose(of: last) }

        // The segment the time falls in: the last key at or before it, and the one after.
        var index = 0
        while index + 1 < keys.count, keys[index + 1].time <= t {
            index += 1
        }
        let from = keys[index]
        let to = keys[index + 1]
        let span = to.time - from.time
        let fraction = span > 0 ? Float((t - from.time) / span) : 1
        let s = from.easing.progress(fraction)
        return TransformPose(
            position: simd_mix(from.position, to.position, simd_float3(repeating: s)),
            rotation: simd_slerp(from.rotation, to.rotation, s),
            scale: simd_mix(from.scale, to.scale, simd_float3(repeating: s))
        )
    }

    /// The pose for a frame: the track's time is the frame's presentation time less
    /// `startedAt`, the presentation time of the frame the track started in.
    public func pose(for frame: FrameTime, startedAt: TimeInterval) -> TransformPose? {
        pose(at: frame.presentationTime - startedAt)
    }

    private func pose(of key: TransformKey) -> TransformPose {
        TransformPose(position: key.position, rotation: key.rotation, scale: key.scale)
    }
}

/// Poses an entity from a track at a frame's presentation time: its position, rotation and
/// scale. `startedAt` is the presentation time of the frame the track started in.
public func applyTransformTrack(entityId: EntityID, track: TransformTrack, startedAt: TimeInterval, frame: FrameTime) {
    guard let pose = track.pose(for: frame, startedAt: startedAt) else { return }
    translateTo(entityId: entityId, position: pose.position)
    rotateTo(entityId: entityId, rotation: pose.rotation)
    scaleTo(entityId: entityId, scale: pose.scale)
}
