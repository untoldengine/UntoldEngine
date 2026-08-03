//
//  SceneBuilderNodesTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Covers the scene builder DSL nodes that need the renderer: primitive nodes
/// (procedural meshes + material modifiers) and light nodes.
final class SceneBuilderNodesTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
        destroyAllEntities()
    }

    override func initializeAssets() {}

    // MARK: - Primitive nodes

    func testCubeNodeCreatesMeshSynchronously() throws {
        let cube = CubeNode(size: 1.0)

        let renderComponent = try XCTUnwrap(
            scene.get(component: RenderComponent.self, for: cube.entityID),
            "Primitive meshes are generated synchronously, so the render component must exist right after init"
        )
        XCTAssertFalse(renderComponent.mesh.isEmpty)
        XCTAssertEqual(renderComponent.mesh.first?.assetName, "Cube")
        XCTAssertEqual(getEntityName(entityId: cube.entityID), "Cube")
    }

    func testPrimitiveNodesCreateExpectedMeshes() {
        let primitives: [(node: any NodeProtocol, expectedName: String)] = [
            (CubeNode(), "Cube"),
            (SphereNode(), "Sphere"),
            (PlaneNode(), "Plane"),
            (CylinderNode(), "Cylinder"),
            (ConeNode(), "Cone"),
        ]

        for (node, expectedName) in primitives {
            let renderComponent = scene.get(component: RenderComponent.self, for: node.entityID)
            XCTAssertNotNil(renderComponent, "\(expectedName)Node should register a render component")
            XCTAssertEqual(renderComponent?.mesh.isEmpty, false, "\(expectedName)Node should have a mesh")
            XCTAssertEqual(getEntityName(entityId: node.entityID), expectedName)
        }
    }

    func testPrimitiveNodeUsesProvidedName() {
        let cube = CubeNode(name: "Crate")
        XCTAssertEqual(getEntityName(entityId: cube.entityID), "Crate")
    }

    func testPrimitiveNodeWrapsExistingEntity() {
        let entity = createEntity()
        let cube = CubeNode(entityID: entity)
        XCTAssertEqual(cube.entityID, entity)
        XCTAssertNotNil(scene.get(component: RenderComponent.self, for: entity))
    }

    func testMaterialModifiersApplyImmediately() {
        let cube = CubeNode()
            .baseColor(1.0, 0.5, 0.0)
            .roughness(0.3)
            .metallic(0.8)
            .emissive(0.25, 0.5, 1.0)

        let baseColor = getMaterialBaseColor(entityId: cube.entityID)
        XCTAssertEqual(baseColor.x, 1.0, accuracy: 0.02)
        XCTAssertEqual(baseColor.y, 0.5, accuracy: 0.02)
        XCTAssertEqual(baseColor.z, 0.0, accuracy: 0.02)
        XCTAssertEqual(baseColor.w, 1.0, accuracy: 0.02)

        XCTAssertEqual(getMaterialRoughness(entityId: cube.entityID), 0.3, accuracy: 0.001)
        XCTAssertEqual(getMaterialMetallic(entityId: cube.entityID), 0.8, accuracy: 0.001)
        XCTAssertEqual(getMaterialEmmissive(entityId: cube.entityID), simd_float3(0.25, 0.5, 1.0))
    }

    func testMaterialDataAppliesAllScalarValues() {
        let sphere = SphereNode().materialData(
            roughness: 0.4,
            metallic: 0.6,
            emissive: (0.1, 0.2, 0.3),
            baseColor: (0.9, 0.1, 0.2, 1.0)
        )

        let baseColor = getMaterialBaseColor(entityId: sphere.entityID)
        XCTAssertEqual(baseColor.x, 0.9, accuracy: 0.02)
        XCTAssertEqual(baseColor.y, 0.1, accuracy: 0.02)
        XCTAssertEqual(baseColor.z, 0.2, accuracy: 0.02)

        XCTAssertEqual(getMaterialRoughness(entityId: sphere.entityID), 0.4, accuracy: 0.001)
        XCTAssertEqual(getMaterialMetallic(entityId: sphere.entityID), 0.6, accuracy: 0.001)
        XCTAssertEqual(getMaterialEmmissive(entityId: sphere.entityID), simd_float3(0.1, 0.2, 0.3))
    }

    func testPrimitiveNodeParentsChildContent() {
        let child = SphereNode(name: "moon")
        let parent = CubeNode { child }

        XCTAssertEqual(parent.subNodes.count, 1)
        XCTAssertEqual(getEntityParent(entityId: child.entityID), parent.entityID)
    }

    func testTranslateToPositionsPrimitiveAbsolutely() {
        let cube = CubeNode()

        _ = cube.translateTo(x: 2, y: 3, z: 4)
        _ = cube.translateTo(x: 2, y: 3, z: 4)

        XCTAssertEqual(getLocalPosition(entityId: cube.entityID), simd_float3(2, 3, 4))
    }

    // MARK: - Light nodes

    func testPointLightNodeCreatesComponents() {
        let light = PointLightNode()

        XCTAssertTrue(hasComponent(entityId: light.entityID, componentType: LightComponent.self))
        XCTAssertTrue(hasComponent(entityId: light.entityID, componentType: PointLightComponent.self))
        XCTAssertEqual(getEntityName(entityId: light.entityID), "Point Light")
    }

    func testPointLightNodeModifiers() {
        let light = PointLightNode()
            .color(0.2, 0.9, 0.3)
            .intensity(10)
            .radius(0.5)
            .falloff(0.8)
            .attenuation(constant: 1, linear: 0.5, quadratic: 1.2)

        XCTAssertEqual(getLightColor(entityId: light.entityID), simd_float3(0.2, 0.9, 0.3))
        XCTAssertEqual(getLightIntensity(entityId: light.entityID), 10)
        XCTAssertEqual(getLightRadius(entityId: light.entityID), 0.5)
        XCTAssertEqual(getLightFalloff(entityId: light.entityID), 0.8)
        XCTAssertEqual(getLightAttenuation(entityId: light.entityID), simd_float3(1, 0.5, 1.2))
    }

    func testDirectionalLightNodeBecomesActiveSun() {
        let first = DirectionalLightNode()
        XCTAssertEqual(LightingSystem.shared.activeDirectionalLight, first.entityID)

        let second = DirectionalLightNode()
        XCTAssertEqual(LightingSystem.shared.activeDirectionalLight, second.entityID,
                       "Declaring a DirectionalLightNode makes it the scene's active sun")
        XCTAssertEqual(getEntityName(entityId: second.entityID), "Directional Light")
    }

    func testSpotLightNodeModifiers() {
        let light = SpotLightNode()
            .coneAngle(30)
            .radius(0.4)
            .intensity(5)

        XCTAssertTrue(hasComponent(entityId: light.entityID, componentType: SpotLightComponent.self))
        XCTAssertEqual(getEntityName(entityId: light.entityID), "Spot Light")
        XCTAssertEqual(getLightConeAngle(entityId: light.entityID), 30)
        XCTAssertEqual(getLightRadius(entityId: light.entityID), 0.4)
        XCTAssertEqual(getLightIntensity(entityId: light.entityID), 5)
    }

    func testLightNodeWrapsExistingLightEntity() {
        let entity = createEntity()
        createPointLight(entityId: entity)
        updateLightIntensity(entityId: entity, intensity: 7)

        let light = PointLightNode(entityID: entity)

        XCTAssertEqual(light.entityID, entity)
        XCTAssertEqual(getLightIntensity(entityId: entity), 7,
                       "Wrapping an existing point light must not recreate the component")
    }

}
