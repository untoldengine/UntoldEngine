//
//  ClipSampler.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd

/// Samples a `CompiledAnimationClip` into a `PoseBuffer` without allocating.
///
/// Keyframe intervals are located with a binary search seeded by a per-joint
/// cursor hint: playback advances monotonically, so consecutive frames almost
/// always hit the hint (or its successor) and skip the search entirely.
/// Cursors are hints only — a stale or wrong cursor changes nothing but
/// speed.
///
/// The interpolation semantics intentionally reproduce
/// `Animation.interpolateKeyframes` exactly (clamping before the first key,
/// per-channel wrapping on the channel's own last key time, non-repeating
/// clamp on the last key) so the compiled path is a drop-in replacement for
/// the string-keyed path; the equality is enforced by unit tests.
struct ClipSampler {
    private var rotationCursors: [Int] = []
    private var translationCursors: [Int] = []
    private var boundClip: ObjectIdentifier?

    /// Samples the clip at `time` into `pose`.
    ///
    /// `duration` and `speed` come from the live `AnimationClip` at the call
    /// site: the outer wrap uses the clip duration and the channel lookup
    /// time is scaled by the clip speed, matching
    /// `Skeleton.updateWorldPose(at:animationClip:)`.
    mutating func sample(
        _ clip: CompiledAnimationClip,
        time: Float,
        duration: Float,
        speed: Float,
        into pose: inout PoseBuffer
    ) {
        bind(clip)
        pose.resize(jointCount: clip.jointCount)

        let channelTime = fmod(time, duration) * speed

        for index in 0 ..< clip.jointCount {
            let channel = clip.channels[index]

            guard channel.animated else {
                pose.translations[index] = clip.restTranslations[index]
                pose.rotations[index] = clip.restRotations[index]
                continue
            }

            pose.rotations[index] = sampleChannel(
                times: channel.rotationTimes,
                values: channel.rotationValues,
                repeats: channel.repeats,
                at: channelTime,
                cursor: &rotationCursors[index],
                interpolate: simd_slerp
            ) ?? clip.restRotations[index]

            pose.translations[index] = sampleChannel(
                times: channel.translationTimes,
                values: channel.translationValues,
                repeats: channel.repeats,
                at: channelTime,
                cursor: &translationCursors[index],
                interpolate: { a, b, t in a + (b - a) * t }
            ) ?? clip.restTranslations[index]
        }
    }

    // MARK: - Private Helpers

    /// Resets cursor storage when the sampled clip changes.
    private mutating func bind(_ clip: CompiledAnimationClip) {
        let identifier = ObjectIdentifier(clip)
        guard boundClip != identifier else { return }
        boundClip = identifier
        rotationCursors = [Int](repeating: 1, count: clip.jointCount)
        translationCursors = [Int](repeating: 1, count: clip.jointCount)
    }

    /// Locates the keyframe interval containing `time` and interpolates.
    /// Returns nil when the channel is empty or no interval matches, in
    /// which case the caller falls back to the rest pose.
    private func sampleChannel<Value>(
        times: [Float],
        values: [Value],
        repeats: Bool,
        at time: Float,
        cursor: inout Int,
        interpolate: (Value, Value, Float) -> Value
    ) -> Value? {
        guard let lastTime = times.last else { return nil }

        if times[0] >= time {
            return values[0]
        }
        if time >= lastTime, !repeats {
            return values[values.count - 1]
        }

        let wrappedTime = fmod(time, lastTime)
        guard let index = findInterval(times: times, at: wrappedTime, cursor: &cursor) else {
            return nil
        }

        let previousTime = times[index - 1]
        let nextTime = times[index]
        let t = (wrappedTime - previousTime) / (nextTime - previousTime)
        return interpolate(values[index - 1], values[index], t)
    }

    /// Finds the smallest index `i` in `1..<times.count` with
    /// `time < times[i]`, trying the cursor hint (and its successor) before
    /// falling back to binary search.
    private func findInterval(times: [Float], at time: Float, cursor: inout Int) -> Int? {
        let count = times.count
        guard count > 1 else { return nil }

        let hint = cursor
        if hint >= 1, hint < count, time < times[hint], hint == 1 || times[hint - 1] <= time {
            return hint
        }
        let next = hint + 1
        if hint >= 1, next < count, time < times[next], times[next - 1] <= time {
            cursor = next
            return next
        }

        var low = 1
        var high = count - 1
        var found = count
        while low <= high {
            let mid = (low + high) / 2
            if time < times[mid] {
                found = mid
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        guard found < count else { return nil }
        cursor = found
        return found
    }
}
