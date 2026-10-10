//
//  AnimationClipJointMismatchTests.swift
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

/// Coverage for GitHub issue #1318: a clip whose channels resolve against
/// zero joints on the bound skeleton (e.g. a namespace prefix mismatch like
/// "skel:LeftArm" vs "LeftArm", or a differing parent-chain path) used to
/// register and play silently — `currentAnimation` set, `currentTime`
/// advancing, every joint sampling its rest pose, with no diagnostic at all.
/// `warnIfClipHasNoMatchingJoints` now reports `.animationClipNoMatchingJoints`
/// whenever such a clip is selected for playback.
@MainActor
final class AnimationClipJointMismatchTests: XCTestCase {
    #if canImport(AppKit)
        private final class CapturingSink: LoggerSink {
            private let expectation: XCTestExpectation
            private let predicate: (String) -> Bool
            private(set) var messages: [String] = []

            init(expectation: XCTestExpectation, predicate: @escaping (String) -> Bool) {
                self.expectation = expectation
                self.predicate = predicate
            }

            func didLog(_ event: LogEvent) {
                guard event.level == .error else { return }
                messages.append(event.message)
                if predicate(event.message) {
                    expectation.fulfill()
                }
            }
        }
    #endif

    private func makeEntity(jointPath: String) -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)

        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: [jointPath],
            parentIndices: [nil],
            bindTransforms: [.identity],
            restTransforms: [.identity]
        )
        scene.get(component: SkeletonComponent.self, for: entityId)?.skeleton =
            Skeleton(runtimeSkeleton: runtimeSkeleton)
        return entityId
    }

    private func makeRuntimeClip(name: String, jointPath: String) -> RuntimeAnimationClip {
        let channel = RuntimeAnimationChannel(
            jointPath: jointPath,
            translations: [.init(time: 0.0, value: simd_float3(0, 1, 0))]
        )
        return RuntimeAnimationClip(name: name, duration: 1.0, channels: [channel])
    }

    func testMismatchedNamespaceClipCompilesToZeroAnimatedChannels() throws {
        let runtimeSkeleton = RuntimeSkeleton(
            jointPaths: ["LeftArm"],
            parentIndices: [nil],
            bindTransforms: [.identity],
            restTransforms: [.identity]
        )
        let skeleton = try XCTUnwrap(Skeleton(runtimeSkeleton: runtimeSkeleton))
        let clip = AnimationClip(runtimeClip: makeRuntimeClip(name: "wave", jointPath: "skel:LeftArm"))

        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)

        XCTAssertFalse(compiled.channels.contains(where: \.animated),
                       "A namespace-prefixed clip path must not resolve against the bare skeleton path")
    }

    #if canImport(AppKit)
        func testChangeAnimationReportsClipWithNoMatchingJoints() throws {
            resetEngineTestState()
            let entityId = makeEntity(jointPath: "LeftArm")
            defer { destroyEntity(entityId: entityId) }

            let animationComponent = try XCTUnwrap(scene.get(component: AnimationComponent.self, for: entityId))
            _ = registerRuntimeAnimationClips(
                [makeRuntimeClip(name: "wave", jointPath: "skel:LeftArm")],
                preferredName: "wave",
                to: animationComponent
            )

            let expectation = expectation(description: "mismatch reported")
            let sink = CapturingSink(expectation: expectation) { message in
                message.contains("1089") && message.contains("wave")
            }
            Logger.addSink(sink)

            changeAnimation(entityId: entityId, name: "wave", transitionHalflife: 0)

            wait(for: [expectation], timeout: 2.0)

            // Diagnostic only: the clip still registers and plays.
            XCTAssertTrue(animationComponent.currentAnimation === animationComponent.animationClips["wave"])
        }

        func testChangeAnimationDoesNotReportMatchingClip() throws {
            resetEngineTestState()
            let entityId = makeEntity(jointPath: "LeftArm")
            defer { destroyEntity(entityId: entityId) }

            let animationComponent = try XCTUnwrap(scene.get(component: AnimationComponent.self, for: entityId))
            _ = registerRuntimeAnimationClips(
                [makeRuntimeClip(name: "wave", jointPath: "LeftArm")],
                preferredName: "wave",
                to: animationComponent
            )

            let unexpected = expectation(description: "no mismatch should be reported")
            unexpected.isInverted = true
            let sink = CapturingSink(expectation: unexpected) { message in
                message.contains("1089")
            }
            Logger.addSink(sink)

            changeAnimation(entityId: entityId, name: "wave", transitionHalflife: 0)

            wait(for: [unexpected], timeout: 0.5)
        }
    #endif
}
