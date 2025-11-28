//
//  USCCameraScriptTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class USCCameraScriptTests: XCTestCase {
    override func setUp() {
        super.setUp()
        initScriptingSystem() // should register cameraMoveTo
    }

    override func tearDown() {
        destroyAllEntities()
        super.tearDown()
    }

    func testCameraMoveTo_Scripted() {
        // 1. Create a camera entity
        let cameraEntity = createEntity()
        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity

        // Sanity: initial camera position is not the target
        guard let initialCam = scene.get(component: CameraComponent.self,
                                         for: cameraEntity)
        else {
            return XCTFail("CameraComponent should exist on game camera")
        }
        XCTAssertNotEqual(initialCam.localPosition,
                          simd_float3(1.0, 2.0, 3.0))

        // 2. Build a USC script that calls cameraMoveTo
        let script = buildScript(name: "cameraMoveToScript") { s in
            s.onUpdate()
                // user-friendly variable
                .setVariable("targetPos", to: Vec3(x: 1.0, y: 2.0, z: 3.0))
                // map into the action arg key
                .setVariable(ScriptArgKey.position.rawValue,
                             fromVariable: "targetPos")
                // invoke the engine camera action
                .callAction(.cameraMoveTo,
                            args: [.position])
        }

        // 3. Create context and interpreter
        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()

        // 4. Execute just the OnUpdate event
        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // 5. Assert that the camera actually moved
        guard let camAfter = scene.get(component: CameraComponent.self,
                                       for: cameraEntity)
        else {
            return XCTFail("CameraComponent should still exist")
        }

        let expected = simd_float3(1.0, 2.0, 3.0)
        XCTAssertEqual(camAfter.localPosition.x, expected.x, accuracy: 1e-5)
        XCTAssertEqual(camAfter.localPosition.y, expected.y, accuracy: 1e-5)
        XCTAssertEqual(camAfter.localPosition.z, expected.z, accuracy: 1e-5)
    }

    func testCameraLookAt_Scripted() {
        let cameraEntity = createEntity()
        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity

        // Different from default so we can see a change
        let eye = Vec3(x: 1.0, y: 2.0, z: 3.0)
        let target = Vec3(x: 0.0, y: 0.0, z: 0.0)
        let up = Vec3.up

        let script = buildScript(name: "cameraLookAtScript") { s in
            s.onUpdate()
                .cameraLookAt(eye: Vec3(x: 1.0, y: 2.0, z: 3.0),
                              target: Vec3(x: 0.0, y: 0.0, z: 0.0),
                              up: Vec3.up)
        }

        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard let cam = scene.get(component: CameraComponent.self,
                                  for: cameraEntity)
        else {
            return XCTFail("CameraComponent should exist")
        }

        let expectedEye = simd_float3(eye.x, eye.y, eye.z)
        let expectedTarget = simd_float3(target.x, target.y, target.z)

        XCTAssertEqual(cam.eye.x, expectedEye.x, accuracy: 1e-5)
        XCTAssertEqual(cam.eye.y, expectedEye.y, accuracy: 1e-5)
        XCTAssertEqual(cam.eye.z, expectedEye.z, accuracy: 1e-5)

        XCTAssertEqual(cam.target.x, expectedTarget.x, accuracy: 1e-5)
        XCTAssertEqual(cam.target.y, expectedTarget.y, accuracy: 1e-5)
        XCTAssertEqual(cam.target.z, expectedTarget.z, accuracy: 1e-5)

        // localPosition should also match eye
        XCTAssertEqual(cam.localPosition.x, expectedEye.x, accuracy: 1e-5)
        XCTAssertEqual(cam.localPosition.y, expectedEye.y, accuracy: 1e-5)
        XCTAssertEqual(cam.localPosition.z, expectedEye.z, accuracy: 1e-5)
    }

    func testCameraMoveWithInput_Scripted() {
        let cameraEntity = createEntity()

        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity

        guard let camBefore = scene.get(component: CameraComponent.self,
                                        for: cameraEntity)
        else {
            return XCTFail("CameraComponent should exist")
        }
        let initialPos = camBefore.localPosition

        let script = buildScript(name: "cameraMoveForwardScript") { s in
            s.onUpdate()
                .setVariable("speed", to: 5.0)
                .setVariable("dt", to: 0.5)
                .setVariable("wPressed", to: true)
                .setVariable("aPressed", to: false)
                .setVariable("sPressed", to: false)
                .setVariable("dPressed", to: false)
                .setVariable("qPressed", to: false)
                .setVariable("ePressed", to: false)
                .cameraMoveWithInput(speedVar: "speed",
                                     deltaTimeVar: "dt",
                                     wVar: "wPressed",
                                     aVar: "aPressed",
                                     sVar: "sPressed",
                                     dVar: "dPressed",
                                     qVar: "qPressed",
                                     eVar: "ePressed")
        }

        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard let camAfter = scene.get(component: CameraComponent.self,
                                       for: cameraEntity)
        else {
            return XCTFail("CameraComponent should exist after move")
        }

        let newPos = camAfter.localPosition

        // At minimum, we expect some movement
        XCTAssertNotEqual(newPos.y, initialPos.y, accuracy: 1e-5)
        XCTAssertNotEqual(newPos.z, initialPos.z, accuracy: 1e-5,
                          "Camera should have moved along its axes when W is pressed")
    }
}
