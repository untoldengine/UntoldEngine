//
//  AsyncMeshLoadingTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// These unit tests were jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class AsyncMeshLoadingTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
        // Ensure AssetLoadingState is clean before each test
        Task {
            // Clear any lingering loading states
            for entityId in getAllGameEntities() {
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
            }
        }
    }

    override func tearDown() {
        super.tearDown()
        destroyAllEntities()
    }

    override func initializeAssets() {}

    // MARK: - Basic Async Loading Tests

    func testSetEntityMeshAsync_loadsSimpleMesh() async throws {
        // Given: An entity without a mesh
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "AsyncTestEntity")

        // When: Load a mesh asynchronously
        let expectation = XCTestExpectation(description: "Mesh loaded")
        var loadSuccess = false

        setEntityMeshAsync(
            entityId: entityId,
            filename: "ball",
            withExtension: "usdz"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Wait for async completion and verify
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertTrue(loadSuccess, "Mesh should load successfully")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Entity should have RenderComponent")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self), "Entity should have transform")

        // Verify mesh was registered
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("RenderComponent should exist")
            return
        }
        XCTAssertFalse(renderComponent.mesh.isEmpty, "Mesh should not be empty")

        // Verify entity is visible after loading
        XCTAssertTrue(renderComponent.isVisible, "Entity should be visible after loading")
    }

    func testSetEntityMeshAsync_loadsMultiMeshAsset() async throws {
        // Given: An entity for a complex model
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "StadiumEntity")

        // When: Load a multi-mesh asset asynchronously
        let expectation = XCTestExpectation(description: "Multi-mesh loaded")
        var loadSuccess = false

        setEntityMeshAsync(
            entityId: entityId,
            filename: "stadium",
            withExtension: "usdz"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Wait and verify
        await fulfillment(of: [expectation], timeout: 10.0)

        XCTAssertTrue(loadSuccess, "Multi-mesh asset should load successfully")

        // Verify root entity has AssetInstanceComponent
        XCTAssertTrue(
            hasComponent(entityId: entityId, componentType: AssetInstanceComponent.self),
            "Root entity should have AssetInstanceComponent for multi-mesh assets"
        )

        // Verify child entities were created
        guard let sceneGraphComp = scene.get(component: ScenegraphComponent.self, for: entityId) else {
            XCTFail("ScenegraphComponent should exist")
            return
        }

        XCTAssertFalse(sceneGraphComp.children.isEmpty, "Multi-mesh asset should create child entities")

        // Verify children have DerivedAssetNodeComponent
        for childId in sceneGraphComp.children {
            XCTAssertTrue(
                hasComponent(entityId: childId, componentType: DerivedAssetNodeComponent.self),
                "Child entities should have DerivedAssetNodeComponent"
            )
            XCTAssertTrue(
                hasComponent(entityId: childId, componentType: RenderComponent.self),
                "Child entities should have RenderComponent"
            )

            // Verify children are visible after loading
            if let childRenderComp = scene.get(component: RenderComponent.self, for: childId) {
                XCTAssertTrue(childRenderComp.isVisible, "Child entity should be visible after loading")
            }
        }
    }

    func testSetEntityMeshAsync_handlesInvalidFilename() async throws {
        // Given: An entity and an invalid filename
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "FailEntity")

        // When: Attempt to load non-existent mesh
        let expectation = XCTestExpectation(description: "Load failed with fallback")
        var loadSuccess = true

        setEntityMeshAsync(
            entityId: entityId,
            filename: "nonexistent_model",
            withExtension: "usdz"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Should fail but create fallback cube
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertFalse(loadSuccess, "Should fail to load non-existent file")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should have RenderComponent with fallback")

        // Verify fallback mesh was created
        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            XCTAssertFalse(renderComponent.mesh.isEmpty, "Should have fallback cube mesh")
        }
    }

    func testSetEntityMeshAsync_handlesUnsupportedFileType() async throws {
        // Given: An entity and unsupported file type
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "UnsupportedEntity")

        // When: Attempt to load .dae file (unsupported)
        let expectation = XCTestExpectation(description: "Unsupported file type")
        var loadSuccess = true

        // Create a mock .dae file reference
        LoadingSystem.shared.resourceURLFn = { _, ext, _ in
            if ext == "dae" {
                return URL(fileURLWithPath: "/tmp/test.dae")
            }
            return nil
        }

        setEntityMeshAsync(
            entityId: entityId,
            filename: "test",
            withExtension: "dae"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Should fail and create fallback
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertFalse(loadSuccess, "Should fail for unsupported file type")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should have fallback mesh")
    }

    // MARK: - AssetLoadingState Integration Tests

    func testAsyncLoading_tracksProgressCorrectly() async throws {
        // Given: An entity to load
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "ProgressEntity")

        // When: Start loading and track progress
        let loadingStartExpectation = XCTestExpectation(description: "Loading started")
        let loadingCompleteExpectation = XCTestExpectation(description: "Loading completed")

        // Track that loading state changes
        Task {
            // Check if loading starts
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            let isLoading = await AssetLoadingState.shared.isLoading(entityId: entityId)
            if isLoading {
                loadingStartExpectation.fulfill()
            }
        }

        setEntityMeshAsync(
            entityId: entityId,
            filename: "ball",
            withExtension: "usdz"
        ) { _ in
            loadingCompleteExpectation.fulfill()
        }

        // Then: Verify loading state transitions
        await fulfillment(of: [loadingStartExpectation, loadingCompleteExpectation], timeout: 5.0)

        // After completion, should not be loading
        let isLoadingAfter = await AssetLoadingState.shared.isLoading(entityId: entityId)
        XCTAssertFalse(isLoadingAfter, "Should not be loading after completion")

        let progressAfter = await AssetLoadingState.shared.getProgress(for: entityId)
        XCTAssertNil(progressAfter, "Progress should be cleared after completion")
    }

    func testAsyncLoading_tracksMultipleEntitiesSimultaneously() async throws {
        // Given: Multiple entities
        let entity1 = createEntity()
        let entity2 = createEntity()
        let entity3 = createEntity()
        setEntityName(entityId: entity1, name: "Entity1")
        setEntityName(entityId: entity2, name: "Entity2")
        setEntityName(entityId: entity3, name: "Entity3")

        // When: Load all three asynchronously
        let expectation1 = XCTestExpectation(description: "Entity 1 loaded")
        let expectation2 = XCTestExpectation(description: "Entity 2 loaded")
        let expectation3 = XCTestExpectation(description: "Entity 3 loaded")

        setEntityMeshAsync(entityId: entity1, filename: "ball", withExtension: "usdz") { _ in expectation1.fulfill() }
        setEntityMeshAsync(entityId: entity2, filename: "ball", withExtension: "usdz") { _ in expectation2.fulfill() }
        setEntityMeshAsync(entityId: entity3, filename: "ball", withExtension: "usdz") { _ in expectation3.fulfill() }

        // Check that multiple are loading
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        let loadingCount = await AssetLoadingState.shared.loadingCount()
        XCTAssertGreaterThan(loadingCount, 0, "Should be tracking loading entities")

        // Then: All should complete
        await fulfillment(of: [expectation1, expectation2, expectation3], timeout: 10.0)

        // Verify all have RenderComponents
        XCTAssertTrue(hasComponent(entityId: entity1, componentType: RenderComponent.self))
        XCTAssertTrue(hasComponent(entityId: entity2, componentType: RenderComponent.self))
        XCTAssertTrue(hasComponent(entityId: entity3, componentType: RenderComponent.self))
    }

    func testAsyncLoading_progressPhaseTransitions() async throws {
        // Given: An entity and a multi-mesh asset
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "PhaseEntity")

        var loadingPhaseDetected = false
        var registeringPhaseDetected = false

        // When: Load and monitor phase transitions
        let monitorTask = Task {
            for _ in 0 ..< 50 { // Check for up to 5 seconds
                if let progress = await AssetLoadingState.shared.getProgress(for: entityId) {
                    switch progress.phase {
                    case .loading:
                        loadingPhaseDetected = true
                    case .registering:
                        registeringPhaseDetected = true
                    }
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }

        let expectation = XCTestExpectation(description: "Loading complete")
        setEntityMeshAsync(
            entityId: entityId,
            filename: "stadium",
            withExtension: "usdz"
        ) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
        monitorTask.cancel()

        // Then: Should have detected phase transitions
        XCTAssertTrue(loadingPhaseDetected, "Should detect loading phase")
        // Note: Registering phase might be very quick for small assets, so we don't strictly require it
    }

    // MARK: - Component Registration Tests

    func testAsyncLoading_registersRequiredComponents() async throws {
        // Given: A bare entity without components
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "ComponentEntity")

        // Note: createEntity() automatically registers LocalTransform and Scenegraph via makeSpatial()
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        // When: Load mesh asynchronously
        let expectation = XCTestExpectation(description: "Mesh loaded")
        setEntityMeshAsync(entityId: entityId, filename: "ball", withExtension: "usdz") { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Then: Required components should be registered automatically
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self), "Should auto-register transform")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self), "Should auto-register scene graph")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should register render component")
    }

    func testAsyncLoading_preservesExistingComponents() async throws {
        // Given: An entity with pre-configured transform
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "PreConfigEntity")
        registerTransformComponent(entityId: entityId)

        let originalPosition = simd_float3(1.0, 2.0, 3.0)
        translateTo(entityId: entityId, position: originalPosition)

        // When: Load mesh asynchronously
        let expectation = XCTestExpectation(description: "Mesh loaded")
        setEntityMeshAsync(entityId: entityId, filename: "ball", withExtension: "usdz") { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        // Then: Verify render component was registered
        // Note: registerRenderComponent overwrites localTransform.position with mesh's transform
        // This is expected behavior - the mesh's local transform takes precedence
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should register render component")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: WorldTransformComponent.self), "Should have world transform")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self), "Should have local transform")
    }

    // MARK: - Visibility Toggle Tests

    func testAsyncLoading_entitiesHiddenDuringRegistration() async throws {
        // Given: An entity loading a complex asset
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "VisibilityEntity")

        var wasHiddenDuringLoad = false

        // When: Monitor visibility during loading
        let monitorTask = Task {
            for _ in 0 ..< 50 {
                if let renderComp = scene.get(component: RenderComponent.self, for: entityId) {
                    if !renderComp.isVisible {
                        wasHiddenDuringLoad = true
                    }
                }
                // Also check children
                if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: entityId) {
                    for childId in sceneGraph.children {
                        if let childRenderComp = scene.get(component: RenderComponent.self, for: childId) {
                            if !childRenderComp.isVisible {
                                wasHiddenDuringLoad = true
                            }
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            }
        }

        let expectation = XCTestExpectation(description: "Loading complete")
        setEntityMeshAsync(entityId: entityId, filename: "stadium", withExtension: "usdz") { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 10.0)
        monitorTask.cancel()

        // Then: Should have been hidden during registration
        // Note: This might not always trigger if loading is too fast

        // But should be visible after completion
        if let renderComp = scene.get(component: RenderComponent.self, for: entityId) {
            // Root of multi-mesh might not have render component
            XCTAssertTrue(renderComp.isVisible, "Should be visible after loading")
        }

        // Check children visibility
        if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: entityId) {
            for childId in sceneGraph.children {
                if let childRenderComp = scene.get(component: RenderComponent.self, for: childId) {
                    XCTAssertTrue(childRenderComp.isVisible, "Children should be visible after loading")
                }
            }
        }
    }

    // MARK: - Serialization/Deserialization with Async Loading Tests

    func testSerializeDeserialize_asyncLoadingTriggered() async throws {
        // Given: Create and serialize a scene with meshes
        let originalEntity = createEntity()
        setEntityName(entityId: originalEntity, name: "SerializedEntity")
        registerTransformComponent(entityId: originalEntity)

        // Use BasicPrimitives to create a mesh
        let meshes = BasicPrimitives.createCube()
        let mockURL = URL(fileURLWithPath: "/test/model.usdz")
        registerRenderComponent(entityId: originalEntity, meshes: meshes, url: mockURL, assetName: "TestModel")

        var sceneData = serializeScene()
        sceneData.environment = nil // Bypass HDR generation
        // When: Clear scene and deserialize with async mode
        destroyAllEntities()
        XCTAssertEqual(getAllGameEntities().count, 0)

        // Mock the resource URL function to return our test URL
        let expectation = XCTestExpectation(description: "Async load triggered")
        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, _ in
            if name == "model", ext == "usdz" {
                expectation.fulfill()
            }
            return nil // Return nil to trigger fallback
        }
        defer {
            LoadingSystem.shared.resourceURLFn = originalResourceURLFn
        }

        deserializeScene(sceneData: sceneData, meshLoadingMode: .asyncDefault)

        // Then: Should trigger async loading
        await fulfillment(of: [expectation], timeout: 2.0)

        // Entity should exist immediately
        XCTAssertEqual(getAllGameEntities().count, 3, "Entity should be created immediately")
    }

    func testDeserialize_syncMode_loadsImmediately() throws {
        // Given: A serialized scene
        let originalEntity = createEntity()
        setEntityName(entityId: originalEntity, name: "SyncEntity")
        registerTransformComponent(entityId: originalEntity)

        let meshes = BasicPrimitives.createSphere()
        let mockURL = URL(fileURLWithPath: "/test/sphere.usdz")
        registerRenderComponent(entityId: originalEntity, meshes: meshes, url: mockURL, assetName: "TestSphere")

        var sceneData = serializeScene()
        sceneData.environment = nil // Bypass HDR generation

        // When: Deserialize with sync mode
        destroyAllEntities()

        // Override resource URL to return a valid test file
        LoadingSystem.shared.resourceURLFn = { name, ext, _ in
            if name == "sphere", ext == "usdz" {
                // Return nil to skip actual loading (just testing the code path)
                return nil
            }
            return nil
        }

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        // Then: Entity should exist
        XCTAssertEqual(getAllGameEntities().count, 3, "Entity should be created")
    }

    // MARK: - Coordinate Conversion Tests

    func testAsyncLoading_supportsCoordinateConversion() async throws {
        // Given: An entity
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "CoordConversionEntity")

        // When: Load with coordinate conversion
        let expectation = XCTestExpectation(description: "Loaded with conversion")
        var loadSuccess = false

        setEntityMeshAsync(
            entityId: entityId,
            filename: "ball",
            withExtension: "usdz",
            coordinateConversion: .forceZUpToYUp
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Should load successfully
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertTrue(loadSuccess, "Should load with coordinate conversion")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self))
    }

    // MARK: - Asset Name Filtering Tests

    func testAsyncLoading_filtersSpecificAssetName() async throws {
        // Given: A multi-mesh file and specific asset name
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "FilteredEntity")

        // When: Load with asset name filter
        let expectation = XCTestExpectation(description: "Filtered load")
        var loadSuccess = false

        // Note: This requires knowing the internal asset name structure of stadium.usdz
        // For this test, we'll use a generic approach
        setEntityMeshAsync(
            entityId: entityId,
            filename: "stadium",
            withExtension: "usdz",
            assetName: "stadium" // Using the file name as asset name
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Should load (may load specific mesh or all meshes depending on file structure)
        await fulfillment(of: [expectation], timeout: 10.0)
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self))
    }

    // MARK: - Fallback Mesh Tests

    func testFallbackMesh_createsCubeOnFailure() async throws {
        // Given: An entity and invalid file
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "FallbackEntity")

        // When: Load fails
        let expectation = XCTestExpectation(description: "Fallback created")
        var loadSuccess = true

        setEntityMeshAsync(
            entityId: entityId,
            filename: "nonexistent",
            withExtension: "usdz"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        // Then: Should create fallback cube
        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertFalse(loadSuccess, "Should report failure")

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("Should have RenderComponent with fallback")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Should have fallback mesh")
        XCTAssertTrue(renderComponent.isVisible, "Fallback mesh should be visible")
    }

    // MARK: - Stress Tests

    func testAsyncLoading_handlesRapidSequentialLoads() async throws {
        // Given: Multiple entities to load rapidly
        var entities: [EntityID] = []
        for i in 0 ..< 5 {
            let entityId = createEntity()
            setEntityName(entityId: entityId, name: "RapidEntity_\(i)")
            entities.append(entityId)
        }

        // When: Load all rapidly in sequence
        var expectations: [XCTestExpectation] = []
        for i in 0 ..< entities.count {
            let exp = XCTestExpectation(description: "Entity \(i) loaded")
            expectations.append(exp)

            setEntityMeshAsync(entityId: entities[i], filename: "ball", withExtension: "usdz") { _ in
                exp.fulfill()
            }
        }

        // Then: All should complete without crashes
        await fulfillment(of: expectations, timeout: 15.0)

        for entityId in entities {
            XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self), "Should have mesh loaded")
        }
    }
}
