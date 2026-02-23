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

private final class TestCustomComponent: Component, Codable {
    var intValue: Int = 0
    var label: String = ""
    required init() {}
}

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

    func testRoundChangeNameTripBaseSceneViaJSONFile() {
        // Recreate the base scene from BaseRenderSetup.
        initializeAssets()

        guard let player = findEntity(name: "player") else {
            XCTFail("Player should exist")
            return
        }

        setEntityName(entityId: player, name: "new_player")

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
        XCTAssertTrue(authoredEntities.contains { getEntityName(entityId: $0) == "new_player" }, "Player entity should be recreated")

        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testRoundChangeChildNameTripBaseSceneViaJSONFile() {
        // Recreate the base scene from BaseRenderSetup.
        initializeAssets()

        guard let stadium = findEntity(name: "stadium") else {
            XCTFail("Stadium should exist")
            return
        }

        let children: [EntityID] = getEntityChildren(parentId: stadium)

        // change name to 3rd child
        setEntityName(entityId: children[2], name: "new_child_name")
        XCTAssertEqual(getEntityName(entityId: children[2]), "new_child_name")

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

        guard let stadiumEntityID = authoredEntities.first(
            where: { getEntityName(entityId: $0) == "stadium" }
        ) else {
            XCTFail("Failed to find stadium id")
            return
        }

        // get all the children
        let newChildren = getEntityChildren(parentId: stadiumEntityID)

        XCTAssertTrue(newChildren.contains { getEntityName(entityId: $0) == "new_child_name" }, "Child entity should have new name")

        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testRoundTripCustomComponentViaJSON() {
        encodeCustomComponent(type: TestCustomComponent.self) { existing, decoded in
            existing.intValue = decoded.intValue
            existing.label = decoded.label
        }

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "CustomComponentEntity")
        registerComponent(entityId: entityId, componentType: TestCustomComponent.self)

        guard let component = scene.get(component: TestCustomComponent.self, for: entityId) else {
            XCTFail("Custom component should exist")
            return
        }

        component.intValue = 42
        component.label = "hello"

        let sceneData = serializeScene()

        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("custom_component_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write custom component JSON: \(error)")
            return
        }

        destroyAllEntities()

        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load custom component JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData)

        guard let recreated = findEntity(name: "CustomComponentEntity"),
              let recreatedComponent = scene.get(component: TestCustomComponent.self, for: recreated)
        else {
            XCTFail("Custom component should be restored after deserialization")
            return
        }

        XCTAssertEqual(recreatedComponent.intValue, 42, "Custom component intValue should round-trip")
        XCTAssertEqual(recreatedComponent.label, "hello", "Custom component label should round-trip")

        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testRoundTripAnimationComponentViaJSON() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "AnimatedEntity")
        setEntityMesh(entityId: entityId, filename: "redplayer", withExtension: "usdz")

        let animationURL = LoadingSystem.shared.resourceURL(forResource: "running", withExtension: "usdz")
        guard let animationURL else {
            XCTFail("Missing animation resource")
            return
        }

        setEntityAnimations(entityId: entityId, filename: "running", withExtension: "usdz", name: "running")

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
            XCTFail("AnimationComponent should exist")
            return
        }
        animationComponent.animationsFilenames = [animationURL]

        let sceneData = serializeScene()

        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("animation_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write animation JSON: \(error)")
            return
        }

        destroyAllEntities()

        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load animation JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        guard let recreated = findEntity(name: "AnimatedEntity"),
              let recreatedAnimation = scene.get(component: AnimationComponent.self, for: recreated)
        else {
            XCTFail("Animation component should be restored after deserialization")
            return
        }

        XCTAssertEqual(recreatedAnimation.currentAnimation?.name, "running",
                       "Animation name should match")

        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testMaterialTextureURLsRoundTripViaJSON() {
        guard let ball = findEntity(name: "ball") else {
            return
        }

        let expectedOpacity: Float = 0.35
        let expectedAlphaCutoff: Float = 0.42
        let expectedAlphaMode: MaterialAlphaMode = .mask

        updateMaterialOpacity(entityId: ball, opacity: expectedOpacity)
        updateMaterialAlphaCutoff(entityId: ball, cutoff: expectedAlphaCutoff)
        updateMaterialAlphaMode(entityId: ball, mode: expectedAlphaMode)

        let baseColorURL = getMaterialTextureURL(entityId: ball, type: .baseColor)
        let roughnessURL = getMaterialTextureURL(entityId: ball, type: .roughness)
        let metallicURL = getMaterialTextureURL(entityId: ball, type: .metallic)
        let normalURL = getMaterialTextureURL(entityId: ball, type: .normal)

        let sceneData = serializeScene()

        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("material_urls_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write material JSON: \(error)")
            return
        }

        destroyAllEntities()

        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load material JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        guard let recreated = findEntity(name: "ball")
        else {
            XCTFail("Render component should be restored after deserialization")
            return
        }

        XCTAssertEqual(getMaterialTextureURL(entityId: recreated, type: .baseColor), baseColorURL, "Base color URL should match")
        XCTAssertEqual(getMaterialTextureURL(entityId: recreated, type: .roughness), roughnessURL, "Roughness URL should match")
        XCTAssertEqual(getMaterialTextureURL(entityId: recreated, type: .metallic), metallicURL, "Metallic URL should match")
        XCTAssertEqual(getMaterialTextureURL(entityId: recreated, type: .normal), normalURL, "Normal URL should match")
        XCTAssertEqual(getMaterialOpacity(entityId: recreated), expectedOpacity, accuracy: 0.0001, "Opacity should round-trip")
        XCTAssertEqual(getMaterialAlphaCutoff(entityId: recreated), expectedAlphaCutoff, accuracy: 0.0001, "Alpha cutoff should round-trip")
        XCTAssertEqual(getMaterialAlphaMode(entityId: recreated), expectedAlphaMode, "Alpha mode should round-trip")

        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testAssetInstanceOverridesRoundTripViaJSON() {
        let rootId = createEntity()
        setEntityName(entityId: rootId, name: "AssetRoot")
        registerSceneGraphComponent(entityId: rootId)

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
        setEntityName(entityId: childId, name: "OverrideChild")
        registerSceneGraphComponent(entityId: childId)
        registerTransformComponent(entityId: childId)
        setParent(childId: childId, parentId: rootId)
        translateTo(entityId: childId, position: simd_float3(1.0, 2.0, 3.0))
        scaleTo(entityId: childId, scale: simd_float3(2.0, 2.0, 2.0))

        registerComponent(entityId: childId, componentType: DerivedAssetNodeComponent.self)
        guard let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) else {
            XCTFail("DerivedAssetNodeComponent should exist on child entity")
            return
        }
        derivedComp.assetRootEntityId = rootId
        derivedComp.nodePath = "Root/Child#0"

        let childMeshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: childId, meshes: childMeshes, assetName: "Cube")

        let expectedOverrideOpacity: Float = 0.28
        let expectedOverrideCutoff: Float = 0.61
        let expectedOverrideModeRawValue: Int32 = MaterialAlphaMode.mask.rawValue

        updateMaterialOpacity(entityId: childId, opacity: expectedOverrideOpacity)
        updateMaterialAlphaCutoff(entityId: childId, cutoff: expectedOverrideCutoff)
        updateMaterialAlphaMode(entityId: childId, mode: .mask)

        let sceneData = serializeScene()

        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("asset_instance_overrides.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write asset instance JSON: \(error)")
            return
        }

        guard let loadedSceneData = loadGameScene(from: sceneURL),
              let loadedRoot = loadedSceneData.entities.first,
              let overrides = loadedRoot.assetInstance?.overrides
        else {
            XCTFail("Failed to load asset instance overrides")
            return
        }

        XCTAssertEqual(overrides.count, 1, "Should round-trip one override")
        XCTAssertEqual(overrides.first?.nodePath, "Root/Child#0", "Override nodePath should round-trip")
        XCTAssertEqual(overrides.first?.name, "OverrideChild", "Override name should round-trip")
        XCTAssertEqual(overrides.first?.transform?.position, simd_float3(1.0, 2.0, 3.0), "Override position should round-trip")
        XCTAssertEqual(overrides.first?.transform?.scale, simd_float3(2.0, 2.0, 2.0), "Override scale should round-trip")
        guard let materialOverride = overrides.first?.material else {
            XCTFail("Override material should round-trip")
            return
        }
        guard let overrideOpacity = materialOverride.opacity else {
            XCTFail("Override opacity should be present")
            return
        }
        guard let overrideAlphaCutoff = materialOverride.alphaCutoff else {
            XCTFail("Override alpha cutoff should be present")
            return
        }
        XCTAssertEqual(overrideOpacity, expectedOverrideOpacity, accuracy: 0.0001, "Override opacity should round-trip")
        XCTAssertEqual(overrideAlphaCutoff, expectedOverrideCutoff, accuracy: 0.0001, "Override alpha cutoff should round-trip")
        XCTAssertEqual(materialOverride.alphaMode, expectedOverrideModeRawValue, "Override alpha mode should round-trip")

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
        ColorGradingParams.shared.enabled = true

        // Serialize
        let sceneData = serializeScene()

        // Verify
        XCTAssertNotNil(sceneData.colorGrading, "Color grading data should be serialized")
        XCTAssertEqual(sceneData.colorGrading?.brightness, 0.1, "Brightness should match")
        XCTAssertEqual(sceneData.colorGrading?.contrast, 1.2, "Contrast should match")
        XCTAssertEqual(sceneData.colorGrading?.saturation, 1.1, "Saturation should match")
        XCTAssertTrue(sceneData.colorGrading?.enabled == true, "Color grading enabled flag should match")

        // Reset
        ColorGradingParams.shared.brightness = 0.0
        ColorGradingParams.shared.contrast = 1.0
        ColorGradingParams.shared.saturation = 1.0
        ColorGradingParams.shared.temperature = 0.0
        ColorGradingParams.shared.enabled = false
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
        sceneData.colorGrading = ColorGradingData(
            brightness: 0.2,
            contrast: 1.1,
            saturation: 1.05,
            exposure: 0.1,
            temperature: 0.2,
            tint: -0.1,
            enabled: true
        )
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
        XCTAssertTrue(ColorGradingParams.shared.enabled, "Color grading should be enabled")

        // Cleanup
        ColorGradingParams.shared.enabled = false
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

    func testProceduralMeshSerializationDeserialization() {
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "ProcCube")
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")

        let sceneData = serializeScene()

        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        guard let loadedId = findEntity(name: "ProcCube") else {
            XCTFail("Expected to find procedural entity after deserialization")
            return
        }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: loadedId) else {
            XCTFail("Expected RenderComponent on deserialized procedural entity")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Procedural mesh should be recreated on deserialize")
        XCTAssertEqual(renderComponent.assetName, "Cube")
        XCTAssertTrue(renderComponent.assetURL.path.hasPrefix("/primitive/"))
    }

    // MARK: - LOD Component Tests

    func testSerializeLODComponent() {
        // Create entity with LOD component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "LODEntity")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: LODComponent.self)

        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            XCTFail("LODComponent should exist")
            return
        }

        // Create mock LOD levels with URLs
        let lod0URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD0.usdz")
        let lod1URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD1.usdz")
        let lod2URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD2.usdz")

        // Create empty mesh arrays for testing (we only care about serialization)
        let emptyMeshes: [Mesh] = []

        lodComponent.lodLevels = [
            LODLevel(mesh: emptyMeshes, maxDistance: 10.0, screenPercentage: 0.0, url: lod0URL),
            LODLevel(mesh: emptyMeshes, maxDistance: 25.0, screenPercentage: 0.0, url: lod1URL),
            LODLevel(mesh: emptyMeshes, maxDistance: 50.0, screenPercentage: 0.0, url: lod2URL),
        ]
        lodComponent.currentLOD = 1
        lodComponent.fadeTransition = true
        lodComponent.transitionDuration = 0.5

        // Serialize
        let sceneData = serializeScene()

        // Verify LOD data was serialized
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasLODComponent == true, "Should have LOD component flag")
        XCTAssertNotNil(sceneData.entities[0].lodData, "LOD data should not be nil")

        let lodData = sceneData.entities[0].lodData!
        XCTAssertEqual(lodData.lodLevels.count, 3, "Should have 3 LOD levels")
        XCTAssertEqual(lodData.currentLOD, 1, "Current LOD should match")
        XCTAssertTrue(lodData.fadeTransition, "Fade transition should be enabled")
        XCTAssertEqual(lodData.transitionDuration, 0.5, "Transition duration should match")

        // Verify LOD level data
        XCTAssertEqual(lodData.lodLevels[0].url, lod0URL, "LOD0 URL should match")
        XCTAssertEqual(lodData.lodLevels[0].maxDistance, 10.0, "LOD0 distance should match")

        XCTAssertEqual(lodData.lodLevels[1].url, lod1URL, "LOD1 URL should match")
        XCTAssertEqual(lodData.lodLevels[1].maxDistance, 25.0, "LOD1 distance should match")

        XCTAssertEqual(lodData.lodLevels[2].url, lod2URL, "LOD2 URL should match")
        XCTAssertEqual(lodData.lodLevels[2].maxDistance, 50.0, "LOD2 distance should match")
    }

    func testSerializeLODComponentWithoutURLs() {
        // Test that LOD levels without URLs are not serialized
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "LODEntityNoURLs")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: LODComponent.self)

        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            XCTFail("LODComponent should exist")
            return
        }

        // Create LOD levels without URLs (url = nil)
        let emptyMeshes: [Mesh] = []
        lodComponent.lodLevels = [
            LODLevel(mesh: emptyMeshes, maxDistance: 10.0, screenPercentage: 0.0, url: nil),
            LODLevel(mesh: emptyMeshes, maxDistance: 25.0, screenPercentage: 0.0, url: nil),
        ]

        // Serialize
        let sceneData = serializeScene()

        // Verify LOD component exists but no LOD data was serialized (because URLs are nil)
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasLODComponent == true, "Should have LOD component flag")
        XCTAssertNil(sceneData.entities[0].lodData, "LOD data should be nil when no URLs are present")
    }

    func testSerializeLODComponentMixedURLs() {
        // Test that only LOD levels with URLs are serialized
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "LODEntityMixed")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: LODComponent.self)

        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            XCTFail("LODComponent should exist")
            return
        }

        let lod0URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD0.usdz")
        let lod2URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD2.usdz")
        let emptyMeshes: [Mesh] = []

        lodComponent.lodLevels = [
            LODLevel(mesh: emptyMeshes, maxDistance: 10.0, screenPercentage: 0.0, url: lod0URL),
            LODLevel(mesh: emptyMeshes, maxDistance: 25.0, screenPercentage: 0.0, url: nil), // No URL
            LODLevel(mesh: emptyMeshes, maxDistance: 50.0, screenPercentage: 0.0, url: lod2URL),
        ]

        // Serialize
        let sceneData = serializeScene()

        // Verify only LOD levels with URLs were serialized
        XCTAssertNotNil(sceneData.entities[0].lodData, "LOD data should exist")
        let lodData = sceneData.entities[0].lodData!
        XCTAssertEqual(lodData.lodLevels.count, 2, "Should only serialize LOD levels with URLs")
        XCTAssertEqual(lodData.lodLevels[0].url, lod0URL, "First serialized LOD should be LOD0")
        XCTAssertEqual(lodData.lodLevels[1].url, lod2URL, "Second serialized LOD should be LOD2")
    }

    func testSerializeEntityWithoutLODComponent() {
        // Verify entities without LOD component don't have LOD data
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "RegularEntity")
        registerTransformComponent(entityId: entityId)

        // Serialize
        let sceneData = serializeScene()

        // Verify no LOD data
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertNil(sceneData.entities[0].hasLODComponent, "Should not have LOD component flag")
        XCTAssertNil(sceneData.entities[0].lodData, "Should not have LOD data")
    }

    // MARK: - Static Batch Component Tests

    func testSerializeSingleEntityWithStaticBatchComponent() {
        // Create entity with mesh and static batch component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StaticCube")
        registerTransformComponent(entityId: entityId)
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")

        // Mark as static
        setEntityStaticBatchComponent(entityId: entityId)

        // Serialize
        let sceneData = serializeScene()

        // Verify StaticBatchComponent was serialized
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasStaticBatchComponent == true, "Should have static batch component flag")
    }

    func testDeserializeSingleEntityWithStaticBatchComponent() {
        // Create entity with mesh and static batch component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StaticCube")
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")
        setEntityStaticBatchComponent(entityId: entityId)

        // Serialize
        let sceneData = serializeScene()

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Deserialize
        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        // Verify entity was recreated with StaticBatchComponent
        guard let recreatedId = findEntity(name: "StaticCube") else {
            XCTFail("Expected to find StaticCube after deserialization")
            return
        }

        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StaticBatchComponent.self),
            "StaticBatchComponent should be restored after deserialization"
        )
    }

    func testSerializeParentWithStaticBatchChildren() {
        // Create parent entity (USDZ root)
        let parentId = createEntity()
        setEntityName(entityId: parentId, name: "TreeRoot")
        registerTransformComponent(entityId: parentId)
        registerSceneGraphComponent(entityId: parentId)

        // Create child entities with meshes
        let child1 = createEntity()
        setEntityName(entityId: child1, name: "TreeTrunk")
        registerTransformComponent(entityId: child1)
        registerSceneGraphComponent(entityId: child1)
        let mesh1 = BasicPrimitives.createCylinder()
        setEntityMeshDirect(entityId: child1, meshes: mesh1, assetName: "Cylinder")
        setParent(childId: child1, parentId: parentId)
        setEntityStaticBatchComponent(entityId: child1)

        let child2 = createEntity()
        setEntityName(entityId: child2, name: "TreeLeaves")
        registerTransformComponent(entityId: child2)
        registerSceneGraphComponent(entityId: child2)
        let mesh2 = BasicPrimitives.createSphere()
        setEntityMeshDirect(entityId: child2, meshes: mesh2, assetName: "Sphere")
        setParent(childId: child2, parentId: parentId)
        setEntityStaticBatchComponent(entityId: child2)

        // Serialize
        let sceneData = serializeScene()

        // Verify parent has StaticBatchComponent flag (due to recursive check)
        XCTAssertEqual(sceneData.entities.count, 3, "Should have parent + 2 children")
        let parentData = sceneData.entities.first { $0.name == "TreeRoot" }
        XCTAssertNotNil(parentData, "Parent entity should exist in scene data")
        XCTAssertTrue(
            parentData?.hasStaticBatchComponent == true,
            "Parent should have static batch component flag when children have the component"
        )
    }

    func testRoundTripStaticBatchComponentViaJSON() {
        // Create entity with static batch component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StaticEntity")
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")
        setEntityStaticBatchComponent(entityId: entityId)

        // Serialize to JSON
        let sceneData = serializeScene()
        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("static_batch_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write static batch JSON: \(error)")
            return
        }

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Load and deserialize
        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load static batch JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        // Verify component was restored
        guard let recreatedId = findEntity(name: "StaticEntity") else {
            XCTFail("Expected to find StaticEntity after deserialization")
            return
        }

        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StaticBatchComponent.self),
            "StaticBatchComponent should be restored after JSON round-trip"
        )

        // Cleanup
        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testRoundTripStaticBatchComponentWithHierarchyViaJSON() {
        // Create hierarchy: Parent with two static children
        let parentId = createEntity()
        setEntityName(entityId: parentId, name: "StaticGroup")
        registerTransformComponent(entityId: parentId)
        registerSceneGraphComponent(entityId: parentId)

        let child1 = createEntity()
        setEntityName(entityId: child1, name: "StaticChild1")
        registerTransformComponent(entityId: child1)
        registerSceneGraphComponent(entityId: child1)
        let mesh1 = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: child1, meshes: mesh1, assetName: "Cube")
        setParent(childId: child1, parentId: parentId)
        setEntityStaticBatchComponent(entityId: child1)

        let child2 = createEntity()
        setEntityName(entityId: child2, name: "StaticChild2")
        registerTransformComponent(entityId: child2)
        registerSceneGraphComponent(entityId: child2)
        let mesh2 = BasicPrimitives.createSphere()
        setEntityMeshDirect(entityId: child2, meshes: mesh2, assetName: "Sphere")
        setParent(childId: child2, parentId: parentId)
        setEntityStaticBatchComponent(entityId: child2)

        // Serialize to JSON
        let sceneData = serializeScene()
        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("static_batch_hierarchy_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write static batch hierarchy JSON: \(error)")
            return
        }

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Load and deserialize
        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load static batch hierarchy JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        // Verify all entities were recreated
        guard let recreatedParent = findEntity(name: "StaticGroup"),
              let recreatedChild1 = findEntity(name: "StaticChild1"),
              let recreatedChild2 = findEntity(name: "StaticChild2")
        else {
            XCTFail("Expected to find all entities after deserialization")
            return
        }

        // Verify children have StaticBatchComponent
        XCTAssertTrue(
            hasComponent(entityId: recreatedChild1, componentType: StaticBatchComponent.self),
            "Child1 should have StaticBatchComponent after deserialization"
        )
        XCTAssertTrue(
            hasComponent(entityId: recreatedChild2, componentType: StaticBatchComponent.self),
            "Child2 should have StaticBatchComponent after deserialization"
        )

        // Verify hierarchy was restored
        let parent = getEntityParent(entityId: recreatedChild1)
        XCTAssertEqual(parent, recreatedParent, "Child1 should have correct parent")
        let parent2 = getEntityParent(entityId: recreatedChild2)
        XCTAssertEqual(parent2, recreatedParent, "Child2 should have correct parent")

        // Cleanup
        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testSerializeEntityWithoutStaticBatchComponent() {
        // Verify entities without StaticBatchComponent don't have the flag
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "DynamicEntity")
        registerTransformComponent(entityId: entityId)
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")

        // Serialize without marking as static
        let sceneData = serializeScene()

        // Verify no StaticBatchComponent flag
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertNil(sceneData.entities[0].hasStaticBatchComponent, "Should not have static batch component flag")
    }

    func testSerializeRecursiveHierarchyCheck() {
        // Test that hasStaticBatchInHierarchy checks deeply nested children
        let root = createEntity()
        setEntityName(entityId: root, name: "Root")
        registerTransformComponent(entityId: root)
        registerSceneGraphComponent(entityId: root)

        let level1 = createEntity()
        setEntityName(entityId: level1, name: "Level1")
        registerTransformComponent(entityId: level1)
        registerSceneGraphComponent(entityId: level1)
        setParent(childId: level1, parentId: root)

        let level2 = createEntity()
        setEntityName(entityId: level2, name: "Level2")
        registerTransformComponent(entityId: level2)
        registerSceneGraphComponent(entityId: level2)
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: level2, meshes: meshes, assetName: "Cube")
        setParent(childId: level2, parentId: level1)
        setEntityStaticBatchComponent(entityId: level2) // Only deepest child has component

        // Serialize
        let sceneData = serializeScene()

        // Both root and level1 should have the flag due to recursive check
        let rootData = sceneData.entities.first { $0.name == "Root" }
        let level1Data = sceneData.entities.first { $0.name == "Level1" }
        let level2Data = sceneData.entities.first { $0.name == "Level2" }

        XCTAssertTrue(rootData?.hasStaticBatchComponent == true, "Root should have flag (child hierarchy contains component)")
        XCTAssertTrue(level1Data?.hasStaticBatchComponent == true, "Level1 should have flag (child hierarchy contains component)")
        XCTAssertTrue(level2Data?.hasStaticBatchComponent == true, "Level2 should have flag (has component directly)")
    }

    // MARK: - Geometry Streaming Component Tests

    func testSerializeStreamingComponent() {
        // Create entity with streaming component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StreamedEntity")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)

        guard let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) else {
            XCTFail("StreamingComponent should exist")
            return
        }

        // Set streaming properties
        streamingComponent.streamingRadius = 250.0
        streamingComponent.unloadRadius = 350.0
        streamingComponent.priority = 10
        streamingComponent.assetFilename = "tree_LOD0"
        streamingComponent.assetExtension = "usdz"
        streamingComponent.assetName = "Tree"

        // Serialize
        let sceneData = serializeScene()

        // Verify StreamingComponent was serialized
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasStreamingComponent == true, "Should have streaming component flag")
        XCTAssertNotNil(sceneData.entities[0].streamingData, "Streaming data should not be nil")

        let streamingData = sceneData.entities[0].streamingData!
        XCTAssertEqual(streamingData.streamingRadius, 250.0, "Streaming radius should match")
        XCTAssertEqual(streamingData.unloadRadius, 350.0, "Unload radius should match")
        XCTAssertEqual(streamingData.priority, 10, "Priority should match")
        XCTAssertEqual(streamingData.assetFilename, "tree_LOD0", "Asset filename should match")
        XCTAssertEqual(streamingData.assetExtension, "usdz", "Asset extension should match")
        XCTAssertEqual(streamingData.assetName, "Tree", "Asset name should match")
    }

    func testDeserializeStreamingComponent() {
        // Create entity with streaming component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StreamedEntity")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)

        guard let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) else {
            XCTFail("StreamingComponent should exist")
            return
        }

        streamingComponent.streamingRadius = 200.0
        streamingComponent.unloadRadius = 300.0
        streamingComponent.priority = 5
        streamingComponent.assetFilename = "rock_LOD1"
        streamingComponent.assetExtension = "usdz"

        // Serialize
        let sceneData = serializeScene()

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Deserialize
        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        // Verify entity was recreated with StreamingComponent
        guard let recreatedId = findEntity(name: "StreamedEntity") else {
            XCTFail("Expected to find StreamedEntity after deserialization")
            return
        }

        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StreamingComponent.self),
            "StreamingComponent should be restored after deserialization"
        )

        // Verify streaming component properties were restored
        guard let recreatedComponent = scene.get(component: StreamingComponent.self, for: recreatedId) else {
            XCTFail("StreamingComponent should exist on recreated entity")
            return
        }

        XCTAssertEqual(recreatedComponent.streamingRadius, 200.0, "Streaming radius should be restored")
        XCTAssertEqual(recreatedComponent.unloadRadius, 300.0, "Unload radius should be restored")
        XCTAssertEqual(recreatedComponent.priority, 5, "Priority should be restored")
        XCTAssertEqual(recreatedComponent.assetFilename, "rock_LOD1", "Asset filename should be restored")
        XCTAssertEqual(recreatedComponent.assetExtension, "usdz", "Asset extension should be restored")
        XCTAssertEqual(recreatedComponent.state, .unloaded, "State should be unloaded after deserialization")
    }

    func testRoundTripStreamingComponentViaJSON() {
        // Create entity with streaming component
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StreamedTree")
        registerTransformComponent(entityId: entityId)

        // Add a mesh so the transform is properly serialized
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")

        translateTo(entityId: entityId, position: simd_float3(10.0, 0.0, 5.0))
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)

        guard let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) else {
            XCTFail("StreamingComponent should exist")
            return
        }

        streamingComponent.streamingRadius = 150.0
        streamingComponent.unloadRadius = 250.0
        streamingComponent.priority = 8
        streamingComponent.assetFilename = "tree"
        streamingComponent.assetExtension = "usdz"
        streamingComponent.assetName = "TreeMesh"

        // Serialize to JSON
        let sceneData = serializeScene()
        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("streaming_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write streaming JSON: \(error)")
            return
        }

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Load and deserialize
        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load streaming JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        // Verify component was restored
        guard let recreatedId = findEntity(name: "StreamedTree") else {
            XCTFail("Expected to find StreamedTree after deserialization")
            return
        }

        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StreamingComponent.self),
            "StreamingComponent should be restored after JSON round-trip"
        )

        guard let recreatedComponent = scene.get(component: StreamingComponent.self, for: recreatedId) else {
            XCTFail("StreamingComponent should exist after round-trip")
            return
        }

        XCTAssertEqual(recreatedComponent.streamingRadius, 150.0, "Streaming radius should round-trip")
        XCTAssertEqual(recreatedComponent.unloadRadius, 250.0, "Unload radius should round-trip")
        XCTAssertEqual(recreatedComponent.priority, 8, "Priority should round-trip")
        XCTAssertEqual(recreatedComponent.assetFilename, "tree", "Asset filename should round-trip")
        XCTAssertEqual(recreatedComponent.assetExtension, "usdz", "Asset extension should round-trip")
        XCTAssertEqual(recreatedComponent.assetName, "TreeMesh", "Asset name should round-trip")

        // Cleanup
        try? FileManager.default.removeItem(at: sceneURL)
    }

    func testSerializeEntityWithoutStreamingComponent() {
        // Verify entities without StreamingComponent don't have streaming data
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "RegularEntity")
        registerTransformComponent(entityId: entityId)

        // Serialize without streaming
        let sceneData = serializeScene()

        // Verify no StreamingComponent flag or data
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertNil(sceneData.entities[0].hasStreamingComponent, "Should not have streaming component flag")
        XCTAssertNil(sceneData.entities[0].streamingData, "Should not have streaming data")
    }

    func testSerializeLODWithStreamingComponent() {
        // Test entity with both LOD and Streaming components
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "LODStreamEntity")
        registerTransformComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: LODComponent.self)
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)

        // Setup LOD
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            XCTFail("LODComponent should exist")
            return
        }

        let lod0URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD0.usdz")
        let lod1URL = URL(fileURLWithPath: "/GameData/Models/tree/tree_LOD1.usdz")
        let emptyMeshes: [Mesh] = []

        lodComponent.lodLevels = [
            LODLevel(mesh: emptyMeshes, maxDistance: 50.0, screenPercentage: 0.0, url: lod0URL),
            LODLevel(mesh: emptyMeshes, maxDistance: 100.0, screenPercentage: 0.0, url: lod1URL),
        ]

        // Setup Streaming
        guard let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) else {
            XCTFail("StreamingComponent should exist")
            return
        }

        streamingComponent.streamingRadius = 200.0
        streamingComponent.unloadRadius = 300.0
        streamingComponent.priority = 7
        streamingComponent.assetFilename = "tree_LOD0"
        streamingComponent.assetExtension = "usdz"

        // Serialize
        let sceneData = serializeScene()

        // Verify both components were serialized
        XCTAssertEqual(sceneData.entities.count, 1, "Should have one entity")
        XCTAssertTrue(sceneData.entities[0].hasLODComponent == true, "Should have LOD component flag")
        XCTAssertTrue(sceneData.entities[0].hasStreamingComponent == true, "Should have streaming component flag")
        XCTAssertNotNil(sceneData.entities[0].lodData, "LOD data should not be nil")
        XCTAssertNotNil(sceneData.entities[0].streamingData, "Streaming data should not be nil")

        // Verify LOD data
        let lodData = sceneData.entities[0].lodData!
        XCTAssertEqual(lodData.lodLevels.count, 2, "Should have 2 LOD levels")

        // Verify Streaming data
        let streamingData = sceneData.entities[0].streamingData!
        XCTAssertEqual(streamingData.streamingRadius, 200.0, "Streaming radius should match")
        XCTAssertEqual(streamingData.priority, 7, "Priority should match")
    }

    func testRoundTripStreamingStaticBatchViaJSON() {
        // Test entity with Streaming + StaticBatch components
        // Note: Testing all three (LOD + Streaming + StaticBatch) requires actual LOD files
        // which are not available in unit tests. This test verifies Streaming + StaticBatch work together.
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "ComplexEntity")
        registerTransformComponent(entityId: entityId)
        let meshes = BasicPrimitives.createCube()
        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "Cube")

        // Add Streaming component
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)
        guard let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) else {
            XCTFail("StreamingComponent should exist")
            return
        }

        streamingComponent.streamingRadius = 100.0
        streamingComponent.unloadRadius = 150.0
        streamingComponent.priority = 5
        streamingComponent.assetFilename = "cube_LOD0"
        streamingComponent.assetExtension = "usdz"

        // Add StaticBatch component
        setEntityStaticBatchComponent(entityId: entityId)

        // Serialize to JSON
        let sceneData = serializeScene()
        let tempDir = FileManager.default.temporaryDirectory
        let sceneURL = tempDir.appendingPathComponent("complex_roundtrip.json")

        do {
            let jsonData = try JSONEncoder().encode(sceneData)
            try jsonData.write(to: sceneURL)
        } catch {
            XCTFail("Failed to write complex JSON: \(error)")
            return
        }

        // Clear scene
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        // Load and deserialize
        guard let loadedSceneData = loadGameScene(from: sceneURL) else {
            XCTFail("Failed to load complex JSON")
            return
        }

        deserializeScene(sceneData: loadedSceneData, meshLoadingMode: .sync)

        // Verify components were restored
        guard let recreatedId = findEntity(name: "ComplexEntity") else {
            XCTFail("Expected to find ComplexEntity after deserialization")
            return
        }

        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StreamingComponent.self),
            "StreamingComponent should be restored"
        )
        XCTAssertTrue(
            hasComponent(entityId: recreatedId, componentType: StaticBatchComponent.self),
            "StaticBatchComponent should be restored"
        )

        // Verify streaming properties
        guard let recreatedStreaming = scene.get(component: StreamingComponent.self, for: recreatedId) else {
            XCTFail("StreamingComponent should exist after round-trip")
            return
        }

        XCTAssertEqual(recreatedStreaming.streamingRadius, 100.0, "Streaming radius should round-trip")
        XCTAssertEqual(recreatedStreaming.unloadRadius, 150.0, "Unload radius should round-trip")
        XCTAssertEqual(recreatedStreaming.priority, 5, "Priority should round-trip")

        // Cleanup
        try? FileManager.default.removeItem(at: sceneURL)
    }

    // MARK: - Completion Handler Tests

    func testDeserializeSceneCompletionHandler() {
        // Create a simple entity
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "CompletionTestEntity")
        registerTransformComponent(entityId: entityId)
        translateTo(entityId: entityId, position: simd_float3(1.0, 2.0, 3.0))

        // Serialize
        let sceneData = serializeScene()

        // Clear scene
        destroyAllEntities()

        // Test completion handler is called
        let expectation = XCTestExpectation(description: "Completion handler should be called")

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync) {
            // Verify entity was recreated before completion handler
            let entities = getAllGameEntities()
            XCTAssertEqual(entities.count, 1, "Entity should be recreated before completion")

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testDeserializeSceneCompletionHandlerWithNoCallback() {
        // Test that deserialize works without a completion handler
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "NoCallbackEntity")
        registerTransformComponent(entityId: entityId)

        let sceneData = serializeScene()
        destroyAllEntities()

        // Should not crash when no completion handler is provided
        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        // Verify entity was still created
        XCTAssertEqual(getAllGameEntities().count, 1, "Entity should be created even without completion handler")
    }

    func testDeserializeSceneCompletionHandler_invokedAfterAllAsyncLoadsComplete() async throws {
        // Given: Create multiple entities with render components that will trigger async loading
        let entityNames = ["AsyncEntity1", "AsyncEntity2", "AsyncEntity3"]
        for name in entityNames {
            let entityId = createEntity()
            setEntityName(entityId: entityId, name: name)
            registerTransformComponent(entityId: entityId)
            translateTo(entityId: entityId, position: simd_float3(Float.random(in: 0 ... 10), 0, 0))

            // Use a real file reference that will trigger async loading
            let meshes = BasicPrimitives.createCube()
            let mockURL = URL(fileURLWithPath: "/test/ball.usdz")
            registerRenderComponent(entityId: entityId, meshes: meshes, url: mockURL, assetName: "ball")
        }

        var sceneData = serializeScene()
        sceneData.environment = nil // Bypass HDR generation

        // When: Clear scene and deserialize with async mode
        destroyAllEntities()
        scene.finalizePendingDestroys()
        entityNameMap.removeAll()
        reverseEntityNameMap.removeAll()

        XCTAssertEqual(getAllGameEntities().count, 0, "Scene should be empty before deserialize")

        // Track which async loads have been triggered
        var asyncLoadsTriggered = 0
        let loadTrackingLock = NSLock()

        // Mock the resource URL function to track async load operations
        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, _ in
            if name == "ball", ext == "usdz" {
                loadTrackingLock.lock()
                asyncLoadsTriggered += 1
                loadTrackingLock.unlock()
                // Return the actual ball.usdz to trigger real async loading
                return Bundle.module.url(forResource: name, withExtension: ext)
            }
            return nil
        }
        defer {
            LoadingSystem.shared.resourceURLFn = originalResourceURLFn
        }

        // When: Deserialize and track completion
        let completionExpectation = XCTestExpectation(description: "Completion handler invoked")
        var completionCallTime: Date?
        var entitiesAtCompletionTime = 0
        var meshLoadedStates: [Bool] = []

        deserializeScene(sceneData: sceneData, meshLoadingMode: .asyncDefault) {
            completionCallTime = Date()

            // Capture state at completion time
            let entities = getAllGameEntities()
            entitiesAtCompletionTime = entities.count

            // Check render components exist and have meshes
            for entity in entities {
                if let renderComp = scene.get(component: RenderComponent.self, for: entity) {
                    meshLoadedStates.append(!renderComp.mesh.isEmpty)
                }
                // Also check children for multi-mesh assets
                if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: entity) {
                    for childId in sceneGraph.children {
                        if let childRenderComp = scene.get(component: RenderComponent.self, for: childId) {
                            meshLoadedStates.append(!childRenderComp.mesh.isEmpty)
                        }
                    }
                }
            }

            completionExpectation.fulfill()
        }

        // Then: Wait for completion and verify it was called after all loads finished
        await fulfillment(of: [completionExpectation], timeout: 15.0)

        // Verify completion was actually called
        XCTAssertNotNil(completionCallTime, "Completion handler should have been called")

        // Verify all async loads were triggered (3 entities with ball.usdz)
        loadTrackingLock.lock()
        let triggeredCount = asyncLoadsTriggered
        loadTrackingLock.unlock()
        XCTAssertEqual(triggeredCount, entityNames.count, "Should have triggered \(entityNames.count) async loads")

        // Verify entities exist at completion time (root entities + possible children)
        XCTAssertGreaterThanOrEqual(entitiesAtCompletionTime, entityNames.count,
                                    "Should have at least \(entityNames.count) entities when completion is called")

        // Verify all meshes were loaded when completion was called
        XCTAssertFalse(meshLoadedStates.isEmpty, "Should have captured mesh load states")
        for (index, isLoaded) in meshLoadedStates.enumerated() {
            XCTAssertTrue(isLoaded, "Mesh \(index) should be loaded when completion handler is called")
        }
    }
}
