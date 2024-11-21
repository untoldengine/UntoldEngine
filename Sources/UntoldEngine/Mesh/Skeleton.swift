//
//  Skeleton.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/13/24.
//

import MetalKit

class Skeleton {
    let parentIndices: [Int?]
    let jointPaths: [String]
    let bindTransform: [simd_float4x4]
    let restTransform: [simd_float4x4]
    var currentPose: [simd_float4x4]

    init?(mdlSkeleton: MDLSkeleton?) {
        guard let mdlSkeleton, !mdlSkeleton.jointPaths.isEmpty else { return nil }

        jointPaths = mdlSkeleton.jointPaths
        parentIndices = Skeleton.computeParentIndices(for: jointPaths)
        bindTransform = mdlSkeleton.jointBindTransforms.float4x4Array
        restTransform = mdlSkeleton.jointRestTransforms.float4x4Array
        currentPose = restTransform
    }

    static func computeParentIndices(for jointPaths: [String]) -> [Int?] {
        return jointPaths.enumerated().map { _, jointPath in
            let parentPath = URL(fileURLWithPath: jointPath)
                .deletingLastPathComponent()
                .relativePath
            return jointPaths.firstIndex(of: parentPath)
        }
    }

    /// Maps external joint paths to indices in the skeleton's joint paths
    func mapJoints(from jointPaths: [String]) -> [Int] {
        return jointPaths.compactMap { self.jointPaths.firstIndex(of: $0) }
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
            animationClip.getPose(at: time * animationClip.speed, jointPath: jointPaths[index])
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

struct Skin {
    var jointPaths: [String] = []
    var skinToSkeletonMap: [Int] = [] // Maps skin joints to skeleton joints
    var jointTransformsBuffer: MTLBuffer // Buffer holding joint transforms

    /// Initializes a Skin object with an animation bind component and a skeleton
    init?(animationBindComponent: MDLAnimationBindComponent?, skeleton: Skeleton?) {
        guard let animationBindComponent, let skeleton else {
            handleError(.noAnimationBind)
            return nil
        }

        jointPaths = animationBindComponent.jointPaths ?? skeleton.jointPaths
        skinToSkeletonMap = skeleton.mapJoints(from: jointPaths)

        guard let buffer = Skin.createBuffer(for: jointPaths.count) else {
            handleError(.jointBufferFailed)
            return nil
        }
        jointTransformsBuffer = buffer
    }
    
    /// Initialize a skin object with zero data-for entities with no armature
    init?(){
        
        guard let buffer = Skin.createBuffer(for: 1) else {
            handleError(.jointBufferFailed)
            return nil
        }
        
        jointTransformsBuffer = buffer
    }

    /// Updates the joint transform matrices in the buffer using the skeleton's current pose
    func updateJointMatrices(skeleton: Skeleton?) {
        guard let skeletonPose = skeleton?.currentPose else {
            handleError(.noSkeletonPose)
            return
        }

        guard let pointer = Skin.bindBuffer(jointTransformsBuffer, jointCount: jointPaths.count) else {
            handleError(.jointBindFailed)
            return
        }

        for (index, skinIndex) in skinToSkeletonMap.enumerated() {
            pointer[index] = skeletonPose[skinIndex]
        }
    }

    // MARK: - Private Helpers

    /// Creates a Metal buffer for storing joint transform matrices
    private static func createBuffer(for jointCount: Int) -> MTLBuffer? {
        let bufferSize = jointCount * MemoryLayout<simd_float4x4>.stride
        return renderInfo.device.makeBuffer(length: bufferSize)
    }

    /// Binds the Metal buffer and returns a typed pointer
    private static func bindBuffer(_ buffer: MTLBuffer, jointCount: Int) -> UnsafeMutablePointer<simd_float4x4>? {
        return buffer.contents().bindMemory(to: simd_float4x4.self, capacity: jointCount)
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
        return interpolateKeyframes(translations, at: time) { a, b, t in
            a + (b - a) * t
        }
    }

    /// Retrieves the interpolated rotation value at the specified time
    func getRotation(at time: Float) -> simd_quatf? {
        return interpolateKeyframes(rotations, at: time, interpolate: simd_slerp)
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

    /// Retrieves the interpolated pose for a joint at a specific time
    func getPose(at time: Float, jointPath: String) -> float4x4? {
        guard let animation = jointAnimation[jointPath] else { return nil }
        let rotation = animation.getRotation(at: time) ?? simd_quatf(.identity)
        let translation = animation.getTranslation(at: time) ?? simd_float3(repeating: 0)
        return float4x4(translation: translation) * float4x4(rotation)
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
        return times.enumerated().map { index, time in
            let startIndex = index * jointCount
            let endIndex = startIndex + jointCount
            let jointValues = Array(values[startIndex ..< endIndex])
            return Keyframe(time: Float(time), value: jointValues[jointIndex])
        }
    }
}
