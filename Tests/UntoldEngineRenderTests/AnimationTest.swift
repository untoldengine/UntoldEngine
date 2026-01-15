//
//  AnimationTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

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
        try runSamples { tex, name in
            self.testGenerateRenderTarget(targetName: name, texture: tex)
        }
    }

    // Save all test poses first, then PSNR from files
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

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: player) else {
            XCTFail("Missing AnimationComponent for player entity")
            return
        }

        animationComponent.currentTime = 0.0
        setAnimationPlaybackSpeed(entityId: player, speed: 2.0)
        AnimationSystem.shared.update(0.25)

        XCTAssertEqual(animationComponent.currentTime, 0.5, accuracy: 0.0001)
    }

    private func runSamples(save: (_ tex: MTLTexture, _ name: String) -> Void) throws {
        var last: Float = 0
        for s in samples {
            let dt = s.time - last
            AnimationSystem.shared.update(dt)
            renderer.getConfiguration().updateRenderingSystemCallback(renderer.metalView)
            guard let cb = renderInfo.lastCommandBuffer else {
                XCTFail("Missing last command buffer"); return
            }
            cb.waitUntilCompleted()

            guard let colorTex = renderInfo
                .offscreenRenderPassDescriptor
                .colorAttachments[Int(colorTarget.rawValue)]
                .texture
            else { XCTFail("No offscreen color target"); return }

            save(colorTex, s.name)
            last = s.time
        }
    }

    override func initializeAssets() {
        cameraLookAt(entityId: findGameCamera(), eye: simd_float3(0.0, 3.0, 7.0), target: simd_float3(0.0, 0.0, 0.0), up: simd_float3(0.0, 1.0, 0.0))

        // Player (animated, named for lookup)
        let player = createEntity()
        setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdz", flip: false)
        setEntityName(entityId: player, name: "player")
        rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
        setEntityAnimations(entityId: player, filename: "running", withExtension: "usdz", name: "running")

        changeAnimation(entityId: player, name: "running")

        ambientIntensity = 0.4

        let sunEntity: EntityID = createEntity()

        createDirLight(entityId: sunEntity)
    }
}
