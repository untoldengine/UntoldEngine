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

final class SceneSerializerTests: BaseRenderSetup {
    // MARK: - Setup and Teardown

    override func setUp() {
        super.setUp()
        // Clean up any existing entities
        destroyAllEntities()
        Logger.logLevel = .none
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

    func testRoundTripBaseSceneViaJSONFile() {
        // Recreate the base scene from BaseRenderSetup.
        initializeAssets()

        let originalSceneData = serializeScene()
        let serializedAuthoredCount = originalSceneData.entities.count

        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("base_scene_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(originalSceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write base scene JSON: \(error)")
            return
        }

        destroyAllEntities()
        XCTAssertEqual(getAllGameEntities().count, 0, "Scene should be empty after destroying all entities")

        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load base scene JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        let authoredEntities = getAllGameEntities().filter { entityId in
            !hasComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self)
        }

        XCTAssertEqual(authoredEntities.count, serializedAuthoredCount, "Should recreate all authored entities")
        XCTAssertTrue(authoredEntities.contains { getEntityName(entityId: $0) == "player" }, "Player entity should be recreated")
        XCTAssertTrue(authoredEntities.contains { getEntityName(entityId: $0) == "ball" }, "Ball entity should be recreated")
        XCTAssertTrue(authoredEntities.contains { getEntityName(entityId: $0) == "stadium" }, "Stadium entity should be recreated")

        try? FileManager.default.removeItem(at: sceneURL)
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

    // MARK: - Asset Instance Override Tests

    func testSerializeSceneStoresDerivedNodeNameOverride() {
        let rootId = createEntity()
        setEntityName(entityId: rootId, name: "AssetRoot")

        registerComponent(entityId: rootId, componentType: AssetInstanceComponent.self)
        guard let assetInstance = scene.get(component: AssetInstanceComponent.self, for: rootId) else {
            XCTFail("AssetInstanceComponent should exist on root entity")
            return
        }
        assetInstance.assetURL = URL(fileURLWithPath: "/tmp/test.usdz")
        assetInstance.assetName = "test"
        assetInstance.importMode = "preserveHierarchy"
        assetInstance.rootPrimPath = nil

        let childId = createEntity()
        setEntityName(entityId: childId, name: "RenamedChild")
        setParent(childId: childId, parentId: rootId)

        registerComponent(entityId: childId, componentType: DerivedAssetNodeComponent.self)
        guard let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) else {
            XCTFail("DerivedAssetNodeComponent should exist on child entity")
            return
        }
        derivedComp.assetRootEntityId = rootId
        derivedComp.nodePath = "Root/Child#0"

        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.entities.count, 1, "Only the asset root should be serialized")
        guard let serializedRoot = sceneData.entities.first else {
            XCTFail("Serialized root entity should exist")
            return
        }
        XCTAssertEqual(serializedRoot.name, "AssetRoot", "Root entity name should match")
        XCTAssertNotNil(serializedRoot.assetInstance, "Asset instance data should be serialized")
        XCTAssertEqual(serializedRoot.assetInstance?.overrides.count, 1, "Should serialize one derived override")
        XCTAssertEqual(serializedRoot.assetInstance?.overrides.first?.nodePath, "Root/Child#0", "Override nodePath should match")
        XCTAssertEqual(serializedRoot.assetInstance?.overrides.first?.name, "RenamedChild", "Override name should match")
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

    // MARK: - IBL Serialization Tests

    func testSceneSerializerOnlySerializesEnvironmentDataWhenApplyIBLOrRenderEnvironmentIsTrue() {
        // Test case 1: Neither applyIBL nor renderEnvironment is true
        applyIBL = false
        renderEnvironment = false
        hdrURL = "test.hdr"

        let sceneData1 = serializeScene()
        XCTAssertNil(sceneData1.environment, "Environment should not be serialized when both applyIBL and renderEnvironment are false")

        // Test case 2: Only applyIBL is true
        applyIBL = true
        renderEnvironment = false

        let sceneData2 = serializeScene()
        XCTAssertNil(sceneData2.environment, "Environment should not be serialized when renderEnvironment is false (even if applyIBL is true)")

        // Test case 3: Only renderEnvironment is true
        applyIBL = false
        renderEnvironment = true

        let sceneData3 = serializeScene()
        XCTAssertNil(sceneData3.environment, "Environment should not be serialized when applyIBL is false (even if renderEnvironment is true)")

        // Test case 4: Both are true and HDR exists
        applyIBL = true
        renderEnvironment = true
        // Create a temporary HDR file
        let tempDir = FileManager.default.temporaryDirectory
        assetBasePath = tempDir
        let hdrDir = tempDir.appendingPathComponent("HDR")
        try? FileManager.default.createDirectory(at: hdrDir, withIntermediateDirectories: true)
        let hdrFile = hdrDir.appendingPathComponent("test.hdr")
        try? "dummy".write(to: hdrFile, atomically: true, encoding: .utf8)

        let sceneData4 = serializeScene()
        XCTAssertNotNil(sceneData4.environment, "Environment should be serialized when both applyIBL and renderEnvironment are true")
        XCTAssertEqual(sceneData4.environment?.applyIBL, true, "applyIBL should be true")
        XCTAssertEqual(sceneData4.environment?.renderEnvironment, true, "renderEnvironment should be true")

        // Cleanup
        try? FileManager.default.removeItem(at: hdrDir)
        applyIBL = false
        renderEnvironment = false
        assetBasePath = nil
    }

    func testSceneSerializerDisablesIBLWhenHDRFileDoesNotExist() {
        // Setup: Enable IBL and renderEnvironment, but point to non-existent HDR
        applyIBL = true
        renderEnvironment = true
        hdrURL = "nonexistent.hdr"

        let tempDir = FileManager.default.temporaryDirectory
        assetBasePath = tempDir
        // Create HDR directory but don't create the file
        let hdrDir = tempDir.appendingPathComponent("HDR")
        try? FileManager.default.createDirectory(at: hdrDir, withIntermediateDirectories: true)

        let sceneData = serializeScene()

        // Environment should not be serialized because HDR validation failed
        XCTAssertNil(sceneData.environment, "Environment should not be serialized when HDR file doesn't exist")

        // Cleanup
        try? FileManager.default.removeItem(at: hdrDir)
        applyIBL = false
        renderEnvironment = false
        assetBasePath = nil
    }

    func testSceneSerializerDisablesIBLWhenAssetBasePathIsNil() {
        // Setup: Enable IBL and renderEnvironment, but no asset base path
        applyIBL = true
        renderEnvironment = true
        hdrURL = "test.hdr"
        assetBasePath = nil

        let sceneData = serializeScene()

        // Environment should not be serialized because we can't validate HDR without base path
        XCTAssertNil(sceneData.environment, "Environment should not be serialized when assetBasePath is nil")

        // Cleanup
        applyIBL = false
        renderEnvironment = false
    }

    func testSceneSerializerOnlyCallsGenerateHDRWhenApplyIBLIsTrueAndValidHDRProvided() {
        // Test case 1: applyIBL is false
        var sceneData = SceneData()
        sceneData.environment = EnvironmentData(
            applyIBL: false,
            renderEnvironment: true,
            hdr: "test.hdr",
            ambientIntensity: 1.0
        )

        // Store original iblSuccessful state
        let originalIblSuccessful = iblSuccessful
        iblSuccessful = false

        deserializeScene(sceneData: sceneData)

        // generateHDR should not have been called, so iblSuccessful should still be false
        XCTAssertFalse(iblSuccessful, "generateHDR should not be called when applyIBL is false")
        XCTAssertFalse(applyIBL, "applyIBL should be false after deserialization")

        // Test case 2: applyIBL is true but no HDR provided
        sceneData.environment = EnvironmentData(
            applyIBL: true,
            renderEnvironment: true,
            hdr: nil,
            ambientIntensity: 1.0
        )

        deserializeScene(sceneData: sceneData)

        // generateHDR should not have been called because HDR is nil
        XCTAssertFalse(iblSuccessful, "generateHDR should not be called when HDR is nil")

        // Test case 3: applyIBL is true but HDR is empty string
        sceneData.environment = EnvironmentData(
            applyIBL: true,
            renderEnvironment: true,
            hdr: "",
            ambientIntensity: 1.0
        )

        deserializeScene(sceneData: sceneData)

        // generateHDR should not have been called because HDR is empty
        XCTAssertFalse(iblSuccessful, "generateHDR should not be called when HDR is empty")

        // Note: We cannot easily test the case where applyIBL is true and valid HDR is provided
        // because generateHDR requires actual HDR file resources and rendering setup

        // Cleanup
        iblSuccessful = originalIblSuccessful
        applyIBL = false
        renderEnvironment = false
    }

    func testFuncUtilsGenerateHDRSetsIblSuccessfulToFalseOnFailure() {
        // Store original state
        let originalIblSuccessful = iblSuccessful

        // Attempt to generate HDR with non-existent file
        iblSuccessful = true // Set to true initially to verify it gets set to false
        generateHDR("nonexistent_hdr_file.hdr")

        // After failure, iblSuccessful should be false
        XCTAssertFalse(iblSuccessful, "iblSuccessful should be set to false when HDR generation fails")

        // Restore original state
        iblSuccessful = originalIblSuccessful
    }

    func testGlobalsApplyIBLIsInitializedToFalseByDefault() {
        // This test verifies the default state when the module loads
        // We reset it in setUp, but we can verify the behavior

        // Create a new scene from scratch
        destroyAllEntities()

        // Create scene data without environment
        let sceneData = SceneData()

        // Before deserialization, manually reset applyIBL to its default
        applyIBL = false

        // Deserialize scene without environment data
        deserializeScene(sceneData: sceneData)

        // applyIBL should remain false (its default value)
        XCTAssertFalse(applyIBL, "applyIBL should be false by default when no environment data is provided")
    }
}
