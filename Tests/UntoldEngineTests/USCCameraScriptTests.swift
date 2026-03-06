//
//  USCCameraScriptTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class USCCameraScriptTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetEngineTestState()
        initScriptingSystem()
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

        // 2. Build a USC script that calls cameraMoveTo instruction
        let script = buildScript(name: "cameraMoveToScript") { s in
            s.onUpdate()
                // user-friendly variable
                .setVariable("targetPos", to: simd_float3(1.0, 2.0, 3.0))
                // invoke the engine camera instruction
                .cameraMoveTo(.variableRef("targetPos"))
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
        let eye = simd_float3(1.0, 2.0, 3.0)
        let target = simd_float3(0.0, 0.0, 0.0)
        let up = simd_float3.up

        let script = buildScript(name: "cameraLookAtScript") { s in
            s.onUpdate()
                .cameraLookAt(eye: simd_float3(1.0, 2.0, 3.0),
                              target: simd_float3(0.0, 0.0, 0.0),
                              up: simd_float3.up)
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

    func testCameraMoveBy_Scripted() {
        let cameraEntity = createEntity()
        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity
        moveCameraTo(entityId: cameraEntity, 0, 0, 0)

        let script = buildScript(name: "cameraMoveByScript") { s in
            s.onUpdate()
                .setVariable("delta", to: simd_float3(1, 2, 3))
                .cameraMoveBy(.variableRef("delta"))
        }

        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard let cam = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            return XCTFail("CameraComponent should exist after moveBy")
        }
        XCTAssertEqual(cam.localPosition, simd_float3(1, 2, 3))
    }

    func testCameraRotate_Scripted() {
        let cameraEntity = createEntity()
        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity
        guard let camBefore = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            return XCTFail("CameraComponent should exist")
        }
        let initialRotation = camBefore.rotation

        let script = buildScript(name: "cameraRotateScript") { s in
            s.onUpdate()
                .setVariable("pitch", to: 0.1)
                .setVariable("yaw", to: -0.1)
                .setVariable("sensitivity", to: 1.0)
                .cameraRotate(pitch: .variableRef("pitch"),
                              yaw: .variableRef("yaw"),
                              sensitivity: .variableRef("sensitivity"))
        }

        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard let camAfter = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            return XCTFail("CameraComponent should exist after rotate")
        }
        XCTAssertNotEqual(camAfter.rotation.real, initialRotation.real, accuracy: 1e-4)
    }

    func testCameraFollow_Scripted() {
        let cameraEntity = createEntity()
        let target = createEntity()
        setEntityName(entityId: target, name: "Player")
        translateTo(entityId: target, position: simd_float3(5, 0, 0))

        createGameCamera(entityId: cameraEntity)
        CameraSystem.shared.activeCamera = cameraEntity
        moveCameraTo(entityId: cameraEntity, 0, 0, 0)

        let script = buildScript(name: "cameraFollowScript") { s in
            s.onUpdate()
                .setVariable("targetEntity", to: "Player")
                .setVariable("offset", to: simd_float3(0, 2, -4))
                .setVariable("smoothFactor", to: 0.0)
                .setVariable("deltaTime", to: 0.0)
                .cameraFollow(target: .variableRef("targetEntity"),
                              offset: .variableRef("offset"),
                              smoothFactor: .variableRef("smoothFactor"),
                              deltaTime: .variableRef("deltaTime"))
        }

        let context = USCContext(entityId: cameraEntity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard let cam = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            return XCTFail("CameraComponent should exist after follow")
        }
        XCTAssertEqual(cam.localPosition, simd_float3(5, 2, -4))
    }
}
