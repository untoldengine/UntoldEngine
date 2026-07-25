//
//  AnimationCompiledSamplerTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class AnimationCompiledSamplerTests: XCTestCase {
    // MARK: - Fixtures

    /// 4-joint skeleton: root → hips → spine, plus a leg hanging off hips.
    /// Rest transforms carry translations, a rotation, and one non-uniform
    /// scale so every code path in matrix reconstruction is exercised.
    /// Bind transforms are non-identity so the inverse-bind multiply matters.
    private func makeSkeleton() -> Skeleton {
        let restRoot = simd_float4x4(translation: simd_float3(0, 1, 0))
        let restHips = simd_float4x4(translation: simd_float3(0, 0.2, 0.1))
            * simd_float4x4(simd_quatf(angle: 0.3, axis: simd_float3(0, 1, 0)))
        let restSpine = simd_float4x4(translation: simd_float3(0, 0.5, 0))
            * simd_float4x4(scale: simd_float3(1.5, 2.0, 1.0))
        let restLeg = simd_float4x4(translation: simd_float3(0.15, -0.4, 0))
            * simd_float4x4(simd_quatf(angle: -0.2, axis: simd_float3(1, 0, 0)))

        let bindRoot = simd_float4x4(translation: simd_float3(0, 1, 0))
        let bindHips = bindRoot * simd_float4x4(translation: simd_float3(0, 0.2, 0.1))
        let bindSpine = bindHips * simd_float4x4(translation: simd_float3(0, 0.5, 0))
        let bindLeg = bindHips * simd_float4x4(translation: simd_float3(0.15, -0.4, 0))

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["root", "root/hips", "root/hips/spine", "root/hips/leg"],
            parentIndices: [nil, 0, 1, 1],
            bindTransforms: [bindRoot, bindHips, bindSpine, bindLeg],
            restTransforms: [restRoot, restHips, restSpine, restLeg]
        )

        guard let skeleton = Skeleton(runtimeSkeleton: runtimeSkeleton) else {
            fatalError("Failed to build test skeleton")
        }
        return skeleton
    }

    /// Walk-style clip: root has translation+rotation keys, hips is
    /// rotation-only (must keep its rest translation), spine has a single
    /// keyframe, leg is unanimated (must keep its full rest transform).
    private func makeWalkClip() -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            translations: [
                .init(time: 0.0, value: simd_float3(0, 1, 0)),
                .init(time: 0.5, value: simd_float3(0, 1.1, 0.5)),
                .init(time: 1.5, value: simd_float3(0, 0.95, 1.4)),
                .init(time: 2.0, value: simd_float3(0, 1, 2)),
            ],
            rotations: [
                .init(time: 0.0, value: quatValue(angle: 0.0)),
                .init(time: 1.0, value: quatValue(angle: 0.4)),
                .init(time: 2.0, value: quatValue(angle: 0.0)),
            ]
        )
        let hipsChannel = RuntimeAnimationChannel(
            jointPath: "root/hips",
            rotations: [
                .init(time: 0.0, value: quatValue(angle: 0.1)),
                .init(time: 0.7, value: quatValue(angle: -0.3)),
                .init(time: 2.0, value: quatValue(angle: 0.1)),
            ]
        )
        let spineChannel = RuntimeAnimationChannel(
            jointPath: "root/hips/spine",
            rotations: [
                .init(time: 0.25, value: quatValue(angle: 0.6)),
            ]
        )

        let runtimeClip = RuntimeAnimationClip(
            name: "walk",
            duration: 2.0,
            channels: [rootChannel, hipsChannel, spineChannel]
        )
        return AnimationClip(runtimeClip: runtimeClip)
    }

    private func makeIdleClip() -> AnimationClip {
        let rootChannel = RuntimeAnimationChannel(
            jointPath: "root",
            rotations: [
                .init(time: 0.0, value: quatValue(angle: 0.05)),
                .init(time: 1.0, value: quatValue(angle: -0.05)),
            ]
        )
        let runtimeClip = RuntimeAnimationClip(
            name: "idle",
            duration: 1.0,
            channels: [rootChannel]
        )
        return AnimationClip(runtimeClip: runtimeClip)
    }

    private func quatValue(angle: Float) -> SIMD4<Float> {
        let q = simd_quatf(angle: angle, axis: simd_normalize(simd_float3(0.2, 1, 0.1)))
        return SIMD4<Float>(q.imag.x, q.imag.y, q.imag.z, q.real)
    }

    // MARK: - Helpers

    private func legacyPose(skeleton: Skeleton, clip: AnimationClip, at time: Float) -> [simd_float4x4] {
        skeleton.updateWorldPose(at: time, animationClip: clip)
        return skeleton.currentPose
    }

    private func compiledPose(
        skeleton: Skeleton,
        clip: AnimationClip,
        compiled: CompiledAnimationClip,
        sampler: inout ClipSampler,
        pose: inout PoseBuffer,
        at time: Float
    ) -> [simd_float4x4] {
        sampler.sample(compiled, time: time, duration: clip.duration, speed: clip.speed, into: &pose)
        skeleton.updateWorldPose(from: pose, localScales: compiled.restScales)
        return skeleton.currentPose
    }

    private func assertPosesEqual(
        _ lhs: [simd_float4x4],
        _ rhs: [simd_float4x4],
        accuracy: Float = 1e-4,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.count, rhs.count, message, file: file, line: line)
        for jointIndex in lhs.indices {
            for column in 0 ..< 4 {
                for row in 0 ..< 4 {
                    XCTAssertEqual(
                        lhs[jointIndex][column][row],
                        rhs[jointIndex][column][row],
                        accuracy: accuracy,
                        "\(message) — joint \(jointIndex), column \(column), row \(row)",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    // MARK: - Equality gate: compiled path vs legacy path

    func testCompiledPathMatchesLegacyPathAtRepresentativeTimes() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        // Start, mid-interval, exact keys, near-wrap, wrap boundary, beyond
        // duration, and before the spine channel's single key.
        let sampleTimes: [Float] = [0.0, 0.1, 0.25, 0.5, 0.7, 0.777, 1.0, 1.5, 1.999, 2.0, 2.5, 5.25]

        for time in sampleTimes {
            let expected = legacyPose(skeleton: skeleton, clip: clip, at: time)
            let actual = compiledPose(
                skeleton: skeleton, clip: clip, compiled: compiled,
                sampler: &sampler, pose: &pose, at: time
            )
            assertPosesEqual(expected, actual, "Pose mismatch at t=\(time)")
        }
    }

    func testCompiledPathMatchesLegacyPathOverSequentialPlayback() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        // Simulates real playback across three loops at ~90 Hz so cursor
        // hints are exercised, including across the wrap.
        var time: Float = 0
        let deltaTime: Float = 1.0 / 90.0
        while time < clip.duration * 3 {
            let expected = legacyPose(skeleton: skeleton, clip: clip, at: time)
            let actual = compiledPose(
                skeleton: skeleton, clip: clip, compiled: compiled,
                sampler: &sampler, pose: &pose, at: time
            )
            assertPosesEqual(expected, actual, "Pose mismatch during playback at t=\(time)")
            time += deltaTime
        }
    }

    func testCompiledPathMatchesLegacyPathWithClipSpeed() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        clip.speed = 1.75
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        for time in stride(from: Float(0), through: 4.0, by: 0.13) {
            let expected = legacyPose(skeleton: skeleton, clip: clip, at: time)
            let actual = compiledPose(
                skeleton: skeleton, clip: clip, compiled: compiled,
                sampler: &sampler, pose: &pose, at: time
            )
            assertPosesEqual(expected, actual, "Pose mismatch with speed 1.75 at t=\(time)")
        }
    }

    // MARK: - Sampler correctness against hand-computed values

    func testTranslationInterpolationMidway() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        // Root translation keys: t=0.5 → (0, 1.1, 0.5), t=1.5 → (0, 0.95, 1.4).
        // Midpoint t=1.0 lerps to (0, 1.025, 0.95).
        sampler.sample(compiled, time: 1.0, duration: clip.duration, speed: 1, into: &pose)
        let translation = pose.translations[0]
        XCTAssertEqual(translation.x, 0.0, accuracy: 1e-5)
        XCTAssertEqual(translation.y, 1.025, accuracy: 1e-5)
        XCTAssertEqual(translation.z, 0.95, accuracy: 1e-5)
    }

    func testExactKeyframeHit() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        sampler.sample(compiled, time: 0.5, duration: clip.duration, speed: 1, into: &pose)
        let translation = pose.translations[0]
        XCTAssertEqual(translation.y, 1.1, accuracy: 1e-5)
        XCTAssertEqual(translation.z, 0.5, accuracy: 1e-5)
    }

    func testRotationOnlyChannelKeepsRestTranslation() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        sampler.sample(compiled, time: 0.35, duration: clip.duration, speed: 1, into: &pose)

        // Hips channel is rotation-only; its rest translation must survive.
        let hipsRest = skeleton.restTransform[1]
        XCTAssertEqual(pose.translations[1].x, hipsRest.columns.3.x, accuracy: 1e-6)
        XCTAssertEqual(pose.translations[1].y, hipsRest.columns.3.y, accuracy: 1e-6)
        XCTAssertEqual(pose.translations[1].z, hipsRest.columns.3.z, accuracy: 1e-6)
    }

    func testUnanimatedJointKeepsRestPose() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        sampler.sample(compiled, time: 1.234, duration: clip.duration, speed: 1, into: &pose)

        // Leg has no channel: its decomposed rest pose must come through.
        XCTAssertFalse(compiled.channels[3].animated)
        let legRest = skeleton.restTransform[3]
        XCTAssertEqual(pose.translations[3].x, legRest.columns.3.x, accuracy: 1e-6)
        XCTAssertEqual(pose.translations[3].y, legRest.columns.3.y, accuracy: 1e-6)
        XCTAssertEqual(pose.translations[3].z, legRest.columns.3.z, accuracy: 1e-6)
    }

    func testWrapDoesNotSnap() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        // Sampling just past the duration must equal sampling the wrapped time.
        var wrappedSampler = ClipSampler()
        var wrappedPose = PoseBuffer()
        sampler.sample(compiled, time: 2.25, duration: clip.duration, speed: 1, into: &pose)
        wrappedSampler.sample(compiled, time: 0.25, duration: clip.duration, speed: 1, into: &wrappedPose)

        for jointIndex in 0 ..< compiled.jointCount {
            XCTAssertEqual(
                simd_length(pose.translations[jointIndex] - wrappedPose.translations[jointIndex]),
                0, accuracy: 1e-5,
                "Translation mismatch across wrap at joint \(jointIndex)"
            )
        }
    }

    // MARK: - Cursor behavior

    func testCursorHintsMatchFreshSamplerResults() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var warmSampler = ClipSampler()
        var warmPose = PoseBuffer()

        var time: Float = 0
        while time < clip.duration * 2 {
            warmSampler.sample(compiled, time: time, duration: clip.duration, speed: 1, into: &warmPose)

            var freshSampler = ClipSampler()
            var freshPose = PoseBuffer()
            freshSampler.sample(compiled, time: time, duration: clip.duration, speed: 1, into: &freshPose)

            for jointIndex in 0 ..< compiled.jointCount {
                XCTAssertEqual(
                    simd_length(warmPose.translations[jointIndex] - freshPose.translations[jointIndex]),
                    0, accuracy: 1e-6,
                    "Warm cursor diverged from fresh sampler at t=\(time), joint \(jointIndex)"
                )
            }
            time += 0.037
        }
    }

    func testSwitchingClipsResetsCursorsCorrectly() {
        let skeleton = makeSkeleton()
        let walkClip = makeWalkClip()
        let idleClip = makeIdleClip()
        let compiledWalk = CompiledAnimationClip(clip: walkClip, skeleton: skeleton)
        let compiledIdle = CompiledAnimationClip(clip: idleClip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        // Advance well into the walk clip, then switch to idle.
        sampler.sample(compiledWalk, time: 1.8, duration: walkClip.duration, speed: 1, into: &pose)
        sampler.sample(compiledIdle, time: 0.3, duration: idleClip.duration, speed: 1, into: &pose)

        var freshSampler = ClipSampler()
        var freshPose = PoseBuffer()
        freshSampler.sample(compiledIdle, time: 0.3, duration: idleClip.duration, speed: 1, into: &freshPose)

        for jointIndex in 0 ..< compiledIdle.jointCount {
            let delta = simd_length(pose.rotations[jointIndex].vector - freshPose.rotations[jointIndex].vector)
            XCTAssertEqual(delta, 0, accuracy: 1e-6, "Clip switch produced stale sampling at joint \(jointIndex)")
        }
    }

    // MARK: - Steady-state storage behavior

    func testPoseBufferStorageIsStableAcrossSamples() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        sampler.sample(compiled, time: 0, duration: clip.duration, speed: 1, into: &pose)
        let warmedCount = pose.jointCount

        let warmBase = pose.translations.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }

        var time: Float = 0.011
        while time < clip.duration * 2 {
            sampler.sample(compiled, time: time, duration: clip.duration, speed: 1, into: &pose)
            time += 0.011
        }

        let steadyBase = pose.translations.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress!) }
        XCTAssertEqual(steadyBase, warmBase, "PoseBuffer storage was reallocated during steady-state sampling")
        XCTAssertEqual(pose.jointCount, warmedCount)
    }

    func testSamplingPerformance() {
        let skeleton = makeSkeleton()
        let clip = makeWalkClip()
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        var sampler = ClipSampler()
        var pose = PoseBuffer()

        measure {
            var time: Float = 0
            for _ in 0 ..< 10000 {
                sampler.sample(compiled, time: time, duration: clip.duration, speed: 1, into: &pose)
                skeleton.updateWorldPose(from: pose, localScales: compiled.restScales)
                time += 1.0 / 90.0
            }
        }
    }
}
