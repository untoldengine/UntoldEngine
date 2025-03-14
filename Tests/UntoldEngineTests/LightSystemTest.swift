//
//  LightSystemTest.swift
//
//
//  Created by Harold Serrano on 3/14/25.
//

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class LightSystemTest: XCTestCase {
    var entityId: EntityID!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()

        entityId = createEntity()
    }

    override func tearDown() {
        destroyEntity(entityId: entityId)
        super.tearDown()
    }

    // MARK: - Light Tests

    func testCreateLight() {
        createLight(entityId: entityId, lightType: .directional)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")
    }

    func testCreateDirectionalLight() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        XCTAssertEqual(lightComponent.lightType, .directional, "Light should be directional")
    }

    func testCreatePointLight() {
        createLight(entityId: entityId, lightType: .point)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        XCTAssertEqual(lightComponent.lightType, .point, "Light should be point")
    }

    func testGetLightParameters() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        rotateTo(entityId: entityId, pitch: 1.0, yaw: -1.0, roll: 1.0)

        lightComponent.color = .one
        lightComponent.attenuation = .one
        lightComponent.radius = 1.0
        lightComponent.intensity = 1.0

        let lightParameters: LightParameters = getLightParameters()

        let orientationEuler = getLocalOrientationEuler(entityId: entityId)
        let orientation = simd_float3(orientationEuler.pitch, orientationEuler.yaw, orientationEuler.roll)

        XCTAssertEqual(lightParameters.color, .one, "color should be all 1's")
        XCTAssertEqual(lightParameters.intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(lightParameters.direction.x, orientation.x, "Pitch should match")
        XCTAssertEqual(lightParameters.direction.y, orientation.y, "Yaw should match")
        XCTAssertEqual(lightParameters.direction.z, orientation.z, "Roll should match")
    }

    func testGetLightColor() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.color = .one

        XCTAssertEqual(lightComponent.color, .one, "color should be all 1's")
    }

    func testGetLightAttenuation() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.attenuation = .one

        XCTAssertEqual(lightComponent.attenuation, .one, "attenuation should be all 1's")
    }

    func testGetLightRadius() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.radius = 1.0

        XCTAssertEqual(lightComponent.radius, 1.0, "Radius should be 1")
    }

    func testGetLightIntensity() {
        createLight(entityId: entityId, lightType: .directional)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.intensity = 1.0

        XCTAssertEqual(lightComponent.intensity, 1.0, "Intensity should be all 1's")
    }

    func testGetPointLightCount() {
        createLight(entityId: entityId, lightType: .point)
        createLight(entityId: createEntity(), lightType: .point)
        createLight(entityId: createEntity(), lightType: .directional)

        XCTAssertEqual(getPointLightCount(), 2, "There should be two point lights")
    }
}
