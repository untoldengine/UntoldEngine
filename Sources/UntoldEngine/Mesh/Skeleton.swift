//
//  Skeleton.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit

class Skeleton {
    var parentIndices: [Int?]
    var jointPaths: [String]
    var bindTransform: [simd_float4x4]
    var restTransform: [simd_float4x4]
    var currentPose: [simd_float4x4]

    init?(mdlSkeleton: MDLSkeleton?) {
        guard let mdlSkeleton, !mdlSkeleton.jointPaths.isEmpty else { return nil }

        jointPaths = mdlSkeleton.jointPaths
        parentIndices = Skeleton.computeParentIndices(for: jointPaths)
        bindTransform = mdlSkeleton.jointBindTransforms.float4x4Array
        restTransform = mdlSkeleton.jointRestTransforms.float4x4Array
        currentPose = restTransform
    }

    init?(runtimeSkeleton: RuntimeSkeleton) {
        guard !runtimeSkeleton.jointPaths.isEmpty,
              runtimeSkeleton.jointPaths.count == runtimeSkeleton.parentIndices.count,
              runtimeSkeleton.jointPaths.count == runtimeSkeleton.bindTransforms.count,
              runtimeSkeleton.jointPaths.count == runtimeSkeleton.restTransforms.count
        else { return nil }

        jointPaths = runtimeSkeleton.jointPaths
        parentIndices = runtimeSkeleton.parentIndices
        bindTransform = runtimeSkeleton.bindTransforms
        restTransform = runtimeSkeleton.restTransforms
        currentPose = runtimeSkeleton.restTransforms
    }

    deinit {}

    static func computeParentIndices(for jointPaths: [String]) -> [Int?] {
        jointPaths.enumerated().map { _, jointPath in
            let parentPath = URL(fileURLWithPath: jointPath)
                .deletingLastPathComponent()
                .relativePath
            return jointPaths.firstIndex(of: parentPath)
        }
    }

    /// Maps external joint paths to indices in the skeleton's joint paths
    func mapJoints(from jointPaths: [String]) -> [Int] {
        jointPaths.compactMap { self.jointPaths.firstIndex(of: $0) }
    }

    /// Updates the skeleton's world pose based on animation data
    func updateWorldPose(at currentTime: Float, animationClip: AnimationClip) {
        let time = fmod(currentTime, animationClip.duration)

        // Compute poses
        let localPose = computeLocalPose(at: time, with: animationClip)
        currentPose = computeWorldPose(from: localPose, applyBindTransform: true)
    }

    /// Resets the skeleton to its rest pose
    func resetPoseToRest() {
        currentPose = computeWorldPose(from: restTransform, applyBindTransform: true)
    }

    // MARK: - Private Helpers

    /// Computes local joint transforms based on an animation clip
    private func computeLocalPose(at time: Float, with animationClip: AnimationClip) -> [simd_float4x4] {
        jointPaths.indices.map { index in
            animationClip.getPose(
                at: time * animationClip.speed,
                jointPath: jointPaths[index],
                fallback: restTransform[index]
            )
                ?? restTransform[index]
        }
    }

    /// Computes world poses from local poses and optionally applies inverse bind transforms
    private func computeWorldPose(from localPose: [simd_float4x4], applyBindTransform: Bool = false) -> [simd_float4x4] {
        var worldPose = [simd_float4x4](repeating: .identity, count: jointPaths.count)

        // Compute world transform for each joint
        for index in 0 ..< parentIndices.count {
            let localMatrix = localPose[index]
            if let parentIndex = parentIndices[index] {
                worldPose[index] = worldPose[parentIndex] * localMatrix
            } else {
                worldPose[index] = localMatrix
            }
        }

        // Optionally apply inverse bind transforms
        if applyBindTransform {
            for index in 0 ..< worldPose.count {
                worldPose[index] *= bindTransform[index].inverse
            }
        }

        return worldPose
    }
}

/// Ring of joint-transform buffers so the CPU never rewrites a buffer a
/// previous frame's GPU work may still be reading.
///
/// The animation update runs before the renderer waits on
/// `commandBufferSemaphore`, so a write can overlap all
/// `maxInFlightCommandBuffers` frames still executing — the ring therefore
/// holds one extra slot. Each `write` rotates to the next buffer;
/// `currentBuffer` is always the most recently written one, so a skin that
/// stops animating keeps binding a buffer the CPU no longer touches.
///
/// This is a class so `Skin` copies (which already share their `MTLBuffer`
/// storage) also share the write cursor.
final class JointTransformsRing {
    private(set) var buffers: [MTLBuffer]
    private var writeIndex: Int = 0
    let jointCount: Int

    /// All buffers are pre-filled with identity matrices so the bind pose
    /// renders correctly before any animation write occurs.
    init?(jointCount: Int) {
        let slotCount = maxInFlightCommandBuffers + 1
        let bufferSize = jointCount * MemoryLayout<simd_float4x4>.stride
        var buffers: [MTLBuffer] = []
        buffers.reserveCapacity(slotCount)

        for _ in 0 ..< slotCount {
            guard let buffer = renderInfo.device.makeBuffer(length: bufferSize) else {
                handleError(.bufferAllocationFailed, "joint transforms: \(bufferSize) bytes for \(jointCount) joints — device likely under memory pressure")
                return nil
            }
            let pointer = buffer.contents().bindMemory(to: simd_float4x4.self, capacity: jointCount)
            for jointIndex in 0 ..< jointCount {
                pointer[jointIndex] = matrix_identity_float4x4
            }
            buffers.append(buffer)
        }

        self.buffers = buffers
        self.jointCount = jointCount
    }

    /// The buffer render passes should bind: the most recently written slot.
    var currentBuffer: MTLBuffer {
        buffers[writeIndex]
    }

    /// Rotates to the next slot and fills it via `fill`, which receives a
    /// typed pointer to the slot's contents.
    func write(_ fill: (UnsafeMutablePointer<simd_float4x4>) -> Void) {
        let nextIndex = (writeIndex + 1) % buffers.count
        let pointer = buffers[nextIndex].contents().bindMemory(to: simd_float4x4.self, capacity: jointCount)
        fill(pointer)
        writeIndex = nextIndex
    }
}

struct Skin {
    var jointPaths: [String] = []
    var skinToSkeletonMap: [Int] = [] // Maps skin joints to skeleton joints
    var jointTransformsRing: JointTransformsRing!

    /// The joint transforms buffer render passes bind this frame.
    var jointTransformsBuffer: MTLBuffer! {
        jointTransformsRing?.currentBuffer
    }

    /// Initializes a Skin object with an animation bind component and a skeleton
    init?(animationBindComponent: MDLAnimationBindComponent?, skeleton: Skeleton?) {
        guard let animationBindComponent, let skeleton else {
            handleError(.noAnimationBind)
            return nil
        }

        jointPaths = animationBindComponent.jointPaths ?? skeleton.jointPaths
        skinToSkeletonMap = skeleton.mapJoints(from: jointPaths)

        guard let ring = JointTransformsRing(jointCount: jointPaths.count) else {
            handleError(.jointBufferFailed)
            return nil
        }
        jointTransformsRing = ring
    }

    init?(runtimeSkin: RuntimeSkinBinding) {
        skinToSkeletonMap = runtimeSkin.skinToSkeletonMap
        jointPaths = runtimeSkin.skinToSkeletonMap.map { "joint_\($0)" }

        guard let ring = JointTransformsRing(jointCount: jointPaths.count) else {
            handleError(.jointBufferFailed)
            return nil
        }
        jointTransformsRing = ring
    }

    /// Initialize a skin object with zero data-for entities with no armature
    init?() {
        guard let ring = JointTransformsRing(jointCount: 1) else {
            handleError(.jointBufferFailed)
            return nil
        }

        jointTransformsRing = ring
    }

    /// Clean up
    mutating func cleanUp() {
        jointTransformsRing = nil
        jointPaths.removeAll()
        skinToSkeletonMap.removeAll()
    }

    /// Updates the joint transform matrices in the next ring slot using the
    /// skeleton's current pose
    func updateJointMatrices(skeleton: Skeleton?) {
        guard let skeletonPose = skeleton?.currentPose else {
            handleError(.noSkeletonPose)
            return
        }

        guard let ring = jointTransformsRing else {
            handleError(.jointBindFailed)
            return
        }

        ring.write { pointer in
            for (index, skinIndex) in skinToSkeletonMap.enumerated() {
                pointer[index] = skeletonPose[skinIndex]
            }
        }
    }
}

struct Keyframe<Value> {
    var time: Float = 0 // Time of the keyframe
    var value: Value // Value at the keyframe
}

struct Animation {
    var translations: [Keyframe<simd_float3>] = [] // Keyframes for translations
    var rotations: [Keyframe<simd_quatf>] = [] // Keyframes for rotations
    var repeatAnimation = true // Whether the animation should loop

    /// Retrieves the interpolated translation value at the specified time
    func getTranslation(at time: Float) -> simd_float3? {
        interpolateKeyframes(translations, at: time) { a, b, t in
            a + (b - a) * t
        }
    }

    /// Retrieves the interpolated rotation value at the specified time
    func getRotation(at time: Float) -> simd_quatf? {
        interpolateKeyframes(rotations, at: time, interpolate: simd_slerp)
    }

    // MARK: - Private Helpers

    /// Generic keyframe interpolation
    private func interpolateKeyframes<Value>(
        _ keyframes: [Keyframe<Value>],
        at time: Float,
        interpolate: (Value, Value, Float) -> Value
    ) -> Value? {
        guard let lastKeyframe = keyframes.last else { return nil }

        var currentTime = time

        // Handle time wrapping for looping animations
        if let first = keyframes.first, first.time >= currentTime {
            return first.value
        }
        if currentTime >= lastKeyframe.time, !repeatAnimation {
            return lastKeyframe.value
        }
        currentTime = fmod(currentTime, lastKeyframe.time)

        // Find the surrounding keyframes
        let keyFramePairs = keyframes.indices.dropFirst().map {
            (previous: keyframes[$0 - 1], next: keyframes[$0])
        }

        guard let (previousKey, nextKey) = keyFramePairs.first(where: {
            currentTime < $0.next.time
        }) else {
            return nil
        }

        // Interpolate between the two keyframes
        let t = (currentTime - previousKey.time) / (nextKey.time - previousKey.time)
        return interpolate(previousKey.value, nextKey.value, t)
    }
}

class AnimationClip {
    let name: String // Name of the animation clip
    var jointAnimation: [String: Animation] = [:] // Per-joint animations
    var duration: Float = 0 // Duration of the animation
    var speed: Float = 1 // Speed multiplier for playback
    var jointPaths: [String] = [] // Paths to joints affected by this clip

    /// Initializes the AnimationClip with a joint animation and a name
    init(animation: MDLPackedJointAnimation, animationName: String) {
        name = animationName
        jointPaths = animation.jointPaths
        duration = 0

        for jointIndex in jointPaths.indices {
            let jointPath = jointPaths[jointIndex]
            let animation = processJointAnimation(jointIndex: jointIndex, jointPath: jointPath, animation: animation)
            jointAnimation[jointPath] = animation
        }
    }

    init(runtimeClip: RuntimeAnimationClip) {
        name = runtimeClip.name
        duration = runtimeClip.duration
        jointPaths = runtimeClip.channels.map(\.jointPath)

        for channel in runtimeClip.channels {
            var animation = Animation()
            animation.translations = channel.translations.map {
                Keyframe(time: $0.time, value: $0.value)
            }
            animation.rotations = channel.rotations.map {
                Keyframe(time: $0.time, value: simd_quatf(ix: $0.value.x, iy: $0.value.y, iz: $0.value.z, r: $0.value.w))
            }
            jointAnimation[channel.jointPath] = animation
        }
    }

    func cleanUp() {
        jointPaths.removeAll()
        jointAnimation.removeAll()
    }

    /// Retrieves the interpolated pose for a joint at a specific time
    func getPose(at time: Float, jointPath: String) -> float4x4? {
        getPose(at: time, jointPath: jointPath, fallback: .identity)
    }

    /// Retrieves the interpolated pose while preserving rest-pose channels that are
    /// not authored by the clip. Many skeletal clips animate rotation only for most
    /// joints; those joints must keep their rest translation offsets. The runtime
    /// format does not store scale animation, so keep the rest-pose local scale too.
    func getPose(at time: Float, jointPath: String, fallback: float4x4) -> float4x4? {
        guard let animation = jointAnimation[jointPath] else { return nil }
        let fallbackScale = Self.localScale(from: fallback)
        let fallbackRotation = Self.localRotation(from: fallback, scale: fallbackScale)
        let rotation = animation.getRotation(at: time) ?? fallbackRotation
        let translation = animation.getTranslation(at: time) ?? simd_float3(
            fallback.columns.3.x,
            fallback.columns.3.y,
            fallback.columns.3.z
        )
        return float4x4(translation: translation) * float4x4(rotation) * float4x4(scale: fallbackScale)
    }

    private static func localScale(from matrix: float4x4) -> SIMD3<Float> {
        SIMD3<Float>(
            simd_length(SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z)),
            simd_length(SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z)),
            simd_length(SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z))
        )
    }

    private static func localRotation(from matrix: float4x4, scale: SIMD3<Float>) -> simd_quatf {
        let epsilon: Float = 0.000001
        let sx = max(scale.x, epsilon)
        let sy = max(scale.y, epsilon)
        let sz = max(scale.z, epsilon)
        let rotationMatrix = matrix_float3x3(columns: (
            SIMD3<Float>(matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z) / sx,
            SIMD3<Float>(matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z) / sy,
            SIMD3<Float>(matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z) / sz
        ))
        return simd_normalize(simd_quatf(rotationMatrix))
    }

    // MARK: - Private Helpers

    /// Processes a joint's animation and creates its Animation object
    private func processJointAnimation(
        jointIndex: Int,
        jointPath _: String,
        animation: MDLPackedJointAnimation
    ) -> Animation {
        var jointAnimation = Animation()

        jointAnimation.rotations = processKeyframes(
            times: animation.rotations.times.map { TimeInterval(Float($0)) }, // Convert [TimeInterval] to [Float]
            values: animation.rotations.floatQuaternionArray,
            jointIndex: jointIndex,
            jointCount: jointPaths.count
        )

        jointAnimation.translations = processKeyframes(
            times: animation.translations.times.map { TimeInterval(Float($0)) }, // Convert [TimeInterval] to [Float]
            values: animation.translations.float3Array,
            jointIndex: jointIndex,
            jointCount: jointPaths.count
        )

        // Update duration
        if let lastRotationTime = animation.rotations.times.last {
            duration = max(duration, Float(lastRotationTime))
        }
        if let lastTranslationTime = animation.translations.times.last {
            duration = max(duration, Float(lastTranslationTime))
        }

        return jointAnimation
    }

    /// Processes keyframes for a joint's animation (generic for rotations and translations)
    private func processKeyframes<Value>(
        times: [TimeInterval], // Changed to [TimeInterval] to reflect actual type
        values: [Value],
        jointIndex: Int,
        jointCount: Int
    ) -> [Keyframe<Value>] {
        times.enumerated().map { index, time in
            let startIndex = index * jointCount
            let endIndex = startIndex + jointCount
            let jointValues = Array(values[startIndex ..< endIndex])
            return Keyframe(time: Float(time), value: jointValues[jointIndex])
        }
    }
}
