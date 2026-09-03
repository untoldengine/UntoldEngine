//
//  AnimationTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class AnimationTests: BaseRenderSetup {
    private let samples: [(time: Float, name: String)] = [
        (0.00, "pose_t000"),
        (0.10, "pose_t010"),
        (0.20, "pose_t020"),
        (0.30, "pose_t030"),
        (0.40, "pose_t040"),
    ]

    func test_generateReferenceKeyframes() throws {
        guard ProcessInfo.processInfo.environment["UNTOLD_REGENERATE_REFERENCES"] == "1" else {
            throw XCTSkip("Reference generation is opt-in. Set UNTOLD_REGENERATE_REFERENCES=1 to run.")
        }
        try runSamples { tex, name in
            self.testGenerateRenderTarget(targetName: name, texture: tex)
        }
    }

    /// Save all test poses first, then PSNR from files
    func test_referenceKeyframes() throws {
        // Phase A: render & save all
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldKeyframes-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        var saved: [(name: String, url: URL)] = []

        try runSamples { tex, name in
            if let url = self.saveTestKeyframePNG(targetName: name, texture: tex, to: outDir) {
                saved.append((name, url))
            } else {
                XCTFail("Failed to save \(name) test PNG")
            }
        }

        // Phase B: PSNR using saved files (no GPU reads now)
        for (name, url) in saved {
            XCTContext.runActivity(named: "PSNR \(name)") { _ in
                self.psnrCompareSaved(referenceName: name, testURL: url)
            }
        }
    }

    func test_animationPlaybackSpeedScalesDeltaTime() {
        guard let player = findEntity(name: "player") else {
            XCTFail("Missing player entity")
            return
        }

        // redplayer is hierarchical: AnimationComponent lives on the resolved child entity.
        let animEntityId = resolveEntityWithAnimationComponent(entityId: player) ?? player
        guard let animationComponent = scene.get(component: AnimationComponent.self, for: animEntityId) else {
            XCTFail("Missing AnimationComponent for player entity")
            return
        }

        animationComponent.currentTime = 0.0
        setAnimationPlaybackSpeed(entityId: player, speed: 2.0)
        AnimationSystem.shared.update(0.25)

        XCTAssertEqual(animationComponent.currentTime, 0.5, accuracy: 0.0001)
    }

    func test_rotationOnlyClipPreservesRestTranslation() throws {
        let restTransform = matrix4x4Translation(0.25, 1.5, -0.75)

        let runtimeClip = RuntimeAnimationClip(
            name: "rotationOnly",
            duration: 1.0,
            channels: [
                RuntimeAnimationChannel(
                    jointPath: "/Hips/Spine",
                    rotations: [
                        RuntimeRotationKeyframe(time: 0.0, value: SIMD4<Float>(0.0, 0.0, 0.0, 1.0)),
                    ]
                ),
            ]
        )
        let clip = AnimationClip(runtimeClip: runtimeClip)
        let pose = try XCTUnwrap(clip.getPose(at: 0.0, jointPath: "/Hips/Spine", fallback: restTransform))

        XCTAssertEqual(pose.columns.3.x, restTransform.columns.3.x, accuracy: 0.0001)
        XCTAssertEqual(pose.columns.3.y, restTransform.columns.3.y, accuracy: 0.0001)
        XCTAssertEqual(pose.columns.3.z, restTransform.columns.3.z, accuracy: 0.0001)
    }

    func test_animationPosePreservesRestScale() throws {
        let restScale = SIMD3<Float>(0.01, 0.02, 0.03)
        let restTransform = matrix4x4Translation(0.25, 1.5, -0.75) * matrix4x4Scale(restScale.x, restScale.y, restScale.z)
        let runtimeClip = RuntimeAnimationClip(
            name: "rotationWithScaledRestPose",
            duration: 1.0,
            channels: [
                RuntimeAnimationChannel(
                    jointPath: "/Hips",
                    translations: [
                        RuntimeTranslationKeyframe(time: 0.0, value: SIMD3<Float>(0.5, 1.0, 1.5)),
                    ],
                    rotations: [
                        RuntimeRotationKeyframe(time: 0.0, value: SIMD4<Float>(0.0, 0.0, 0.0, 1.0)),
                    ]
                ),
            ]
        )

        let clip = AnimationClip(runtimeClip: runtimeClip)
        let pose = try XCTUnwrap(clip.getPose(at: 0.0, jointPath: "/Hips", fallback: restTransform))

        XCTAssertEqual(simd_length(SIMD3<Float>(pose.columns.0.x, pose.columns.0.y, pose.columns.0.z)), restScale.x, accuracy: 0.0001)
        XCTAssertEqual(simd_length(SIMD3<Float>(pose.columns.1.x, pose.columns.1.y, pose.columns.1.z)), restScale.y, accuracy: 0.0001)
        XCTAssertEqual(simd_length(SIMD3<Float>(pose.columns.2.x, pose.columns.2.y, pose.columns.2.z)), restScale.z, accuracy: 0.0001)
    }

    private func runSamples(save: (_ tex: MTLTexture, _ name: String) -> Void) throws {
        resetAnimationPlaybackState()

        var last: Float = 0
        for s in samples {
            let dt = s.time - last
            AnimationSystem.shared.update(dt)
            renderer.getConfiguration().updateRenderingSystemCallback(renderer.metalView)
            guard let cb = renderInfo.lastCommandBuffer else {
                XCTFail("Missing last command buffer"); return
            }
            cb.waitUntilCompleted()

            guard let colorTex = textureResources.sceneCompositeTexture else {
                XCTFail("No scene composite texture")
                return
            }

            save(colorTex, s.name)
            last = s.time
        }
    }

    private func resetAnimationPlaybackState() {
        guard let player = findEntity(name: "player") else {
            XCTFail("Missing player entity")
            return
        }

        // redplayer is hierarchical: AnimationComponent lives on the resolved child entity.
        let animEntityId = resolveEntityWithAnimationComponent(entityId: player) ?? player
        guard let animationComponent = scene.get(component: AnimationComponent.self, for: animEntityId) else {
            XCTFail("Missing AnimationComponent for player entity")
            return
        }

        setAnimationPlaybackSpeed(entityId: player, speed: 1.0)
        animationComponent.currentTime = 0.0
        animationComponent.pause = false
        changeAnimation(entityId: player, name: "running")
        currentGlobalTime = 0.0
    }

    override func initializeAssets() {
        // Reference keyframe PNGs were captured against the grid background; pin it explicitly
        // now that the procedural sky is the default non-IBL background, so this test keeps
        // validating skeletal animation poses rather than sky rendering.
        renderSkyBackground = false
        cameraLookAt(entityId: findGameCamera(), eye: simd_float3(0.0, 3.0, 7.0), target: simd_float3(0.0, 0.0, 0.0), up: simd_float3(0.0, 1.0, 0.0))
        ambientIntensity = 0.4
        let sunEntity: EntityID = createEntity()
        createDirLight(entityId: sunEntity)
        // Player entity is created here; actual async load happens in setUp override below.
        let player = createEntity()
        setEntityName(entityId: player, name: "player")
    }

    override func setUp() async throws {
        try await super.setUp()
        // Load the actual redplayer.untold asset so SkeletonComponent and AnimationComponent
        // are registered. This must run in an async context so we can await completion.
        guard let player = findEntity(name: "player") else { return }
        let exp = XCTestExpectation(description: "redplayer loaded")
        setEntityMeshAsync(entityId: player, filename: "redplayer", withExtension: "untold") { _ in
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 10)
        setEntityAnimations(entityId: player, filename: "running", withExtension: "untold", name: "running")
        changeAnimation(entityId: player, name: "running")
        setVisibleEntities()
    }
}
