//
//  AsyncLoadingSystemTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class AsyncLoadingSystemTest: BaseRenderSetup {
    override func setUp() async throws {
        // Set up asset base path
        let bundleURL = Bundle.module.resourceURL
        assetBasePath = bundleURL
    }

    override func tearDown() {
        super.tearDown()

        destroyAllEntities()
    }

    override func initializeAssets() {}

    // MARK: - AssetLoadingState Tests

    func test_assetLoadingState_startsWithNoActivity() async throws {
        // When/Then: Should report no loading
        let isLoading = await AssetLoadingState.shared.isLoadingAny()
        let count = await AssetLoadingState.shared.loadingCount()

        // Note: Might have loading from other tests, just verify API works
        XCTAssertEqual(isLoading, count > 0, "Loading state should be consistent")
    }

    func test_assetLoadingState_tracksLoadingPhase() async throws {
        // Given: Start loading for an entity
        let entityId: EntityID = 42
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: "test.usdz", totalMeshes: 10)

        // When: Update progress in loading phase
        await AssetLoadingState.shared.updateProgress(
            entityId: entityId,
            currentMesh: 5,
            totalMeshes: 10,
            phase: .loading
        )

        // Then: Should report loading
        let isLoading = await AssetLoadingState.shared.isLoadingAny()
        XCTAssertTrue(isLoading, "Should be loading")

        let progress = await AssetLoadingState.shared.getProgress(for: entityId)
        XCTAssertNotNil(progress, "Progress should exist")
        XCTAssertEqual(progress?.currentMesh, 5)
        XCTAssertEqual(progress?.totalMeshes, 10)
        XCTAssertEqual(progress?.phase, .loading)

        let summary = await AssetLoadingState.shared.loadingSummary()
        XCTAssertFalse(summary.isEmpty, "Summary should exist")
        XCTAssertTrue(summary.contains("Loading"), "Summary should mention loading")

        // Clean up
        await AssetLoadingState.shared.finishLoading(entityId: entityId)
    }

    func test_assetLoadingState_tracksRegisteringPhase() async throws {
        // Given: Start loading and move to registering phase
        let entityId: EntityID = 100
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: "test.usdz", totalMeshes: 100)

        // When: Update to registering phase
        await AssetLoadingState.shared.updateProgress(
            entityId: entityId,
            currentMesh: 50,
            totalMeshes: 100,
            phase: .registering
        )

        // Then: Should show registering phase
        let progress = await AssetLoadingState.shared.getProgress(for: entityId)
        XCTAssertEqual(progress?.phase, .registering)

        let summary = await AssetLoadingState.shared.loadingSummary()
        XCTAssertTrue(summary.contains("Registering"), "Summary should mention registering")

        // Clean up
        await AssetLoadingState.shared.finishLoading(entityId: entityId)
    }

    func test_assetLoadingState_finishLoading_removesEntity() async throws {
        // Given: Loading entity
        let entityId: EntityID = 200
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: "test.usdz", totalMeshes: 10)

        let isLoadingBefore = await AssetLoadingState.shared.isLoading(entityId: entityId)
        XCTAssertTrue(isLoadingBefore, "Should be loading before finish")

        // When: Finish loading
        await AssetLoadingState.shared.finishLoading(entityId: entityId)

        // Then: Should no longer be loading
        let isLoadingAfter = await AssetLoadingState.shared.isLoading(entityId: entityId)
        XCTAssertFalse(isLoadingAfter, "Should not be loading after finish")

        let progress = await AssetLoadingState.shared.getProgress(for: entityId)
        XCTAssertNil(progress, "Progress should be removed")
    }

    func test_assetLoadingState_tracksMultipleEntities() async throws {
        // Given: Multiple entities loading
        await AssetLoadingState.shared.startLoading(entityId: 1, filename: "model1.usdz", totalMeshes: 100)
        await AssetLoadingState.shared.startLoading(entityId: 2, filename: "model2.usdz", totalMeshes: 100)
        await AssetLoadingState.shared.startLoading(entityId: 3, filename: "model3.usdz", totalMeshes: 100)

        // When: Update progress
        await AssetLoadingState.shared.updateProgress(entityId: 1, currentMesh: 10, totalMeshes: 100, phase: .loading)
        await AssetLoadingState.shared.updateProgress(entityId: 2, currentMesh: 50, totalMeshes: 100, phase: .registering)
        await AssetLoadingState.shared.updateProgress(entityId: 3, currentMesh: 75, totalMeshes: 100, phase: .registering)

        // Then: Should track all entities
        let progress1 = await AssetLoadingState.shared.getProgress(for: 1)
        let progress2 = await AssetLoadingState.shared.getProgress(for: 2)
        let progress3 = await AssetLoadingState.shared.getProgress(for: 3)

        XCTAssertEqual(progress1?.currentMesh, 10)
        XCTAssertEqual(progress2?.currentMesh, 50)
        XCTAssertEqual(progress3?.currentMesh, 75)

        let isLoading = await AssetLoadingState.shared.isLoadingAny()
        XCTAssertTrue(isLoading, "Should be loading with multiple entities")

        // Clean up
        await AssetLoadingState.shared.finishLoading(entityId: 1)
        await AssetLoadingState.shared.finishLoading(entityId: 2)
        await AssetLoadingState.shared.finishLoading(entityId: 3)
    }

    // MARK: - Async Mesh Loading Tests

    func test_loadMeshesAsync_loadsSimpleModel() async throws {
        // Given: A simple USDZ model
        guard let url = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            throw XCTSkip("Could not find ball.usdz - skipping test")
        }

        // When: Load meshes asynchronously
        var progressUpdates: [(Int, Int)] = []
        let meshes = await Mesh.loadMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true,
            coordinateConversion: .autoDetect,
            progressHandler: { current, total in
                progressUpdates.append((current, total))
            }
        )

        // Then: Should load successfully
        XCTAssertFalse(meshes.isEmpty, "Should load at least one mesh")
        XCTAssertFalse(progressUpdates.isEmpty, "Should receive progress updates")

        // Verify final progress matches mesh count
        if let lastUpdate = progressUpdates.last {
            XCTAssertEqual(lastUpdate.0, lastUpdate.1, "Final progress should show completion")
        }
    }

    func test_loadMeshesAsync_providesAccurateProgress() async throws {
        // Given: A model with known mesh count
        guard let url = getResourceURL(resourceName: "stadium", ext: "usdz", subName: nil) else {
            throw XCTSkip("Could not find stadium.usdz - skipping test")
        }

        // When: Load with progress tracking
        var progressUpdates: [(Int, Int)] = []
        _ = await Mesh.loadMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true,
            coordinateConversion: .autoDetect,
            progressHandler: { current, total in
                progressUpdates.append((current, total))
            }
        )

        // Then: Progress should be monotonically increasing
        for i in 0 ..< progressUpdates.count - 1 {
            let (current, total) = progressUpdates[i]
            let (nextCurrent, nextTotal) = progressUpdates[i + 1]

            XCTAssertEqual(total, nextTotal, "Total should remain constant")
            XCTAssertLessThanOrEqual(current, nextCurrent, "Current should increase")
            XCTAssertLessThanOrEqual(current, total, "Current should not exceed total")
        }
    }

    func test_loadSceneMeshesAsync_loadsMultipleMeshes() async throws {
        // Given: A model file
        guard let url = getResourceURL(resourceName: "stadium", ext: "usdz", subName: nil) else {
            throw XCTSkip("Could not find stadium.usdz - skipping test")
        }

        // When: Load scene meshes asynchronously
        let meshGroups = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: .autoDetect
        ) { _, _ in
            // Progress callback
        }

        // Then: Should load successfully
        XCTAssertFalse(meshGroups.isEmpty, "Should load mesh groups")
    }

    func test_loadMeshesAsync_handlesMultipleObjects() async throws {
        // Given: A model file with multiple objects
        guard let url = getResourceURL(resourceName: "stadium", ext: "usdz", subName: nil) else {
            throw XCTSkip("Could not find stadium.usdz - skipping test")
        }

        // When: Load meshes
        let meshes = await Mesh.loadMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true,
            coordinateConversion: .autoDetect
        )

        // Then: Should load multiple meshes
        XCTAssertFalse(meshes.isEmpty, "Should load meshes from multi-object file")
    }
    /*
     func testDeserializeSceneTriggersAsyncMeshLoad() {

         // Build a scene with a renderable entity, serialize, then deserialize.
         let expectedName = "TestModel"
         let expectedExt = "usdz"
         let expectedURL = URL(fileURLWithPath: "/tmp/\(expectedName).\(expectedExt)")

         let entityId = createEntity()
         setEntityName(entityId: entityId, name: "AsyncEntity")
         registerTransformComponent(entityId: entityId)
         registerSceneGraphComponent(entityId: entityId)

         let meshes = BasicPrimitives.createCube()
         registerRenderComponent(entityId: entityId, meshes: meshes, url: expectedURL, assetName: expectedName)

         var sceneData = serializeScene()
         sceneData.environment = nil // Bypass HDR generation
         destroyAllEntities()

         let expectation = XCTestExpectation(description: "Async mesh load requested")
         let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
         LoadingSystem.shared.resourceURLFn = { name, ext, _ in
             if name == expectedName, ext == expectedExt {
                 expectation.fulfill()
             }
             return nil // Return nil to trigger fallback mesh creation
         }
         defer {
             LoadingSystem.shared.resourceURLFn = originalResourceURLFn
         }

         // Deserialize with async mode (default)
         deserializeScene(sceneData: sceneData, meshLoadingMode: .asyncDefault)

         // Entity should be created immediately even with async loading
         XCTAssertEqual(getAllGameEntities().count, 3, "Entity should be created immediately")

         // Wait for the async mesh load to be requested
         wait(for: [expectation], timeout: 2.0)
     }
     */
}
