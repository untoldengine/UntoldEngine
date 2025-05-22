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
    var renderer: UntoldRenderer!
    var window: NSWindow!

    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        let windowWidth = 1280
        let windowHeight = 720
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)

        window.title = "Test Window"

        // Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

        // Initialize resources
        self.renderer.initResources()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Light Tests

    func testDirectionalLight() {
        let entityId: EntityID = createEntity()

        createDirLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self), "Should have a Directional Light component")

        destroyEntity(entityId: entityId)
    }

    func testPointLight() {
        let entityId: EntityID = createEntity()

        createPointLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: PointLightComponent.self), "Should have a Point Light component")

        destroyEntity(entityId: entityId)
    }

    func testSpotLight() {
        let entityId: EntityID = createEntity()

        createSpotLight(entityId: entityId)

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LightComponent.self), "Should have a Light component")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: SpotLightComponent.self), "Should have a Spot Light component")

        destroyEntity(entityId: entityId)
    }

    func testGetDirLightParameters() {
        let entityId: EntityID = createEntity()

        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: DirectionalLightComponent.self, for: entityId) != nil else {
            handleError(.noDirLightComponent, entityId)
            return
        }

        let lightParameters: LightParameters = getDirectionalLightParameters()

        XCTAssertEqual(lightParameters.color, .one, "color should be all 1's")
        XCTAssertEqual(lightParameters.intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(lightParameters.direction.x, 0.5, "Rotation about X axis should match")
        XCTAssertEqual(lightParameters.direction.y, 0.70710677, "Rotation about Y axis should match")
        XCTAssertEqual(lightParameters.direction.z, 0.5, accuracy: 0.001, "Rotation about Z axis should match")

        destroyEntity(entityId: entityId)
    }

    func testPointLightParameters() {
        let entityId: EntityID = createEntity()

        createPointLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: PointLightComponent.self, for: entityId) != nil else {
            handleError(.noPointLightComponent, entityId)
            return
        }

        let pointLightParameter: [PointLight] = getPointLights()

        XCTAssertEqual(pointLightParameter[0].intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.x, 1.0, "constant should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.y, 0.05, "linear should be 1")
        XCTAssertEqual(pointLightParameter[0].attenuation.z, 0.5, "quadratic should be 1")
        XCTAssertEqual(pointLightParameter[0].radius, 1.0, "radius should be 1")

        destroyEntity(entityId: entityId)
    }

    func testSpotPointLightParameters() {
        let entityId: EntityID = createEntity()

        createSpotLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        guard scene.get(component: SpotLightComponent.self, for: entityId) != nil else {
            handleError(.noSpotLightComponent, entityId)
            return
        }

        let spotLightParameter: [SpotLight] = getSpotLights()

        XCTAssertEqual(spotLightParameter[0].intensity, 1.0, "intensity should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.x, 1.0, "constant should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.y, 0.05, "linear should be 1")
        XCTAssertEqual(spotLightParameter[0].attenuation.z, 0.5, "quadratic should be 1")
        XCTAssertEqual(spotLightParameter[0].outerCone, 0.523, accuracy: 0.001, "outer cone should be 1")
        XCTAssertEqual(spotLightParameter[0].innerCone, 0.427, accuracy: 0.001, "inner cone should be 1")

        XCTAssertEqual(spotLightParameter[0].direction.x, 0.0, "Rotation about X axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.y, -1.0, "Rotation about Y axis should match")
        XCTAssertEqual(spotLightParameter[0].direction.z, 0.0, accuracy: 0.001, "Rotation about Z axis should match")

        destroyEntity(entityId: entityId)
    }

    func testGetPointLightCount() {
        let entityId0: EntityID = createEntity()
        let entityId1: EntityID = createEntity()

        createPointLight(entityId: entityId0)
        createPointLight(entityId: entityId1)

        XCTAssertEqual(getPointLightCount(), 2, "There should be two point lights")

        destroyEntity(entityId: entityId0)
        destroyEntity(entityId: entityId1)
    }

    func testGetSpotLightCount() {
        let entityId0: EntityID = createEntity()
        let entityId1: EntityID = createEntity()

        createSpotLight(entityId: entityId0)
        createSpotLight(entityId: entityId1)

        XCTAssertEqual(getSpotLightCount(), 2, "There should be two point lights")

        destroyEntity(entityId: entityId0)
        destroyEntity(entityId: entityId1)
    }

    func testGetLightColor() {
        let entityId: EntityID = createEntity()
        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.color = .one

        XCTAssertEqual(lightComponent.color, .one, "color should be all 1's")
        destroyEntity(entityId: entityId)
    }

    func testGetLightIntensity() {
        let entityId: EntityID = createEntity()
        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent, entityId)
            return
        }

        lightComponent.intensity = 1.0

        XCTAssertEqual(lightComponent.intensity, 1.0, "Intensity should be all 1's")
        destroyEntity(entityId: entityId)
    }
}
