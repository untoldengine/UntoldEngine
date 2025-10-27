//
//  SceneSerializerTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// These unit tests were jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import ModelIO
import simd
@testable import UntoldEngine
import XCTest

final class SceneSerializerTests: XCTestCase {
    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        // Clean up any existing entities
        destroyAllEntities()
        Logger.logLevel = .none

        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Metal device is not available.")
            return
        }

        renderInfo.device = device
        vertexDescriptor.model = MDLVertexDescriptor()
    }

    override func tearDown() {
        // Clean up after each test
        destroyAllEntities()
        super.tearDown()
    }

    // MARK: - Basic Serialization Tests

    func testSerializeEmptyScene() {
        // Serialize an empty scene
        let sceneData = serializeScene()

        // Verify the scene data structure exists
        XCTAssertNotNil(sceneData, "Scene data should not be nil")
        XCTAssertEqual(sceneData.entities.count, 0, "Empty scene should have no entities")
    }

    func testSerializeSceneWithSingleEntity() {
        // Create a simple entity
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "TestEntity")
        registerTransformComponent(entityId: entityId)

        // Serialize the scene
        let sceneData = serializeScene()

        // Verify entity was serialized
        XCTAssertEqual(sceneData.entities.count, 1, "Scene should contain one entity")
        XCTAssertEqual(sceneData.entities[0].name, "TestEntity", "Entity name should match")
    }

    func testSerializeSceneWithTransformComponent() {
        // Create entity with transform
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "TransformEntity")
        registerTransformComponent(entityId: entityId)

        let position = simd_float3(1.0, 2.0, 3.0)
        let scale = simd_float3(2.0, 2.0, 2.0)

        translateTo(entityId: entityId, position: position)
        scaleTo(entityId: entityId, scale: scale)

        // Serialize
        let sceneData = serializeScene()

        // Verify transform data
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertEqual(sceneData.entities[0].position, position, "Position should match")
        XCTAssertEqual(sceneData.entities[0].scale, scale, "Scale should match")
        XCTAssertTrue(sceneData.entities[0].hasLocalTransformComponent, "Should have transform component")
    }

    // MARK: - Load Scene from File Tests

    func testLoadSceneFromValidJSON() {
        // Create a temporary scene file
        let tempDir = FileManager.default.temporaryDirectory
        let testSceneURL = tempDir.appendingPathComponent("test_scene.json")

        // Create simple scene data
        let sceneData = SceneData()
        let jsonData = try! JSONEncoder().encode(sceneData)
        try! jsonData.write(to: testSceneURL)

        // Load the scene
        let loadedScene = loadGameScene(from: testSceneURL)

        // Verify
        XCTAssertNotNil(loadedScene, "Should successfully load scene from valid JSON")

        // Cleanup
        try? FileManager.default.removeItem(at: testSceneURL)
    }

    func testLoadSceneFromInvalidPath() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/path/scene.json")

        // Attempt to load non-existent scene
        let loadedScene = loadGameScene(from: invalidURL)

        // Should return nil for invalid path
        XCTAssertNil(loadedScene, "Should return nil for non-existent file")
    }

    func testLoadSceneFromCorruptedJSON() {
        // Create a file with invalid JSON
        let tempDir = FileManager.default.temporaryDirectory
        let corruptedURL = tempDir.appendingPathComponent("corrupted_scene.json")

        let invalidJSON = "{ invalid json content }".data(using: .utf8)!
        try! invalidJSON.write(to: corruptedURL)

        // Attempt to load
        let loadedScene = loadGameScene(from: corruptedURL)

        // Should return nil for corrupted JSON
        XCTAssertNil(loadedScene, "Should return nil for corrupted JSON")

        // Cleanup
        try? FileManager.default.removeItem(at: corruptedURL)
    }

    // MARK: - Round-Trip Tests (Serialize -> Save -> Load -> Deserialize)

    func testRoundTripSingleEntity() {
        // Create an entity
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "RoundTripEntity")
        registerTransformComponent(entityId: entityId)
        translateTo(entityId: entityId, position: simd_float3(5.0, 10.0, 15.0))

        // Serialize
        var originalSceneData = serializeScene()
        originalSceneData.environment = nil // setting env to nil, so that I don't I can bypass generateHDR()
        let originalEntityCount = getAllGameEntities().count

        // Save to file
        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("roundtrip_scene.json")
        let jsonData = try! JSONEncoder().encode(originalSceneData)
        try! jsonData.write(to: sceneURL)

        // Clear the scene
        destroyAllEntities()
        XCTAssertEqual(getAllGameEntities().count, 0, "Scene should be empty after destroying all entities")

        // Load and deserialize
        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load scene")
            return
        }

        deserializeScene(sceneData: loadedSceneData)

        // Verify entity was recreated
        XCTAssertEqual(getAllGameEntities().count, originalEntityCount, "Should have same number of entities")

        let entities = getAllGameEntities()
        XCTAssertGreaterThan(entities.count, 0, "Should have at least one entity")

        let recreatedEntity = entities[0]
        XCTAssertEqual(getEntityName(entityId: recreatedEntity), "RoundTripEntity", "Entity name should match")

        // Cleanup
        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testRoundTripMultipleEntities() {
        // Create multiple entities
        for i in 0 ..< 5 {
            let entityId = createEntity()
            setEntityName(entityId: entityId, name: "Entity_\(i)")
            registerTransformComponent(entityId: entityId)
            translateTo(entityId: entityId, position: simd_float3(Float(i), Float(i * 2), Float(i * 3)))
        }

        let originalCount = getAllGameEntities().count

        // Serialize
        var sceneData = serializeScene()
        sceneData.environment = nil // setting env to nil, so that I don't I can bypass generateHDR()

        // Clear and deserialize
        destroyAllEntities()
        deserializeScene(sceneData: sceneData)

        // Verify all entities were recreated
        XCTAssertEqual(getAllGameEntities().count, originalCount, "Should recreate all entities")
    }

    // MARK: - Entity Component Tests

    func testSerializeCameraComponent() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "CameraEntity")
        createGameCamera(entityId: entityId)

        let eye = simd_float3(0, 5, 10)
        let target = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        cameraLookAt(entityId: entityId, eye: eye, target: target, up: up)

        // Serialize
        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasCameraComponent == true, "Entity should have camera component")
        XCTAssertNotNil(sceneData.entities[0].cameraData, "Camera data should not be nil")
        XCTAssertEqual(sceneData.entities[0].cameraData?.eye, eye, "Camera eye position should match")
        XCTAssertEqual(sceneData.entities[0].cameraData?.target, target, "Camera target should match")
    }

    func testSerializeDirectionalLight() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "DirLight")
        createDirLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
            XCTFail("Light component should exist")
            return
        }

        lightComponent.color = simd_float3(1.0, 0.8, 0.6)
        lightComponent.intensity = 2.5

        // Serialize
        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasDirLightComponent == true, "Should have directional light component")
        XCTAssertNotNil(sceneData.entities[0].lightData, "Light data should not be nil")
        XCTAssertEqual(sceneData.entities[0].lightData?.color, simd_float3(1.0, 0.8, 0.6), "Light color should match")
        XCTAssertEqual(sceneData.entities[0].lightData?.intensity, 2.5, "Light intensity should match")
    }

    func testSerializePointLight() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "PointLight")
        createPointLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId),
              let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId)
        else {
            XCTFail("Light components should exist")
            return
        }

        lightComponent.color = simd_float3(1.0, 0.0, 0.0)
        lightComponent.intensity = 3.0
        pointLightComponent.radius = 10.0
        pointLightComponent.falloff = 0.75

        // Serialize
        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasPointLightComponent == true, "Should have point light component")
        XCTAssertEqual(sceneData.entities[0].lightData?.radius, 10.0, "Radius should match")
        XCTAssertEqual(sceneData.entities[0].lightData?.falloff, 0.75, "Falloff should match")
    }

    func testSerializeSpotLight() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "SpotLight")
        createSpotLight(entityId: entityId)

        guard let lightComponent = scene.get(component: LightComponent.self, for: entityId),
              let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId)
        else {
            XCTFail("Light components should exist")
            return
        }

        lightComponent.intensity = 4.0
        spotLightComponent.coneAngle = 45.0

        // Serialize
        let sceneData = serializeScene()

        XCTAssertTrue(sceneData.entities[0].hasSpotLightComponent == true, "Should have spot light component")
        XCTAssertEqual(sceneData.entities[0].lightData?.coneAngle, 45.0, "Cone angle should match")
    }

    func testSerializeAreaLight() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "AreaLight")
        createAreaLight(entityId: entityId)

        guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
            XCTFail("Area light component should exist")
            return
        }

        let bounds = getDimension(entityId: entityId)
        areaLightComponent.bounds = simd_float2(bounds.width, bounds.height)
        areaLightComponent.twoSided = true

        // Serialize
        let sceneData = serializeScene()

        XCTAssertTrue(sceneData.entities[0].hasAreaLightComponent == true, "Should have area light component")
        XCTAssertEqual(sceneData.entities[0].lightData?.bounds, simd_float2(bounds.width, bounds.height), "Bounds should match")
        XCTAssertTrue(sceneData.entities[0].lightData?.twoSided == true, "Two-sided flag should match")
    }

    // MARK: - Post-Processing Effects Tests

    func testSerializeBloomSettings() {
        // Modify bloom settings
        BloomThresholdParams.shared.threshold = 1.5
        BloomThresholdParams.shared.intensity = 0.8
        BloomThresholdParams.shared.enabled = true

        // Serialize
        let sceneData = serializeScene()

        // Verify bloom data
        XCTAssertNotNil(sceneData.bloom, "Bloom data should be serialized")
        XCTAssertEqual(sceneData.bloom?.threshold, 1.5, "Bloom threshold should match")
        XCTAssertEqual(sceneData.bloom?.intensity, 0.8, "Bloom intensity should match")
        XCTAssertTrue(sceneData.bloom?.enabled == true, "Bloom enabled flag should match")

        // Reset to defaults
        BloomThresholdParams.shared.threshold = 1.0
        BloomThresholdParams.shared.intensity = 1.0
        BloomThresholdParams.shared.enabled = false
    }

    func testSerializeVignetteSettings() {
        // Modify vignette settings
        VignetteParams.shared.intensity = 0.6
        VignetteParams.shared.radius = 0.8
        VignetteParams.shared.softness = 0.5
        VignetteParams.shared.enabled = true

        // Serialize
        let sceneData = serializeScene()

        // Verify vignette data
        XCTAssertNotNil(sceneData.vignette, "Vignette data should be serialized")
        XCTAssertEqual(sceneData.vignette?.intensity, 0.6, "Vignette intensity should match")
        XCTAssertEqual(sceneData.vignette?.radius, 0.8, "Vignette radius should match")
        XCTAssertTrue(sceneData.vignette?.enabled == true, "Vignette enabled flag should match")

        // Reset
        VignetteParams.shared.enabled = false
    }

    func testSerializeColorGradingSettings() {
        // Modify color grading
        ColorGradingParams.shared.brightness = 0.1
        ColorGradingParams.shared.contrast = 1.2
        ColorGradingParams.shared.saturation = 1.1
        ColorGradingParams.shared.temperature = 0.05

        // Serialize
        let sceneData = serializeScene()

        // Verify
        XCTAssertNotNil(sceneData.colorGrading, "Color grading data should be serialized")
        XCTAssertEqual(sceneData.colorGrading?.brightness, 0.1, "Brightness should match")
        XCTAssertEqual(sceneData.colorGrading?.contrast, 1.2, "Contrast should match")
        XCTAssertEqual(sceneData.colorGrading?.saturation, 1.1, "Saturation should match")

        // Reset
        ColorGradingParams.shared.brightness = 0.0
        ColorGradingParams.shared.contrast = 1.0
        ColorGradingParams.shared.saturation = 1.0
        ColorGradingParams.shared.temperature = 0.0
    }

    func testSerializeDepthOfFieldSettings() {
        // Modify depth of field
        DepthOfFieldParams.shared.focusDistance = 0.5
        DepthOfFieldParams.shared.focusRange = 0.2
        DepthOfFieldParams.shared.maxBlur = 0.01
        DepthOfFieldParams.shared.enabled = true

        // Serialize
        let sceneData = serializeScene()

        // Verify
        XCTAssertNotNil(sceneData.depthOfField, "Depth of field data should be serialized")
        XCTAssertEqual(sceneData.depthOfField?.focusDistance, 0.5, "Focus distance should match")
        XCTAssertEqual(sceneData.depthOfField?.focusRange, 0.2, "Focus range should match")
        XCTAssertTrue(sceneData.depthOfField?.enabled == true, "DoF enabled flag should match")

        // Reset
        DepthOfFieldParams.shared.enabled = false
    }

    func testSerializeSSAOSettings() {
        // Modify SSAO
        SSAOParams.shared.radius = 1.0
        SSAOParams.shared.bias = 0.05
        SSAOParams.shared.intensity = 1.5
        SSAOParams.shared.enabled = true

        // Serialize
        let sceneData = serializeScene()

        // Verify
        XCTAssertNotNil(sceneData.ssao, "SSAO data should be serialized")
        XCTAssertEqual(sceneData.ssao?.radius, 1.0, "SSAO radius should match")
        XCTAssertEqual(sceneData.ssao?.bias, 0.05, "SSAO bias should match")
        XCTAssertEqual(sceneData.ssao?.intensity, 1.5, "SSAO intensity should match")
        XCTAssertTrue(sceneData.ssao?.enabled == true, "SSAO enabled flag should match")

        // Reset
        SSAOParams.shared.enabled = false
        SSAOParams.shared.intensity = 0.0
    }

    // MARK: - Deserialization Tests

    func testDeserializeEmptyScene() {
        // Create empty scene data
        let sceneData = SceneData()

        // Should not crash
        deserializeScene(sceneData: sceneData)

        // Verify no entities were created
        XCTAssertEqual(getAllGameEntities().count, 0, "No entities should be created from empty scene")
    }

    func testDeserializeWithEnvironmentSettings() {
        // Create scene data with environment
        var sceneData = SceneData()
        sceneData.environment = EnvironmentData(
            applyIBL: true,
            renderEnvironment: true,
            hdr: "test_hdr.hdr",
            ambientIntensity: 0.8
        )

        // Deserialize
        deserializeScene(sceneData: sceneData)

        // Verify environment settings were applied
        XCTAssertTrue(applyIBL, "IBL should be enabled")
        XCTAssertTrue(renderEnvironment, "Render environment should be enabled")
        XCTAssertEqual(ambientIntensity, 0.8, accuracy: 0.01, "Ambient intensity should match")
    }

    func testDeserializePostProcessingEffects() {
        // Create scene data with post-processing
        var sceneData = SceneData()
        sceneData.bloom = BloomThresholdData(threshold: 2.0, intensity: 1.5, enabled: true)
        sceneData.vignette = VignetteData(intensity: 0.5, radius: 0.6, softness: 0.4, center: simd_float2(0.5, 0.5), enabled: true)

        // Deserialize
        deserializeScene(sceneData: sceneData)

        // Verify post-processing was applied
        XCTAssertEqual(BloomThresholdParams.shared.threshold, 2.0, accuracy: 0.01, "Bloom threshold should be applied")
        XCTAssertEqual(BloomThresholdParams.shared.intensity, 1.5, accuracy: 0.01, "Bloom intensity should be applied")
        XCTAssertTrue(BloomThresholdParams.shared.enabled, "Bloom should be enabled")

        XCTAssertEqual(VignetteParams.shared.intensity, 0.5, accuracy: 0.01, "Vignette intensity should be applied")
        XCTAssertTrue(VignetteParams.shared.enabled, "Vignette should be enabled")

        // Cleanup
        BloomThresholdParams.shared.enabled = false
        VignetteParams.shared.enabled = false
    }

    // MARK: - Parent-Child Hierarchy Tests

    func testSerializeParentChildHierarchy() {
        // Create parent entity
        let parentId = createEntity()
        setEntityName(entityId: parentId, name: "Parent")
        registerTransformComponent(entityId: parentId)
        registerSceneGraphComponent(entityId: parentId)

        // Create child entity
        let childId = createEntity()
        setEntityName(entityId: childId, name: "Child")
        registerTransformComponent(entityId: childId)
        registerSceneGraphComponent(entityId: childId)

        // Set parent-child relationship
        setParent(childId: childId, parentId: parentId)

        // Serialize
        let sceneData = serializeScene()

        // Verify hierarchy is preserved in serialization
        XCTAssertEqual(sceneData.entities.count, 2, "Should have two entities")

        // Find child entity data
        let childEntityData = sceneData.entities.first { $0.name == "Child" }
        XCTAssertNotNil(childEntityData, "Child entity should exist in scene data")
        XCTAssertNotNil(childEntityData?.parentUUID, "Child should have parent UUID")
    }

    func testDeserializeParentChildHierarchy() {
        // Create scene data with hierarchy
        let parentUUID = UUID()
        let childUUID = UUID()

        var parentEntity = EntityData()
        parentEntity.uuid = parentUUID
        parentEntity.name = "Parent"
        parentEntity.hasLocalTransformComponent = true

        var childEntity = EntityData()
        childEntity.uuid = childUUID
        childEntity.name = "Child"
        childEntity.parentUUID = parentUUID
        childEntity.hasLocalTransformComponent = true

        var sceneData = SceneData()
        sceneData.entities = [parentEntity, childEntity]

        // Deserialize
        deserializeScene(sceneData: sceneData)

        // Verify entities were created
        let entities = getAllGameEntities()
        XCTAssertEqual(entities.count, 2, "Should create two entities")

        // Find child and verify it has a parent
        let childEntityId = entities.first { getEntityName(entityId: $0) == "Child" }
        XCTAssertNotNil(childEntityId, "Child entity should be created")

        if let childId = childEntityId {
            let parent = getEntityParent(entityId: childId)
            XCTAssertNotNil(parent, "Child should have a parent")
        }
    }

    // MARK: - Edge Cases and Error Handling

    func testSerializeWithNoComponents() {
        // Create entity without any components
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "BareEntity")

        // Should still serialize
        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.entities.count, 1, "Should serialize entity without components")
        XCTAssertEqual(sceneData.entities[0].name, "BareEntity", "Name should be preserved")
    }

    func testLoadSceneWithNonFileURL() {
        // Create a URL that's not a file URL
        guard let url = URL(string: "https://example.com/scene.json") else {
            XCTFail("Failed to create URL")
            return
        }

        // Should handle gracefully
        let loadedScene = loadGameScene(from: url)
        XCTAssertNil(loadedScene, "Should return nil for non-file URL")
    }
}
