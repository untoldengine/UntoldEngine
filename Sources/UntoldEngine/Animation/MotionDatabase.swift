//
//  MotionDatabase.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Motion matching database: every animation clip resampled at a fixed rate
// into (clip, time) frames, each with a feature vector describing what the
// character is doing at that instant — where its feet are and how fast
// they move, how fast the hips travel, and where the root will be shortly.
// At runtime a query built from the current pose and the AI's desired
// trajectory finds the nearest frame by brute force; playback jumps there
// through an inertialized transition.
//
// Features live in character space: the root joint's horizontal position
// and yaw at the frame define the frame of reference, so the same walk
// matches regardless of where in the world it was authored. Future values
// past a clip's end wrap with the clip's per-loop root displacement/yaw
// (clips are assumed to loop, keys spanning the full duration).
//
// The database is built at load time from clips already loaded on the
// entity — a few minutes of animation resamples in milliseconds. A
// persisted binary format is deferred until database sizes justify it.
// See docs/Architecture/animationPoseLayer.md.

/// Feature group weights: how much each aspect matters in the distance.
public struct MotionMatchingWeights {
    public var footPosition: Float
    public var footVelocity: Float
    public var hipVelocity: Float
    public var trajectoryPosition: Float
    public var trajectoryDirection: Float

    public init(
        footPosition: Float = 0.75,
        footVelocity: Float = 1.0,
        hipVelocity: Float = 1.0,
        trajectoryPosition: Float = 1.0,
        trajectoryDirection: Float = 1.25
    ) {
        self.footPosition = footPosition
        self.footVelocity = footVelocity
        self.hipVelocity = hipVelocity
        self.trajectoryPosition = trajectoryPosition
        self.trajectoryDirection = trajectoryDirection
    }
}

/// Layout of one feature vector. Order (character space):
/// left foot pos (3), right foot pos (3), left foot vel (3),
/// right foot vel (3), hip vel (3), trajectory positions x/z at each
/// horizon (2 each), trajectory facing x/z at each horizon (2 each).
enum MotionFeatureLayout {
    static let trajectoryHorizons: [Float] = [0.33, 0.66, 1.0]
    static let poseDimensions = 15
    static var trajectoryDimensions: Int {
        trajectoryHorizons.count * 4
    }

    static var dimensions: Int {
        poseDimensions + trajectoryDimensions
    }

    static func groupWeight(forDimension d: Int, weights: MotionMatchingWeights) -> Float {
        switch d {
        case 0 ..< 6: return weights.footPosition
        case 6 ..< 12: return weights.footVelocity
        case 12 ..< 15: return weights.hipVelocity
        default:
            let t = d - poseDimensions
            return t % 4 < 2 ? weights.trajectoryPosition : weights.trajectoryDirection
        }
    }
}

final class MotionDatabase {
    struct Frame {
        let clipIndex: Int
        let time: Float
    }

    /// Clips referenced by frames, with their compiled forms.
    let clips: [AnimationClip]
    let compiledClips: [CompiledAnimationClip]

    let frames: [Frame]
    /// First frame index of each clip's contiguous run in `frames`.
    let clipFrameOffsets: [Int]
    let dimensions = MotionFeatureLayout.dimensions
    let sampleInterval: Float

    /// Feature vectors, flattened, pre-scaled by `scales` so the search is
    /// a plain squared distance.
    private let features: [Float]

    /// Per-dimension scale = groupWeight / stdDev.
    let scales: [Float]

    /// Joint indices the features are built from.
    let rootJointIndex: Int
    let leftFootIndex: Int
    let rightFootIndex: Int

    init?(
        clips: [AnimationClip],
        compiledClips: [CompiledAnimationClip],
        skeleton: Skeleton,
        leftFootPath: String,
        rightFootPath: String,
        sampleRate: Float,
        weights: MotionMatchingWeights
    ) {
        guard clips.count == compiledClips.count, clips.isEmpty == false, sampleRate > 0 else { return nil }
        guard let leftFoot = skeleton.jointPaths.firstIndex(of: leftFootPath),
              let rightFoot = skeleton.jointPaths.firstIndex(of: rightFootPath),
              let root = skeleton.parentIndices.firstIndex(where: { $0 == nil })
        else { return nil }

        self.clips = clips
        self.compiledClips = compiledClips
        rootJointIndex = root
        leftFootIndex = leftFoot
        rightFootIndex = rightFoot
        sampleInterval = 1.0 / sampleRate

        var frames: [Frame] = []
        var clipFrameOffsets: [Int] = []
        var rawFeatures: [Float] = []

        var sampler = ClipSampler()
        var pose = PoseBuffer()
        var positions: [simd_float3] = []
        var rotations: [simd_quatf] = []

        /// Samples the root's model-space translation and yaw at an
        /// unwrapped time, correcting whole loops with the clip's per-loop
        /// displacement so future trajectory values never snap backward.
        func rootSample(
            clip: AnimationClip, compiled: CompiledAnimationClip,
            at time: Float, sampler: inout ClipSampler, pose: inout PoseBuffer
        ) -> (position: simd_float3, yaw: Float) {
            let duration = max(clip.duration, 1e-4)
            let loops = floor(time / duration)
            let wrapped = time - loops * duration
            sampler.sample(compiled, time: wrapped, duration: clip.duration, speed: clip.speed, into: &pose)
            let position = pose.translations[root] + compiled.rootTranslationPerLoop * loops
            let yaw = yawTwist(pose.rotations[root]).yaw + compiled.rootYawPerLoop * loops
            return (position, yaw)
        }

        for (clipIndex, clip) in clips.enumerated() {
            clipFrameOffsets.append(frames.count)
            let compiled = compiledClips[clipIndex]
            guard compiled.jointCount == skeleton.jointPaths.count else { continue }
            let duration = clip.duration
            guard duration > 0 else { continue }

            let frameCount = max(1, Int((duration / sampleInterval).rounded()))
            for frameIndex in 0 ..< frameCount {
                let time = Float(frameIndex) * sampleInterval
                let dt = sampleInterval

                // Current frame pose in model space.
                sampler.sample(compiled, time: time, duration: duration, speed: clip.speed, into: &pose)
                computeForwardKinematics(
                    pose: pose, parentIndices: skeleton.parentIndices,
                    positions: &positions, rotations: &rotations
                )
                let rootPosition = positions[root]
                let rootYaw = yawTwist(rotations[root]).yaw
                let inverseYaw = simd_quatf(angle: -rootYaw, axis: simd_float3(0, 1, 0))
                let rootHorizontal = simd_float3(rootPosition.x, 0, rootPosition.z)

                func toCharacterSpace(_ p: simd_float3) -> simd_float3 {
                    inverseYaw.act(p - rootHorizontal)
                }

                let leftFootCS = toCharacterSpace(positions[leftFoot])
                let rightFootCS = toCharacterSpace(positions[rightFoot])

                // Next-sample pose for velocities (feet and hips), with the
                // loop-wrap correction on the root.
                var nextSampler = sampler
                let nextRoot = rootSample(clip: clip, compiled: compiled, at: time + dt, sampler: &nextSampler, pose: &pose)
                computeForwardKinematics(
                    pose: pose, parentIndices: skeleton.parentIndices,
                    positions: &positions, rotations: &rotations
                )
                // The wrapped sample's positions need the same loop shift as the root.
                let loopShift = nextRoot.position - positions[root]
                let leftFootVelocity = (toCharacterSpace(positions[leftFoot] + loopShift) - leftFootCS) / dt
                let rightFootVelocity = (toCharacterSpace(positions[rightFoot] + loopShift) - rightFootCS) / dt
                let hipVelocity = inverseYaw.act(nextRoot.position - rootPosition) / dt

                var vector: [Float] = []
                vector.reserveCapacity(MotionFeatureLayout.dimensions)
                for value in [leftFootCS, rightFootCS, leftFootVelocity, rightFootVelocity, hipVelocity] {
                    vector.append(value.x)
                    vector.append(value.y)
                    vector.append(value.z)
                }

                for horizon in MotionFeatureLayout.trajectoryHorizons {
                    var futureSampler = sampler
                    let future = rootSample(clip: clip, compiled: compiled, at: time + horizon, sampler: &futureSampler, pose: &pose)
                    let relative = inverseYaw.act(future.position - rootHorizontal)
                    vector.append(relative.x)
                    vector.append(relative.z)
                    let yawDelta = future.yaw - rootYaw
                    vector.append(sin(yawDelta))
                    vector.append(cos(yawDelta))
                }

                frames.append(Frame(clipIndex: clipIndex, time: time))
                rawFeatures.append(contentsOf: vector)
            }
        }

        guard frames.isEmpty == false else { return nil }
        self.frames = frames
        self.clipFrameOffsets = clipFrameOffsets

        // Per-dimension standard deviation for normalization; degenerate
        // dimensions (constant across the database) get scale from weight
        // alone so they cannot blow up the distance.
        let dims = MotionFeatureLayout.dimensions
        let count = frames.count
        var scales = [Float](repeating: 1, count: dims)
        for d in 0 ..< dims {
            var mean: Float = 0
            for f in 0 ..< count {
                mean += rawFeatures[f * dims + d]
            }
            mean /= Float(count)
            var variance: Float = 0
            for f in 0 ..< count {
                let delta = rawFeatures[f * dims + d] - mean
                variance += delta * delta
            }
            variance /= Float(count)
            let std = sqrt(variance)
            let weight = MotionFeatureLayout.groupWeight(forDimension: d, weights: weights)
            scales[d] = std > 1e-5 ? weight / std : weight
        }
        self.scales = scales

        var scaled = rawFeatures
        for f in 0 ..< count {
            for d in 0 ..< dims {
                scaled[f * dims + d] *= scales[d]
            }
        }
        features = scaled
    }

    /// Nearest stored frame index for a (clip, wrapped time) position, or
    /// nil when the clip is not part of the database.
    func frameIndex(ofClip clip: AnimationClip, time: Float) -> Int? {
        guard let clipIndex = clips.firstIndex(where: { $0 === clip }) else { return nil }
        let start = clipFrameOffsets[clipIndex]
        let end = clipIndex + 1 < clipFrameOffsets.count ? clipFrameOffsets[clipIndex + 1] : frames.count
        guard start < end else { return nil }
        let offset = Int((time / sampleInterval).rounded())
        return min(max(start + offset, start), end - 1)
    }

    /// A candidate must beat the currently playing frame's cost by this
    /// factor to justify a jump — hysteresis against equal-cost and
    /// noise-level "improvements" that would otherwise cause pointless
    /// phase jumps every search.
    private static let switchMargin: Float = 0.9

    /// Brute-force nearest neighbour. `query` is a raw (unscaled) feature
    /// vector; returns the best frame index. When `preferredIndex` is
    /// given (the frame playback is currently at), the search is seeded
    /// with its discounted cost, so only meaningfully better frames win.
    func search(query: [Float], preferredIndex: Int? = nil) -> Int? {
        guard query.count == dimensions, frames.isEmpty == false else { return nil }

        var scaledQuery = query
        for d in 0 ..< dimensions {
            scaledQuery[d] *= scales[d]
        }

        var bestIndex = 0
        var bestCost = Float.greatestFiniteMagnitude
        if let preferredIndex, preferredIndex >= 0, preferredIndex < frames.count {
            var cost: Float = 0
            let base = preferredIndex * dimensions
            for d in 0 ..< dimensions {
                let delta = features[base + d] - scaledQuery[d]
                cost += delta * delta
            }
            bestIndex = preferredIndex
            bestCost = cost * Self.switchMargin
        }
        features.withUnsafeBufferPointer { buffer in
            for f in 0 ..< frames.count {
                var cost: Float = 0
                let base = f * dimensions
                for d in 0 ..< dimensions {
                    let delta = buffer[base + d] - scaledQuery[d]
                    cost += delta * delta
                    if cost >= bestCost {
                        break
                    }
                }
                if cost < bestCost {
                    bestCost = cost
                    bestIndex = f
                }
            }
        }
        return bestIndex
    }

    /// Raw (unscaled) feature vector of a stored frame — used by tests and
    /// for building continuity-biased queries.
    func rawFeatures(at frameIndex: Int) -> [Float] {
        let base = frameIndex * dimensions
        return (0 ..< dimensions).map { d in
            scales[d] > 0 ? features[base + d] / scales[d] : features[base + d]
        }
    }
}
