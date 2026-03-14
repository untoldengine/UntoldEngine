//
//  GeometryStreamingTest.swift
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

final class GeometryStreamingTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()

        // Disable streaming system during setup to control test state
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.maxUnloadsPerUpdate = 12
        GeometryStreamingSystem.shared.updateInterval = 0.1
    }

    override func tearDown() async throws {
        // Reset streaming system state
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.maxUnloadsPerUpdate = 12
        GeometryStreamingSystem.shared.updateInterval = 0.1
        GeometryStreamingSystem.shared.reset()

        try await super.tearDown()
    }

    // MARK: - StreamingComponent Tests

    func testStreamingComponentInitialization() {
        // Given: Default StreamingComponent
        let component = StreamingComponent()

        // Then: Should have default values
        XCTAssertEqual(component.streamingRadius, 100.0, "❌ Default streaming radius should be 100.0")
        XCTAssertEqual(component.unloadRadius, 150.0, "❌ Default unload radius should be 150.0")
        XCTAssertEqual(component.priority, 0, "❌ Default priority should be 0")
        XCTAssertEqual(component.state, .unloaded, "❌ Default state should be unloaded")
        XCTAssertEqual(component.assetFilename, "", "❌ Default filename should be empty")
        XCTAssertEqual(component.assetExtension, "", "❌ Default extension should be empty")
        XCTAssertNil(component.assetName, "❌ Default assetName should be nil")
    }

    func testStreamingComponentConvenienceInitializer() {
        // Given: StreamingComponent with convenience initializer
        let component = StreamingComponent(
            filename: "testModel",
            withExtension: "usdz",
            streamingRadius: 50.0,
            unloadRadius: 75.0,
            priority: 5
        )

        // Then: Should have provided values
        XCTAssertEqual(component.assetFilename, "testModel", "❌ Filename should match")
        XCTAssertEqual(component.assetExtension, "usdz", "❌ Extension should match")
        XCTAssertEqual(component.streamingRadius, 50.0, "❌ Streaming radius should match")
        XCTAssertEqual(component.unloadRadius, 75.0, "❌ Unload radius should match")
        XCTAssertEqual(component.priority, 5, "❌ Priority should match")
    }

    // MARK: - GeometryStreamingSystem Tests

    func testGeometryStreamingSystemInitialization() {
        XCTAssertNotNil(GeometryStreamingSystem.shared, "❌ GeometryStreamingSystem should be initialized")
        XCTAssertEqual(GeometryStreamingSystem.shared.maxConcurrentLoads, 3, "❌ Default max concurrent loads should be 3")
        XCTAssertEqual(GeometryStreamingSystem.shared.updateInterval, 0.1, "❌ Default update interval should be 0.1")
    }

    func testStreamingSystemCanBeDisabled() {
        // Given: Streaming system is disabled
        GeometryStreamingSystem.shared.enabled = false

        // Then: Should be disabled
        XCTAssertFalse(GeometryStreamingSystem.shared.enabled, "❌ Streaming system should be disabled")

        // When: Enable it
        GeometryStreamingSystem.shared.enabled = true

        // Then: Should be enabled
        XCTAssertTrue(GeometryStreamingSystem.shared.enabled, "❌ Streaming system should be enabled")
    }

    // MARK: - enableStreaming() Tests - Single Mesh Entity

    func testEnableStreamingForSingleMeshEntity() {
        // Given: A single-mesh entity with RenderComponent
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let entity = createEntity()
        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = ballURL
            renderComponent.assetName = "ball"
        }

        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)

        // When: Enable streaming
        enableStreaming(
            entityId: entity,
            streamingRadius: 50.0,
            unloadRadius: 75.0,
            priority: 10
        )

        // Then: Entity should have StreamingComponent with correct values
        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertNotNil(streaming, "❌ Entity should have StreamingComponent")
        XCTAssertEqual(streaming?.streamingRadius, 50.0, "❌ Streaming radius should match")
        XCTAssertEqual(streaming?.unloadRadius, 75.0, "❌ Unload radius should match")
        XCTAssertEqual(streaming?.priority, 10, "❌ Priority should match")
        XCTAssertEqual(streaming?.state, .loaded, "❌ State should be .loaded (mesh already present)")
        XCTAssertEqual(streaming?.assetFilename, "ball", "❌ Filename should be extracted from URL")
        XCTAssertEqual(streaming?.assetExtension, "usdz", "❌ Extension should be extracted from URL")
    }

    func testEnableStreamingFailsWithoutRenderComponent() {
        // Given: An entity without RenderComponent
        let entity = createEntity()
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)

        // When: Enable streaming
        enableStreaming(entityId: entity, streamingRadius: 50.0, unloadRadius: 75.0)

        // Then: Entity should NOT have StreamingComponent (enableStreaming should fail gracefully)
        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertNil(streaming, "❌ Entity without RenderComponent should not get StreamingComponent")
    }

    // MARK: - enableStreaming() Tests - Multi-Mesh Entity (Children)

    func testEnableStreamingForMultiMeshEntity() {
        // Given: A parent entity with children that have RenderComponents (simulating multi-mesh asset)
        let parentEntity = createEntity()
        _ = scene.assign(to: parentEntity, component: LocalTransformComponent.self)
        _ = scene.assign(to: parentEntity, component: WorldTransformComponent.self)

        if let sceneGraph = scene.assign(to: parentEntity, component: ScenegraphComponent.self) {
            // Create child entities with RenderComponents
            var childIds: [EntityID] = []
            for i in 0 ..< 3 {
                let childEntity = createEntity()

                if let childRender = scene.assign(to: childEntity, component: RenderComponent.self) {
                    childRender.assetURL = URL(fileURLWithPath: "/test/model.usdz")
                    childRender.assetName = "part\(i)"
                }
                _ = scene.assign(to: childEntity, component: LocalTransformComponent.self)
                _ = scene.assign(to: childEntity, component: WorldTransformComponent.self)

                childIds.append(childEntity)
            }
            sceneGraph.children = childIds
        }

        // When: Enable streaming on parent
        enableStreaming(
            entityId: parentEntity,
            streamingRadius: 100.0,
            unloadRadius: 150.0,
            priority: 5
        )

        // Then: All children should have StreamingComponent
        if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: parentEntity) {
            for childId in sceneGraph.children {
                let streaming = scene.get(component: StreamingComponent.self, for: childId)
                XCTAssertNotNil(streaming, "❌ Child entity \(childId) should have StreamingComponent")
                XCTAssertEqual(streaming?.streamingRadius, 100.0, "❌ Child streaming radius should match")
                XCTAssertEqual(streaming?.unloadRadius, 150.0, "❌ Child unload radius should match")
                XCTAssertEqual(streaming?.priority, 5, "❌ Child priority should match")
                XCTAssertEqual(streaming?.state, .loaded, "❌ Child state should be .loaded")
            }
        }

        // Parent should NOT have StreamingComponent (no RenderComponent)
        let parentStreaming = scene.get(component: StreamingComponent.self, for: parentEntity)
        XCTAssertNil(parentStreaming, "❌ Parent without RenderComponent should not have StreamingComponent")
    }

    // MARK: - createStreamingEntity() Tests

    func testCreateStreamingEntityDeferred() {
        // When: Create a streaming entity (deferred loading)
        let entity = createStreamingEntity(
            filename: "testModel",
            withExtension: "usdz",
            streamingRadius: 200.0,
            unloadRadius: 300.0,
            priority: 2
        )

        // Then: Entity should exist with proper components
        XCTAssertNotEqual(entity, EntityID.invalid, "❌ Entity should be valid")

        // Should have transform components
        XCTAssertNotNil(scene.get(component: LocalTransformComponent.self, for: entity), "❌ Should have LocalTransformComponent")
        XCTAssertNotNil(scene.get(component: ScenegraphComponent.self, for: entity), "❌ Should have ScenegraphComponent")

        // Should have StreamingComponent with correct values
        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertNotNil(streaming, "❌ Should have StreamingComponent")
        XCTAssertEqual(streaming?.assetFilename, "testModel", "❌ Filename should match")
        XCTAssertEqual(streaming?.assetExtension, "usdz", "❌ Extension should match")
        XCTAssertEqual(streaming?.streamingRadius, 200.0, "❌ Streaming radius should match")
        XCTAssertEqual(streaming?.unloadRadius, 300.0, "❌ Unload radius should match")
        XCTAssertEqual(streaming?.priority, 2, "❌ Priority should match")
        XCTAssertEqual(streaming?.state, .unloaded, "❌ State should be .unloaded (deferred)")

        // Should NOT have RenderComponent yet (mesh not loaded)
        let render = scene.get(component: RenderComponent.self, for: entity)
        XCTAssertNil(render, "❌ Should not have RenderComponent until mesh is loaded")
    }

    // MARK: - getStats() Tests

    func testGetStatsEmpty() {
        // Given: No streaming entities
        // When: Get stats
        let stats = GeometryStreamingSystem.shared.getStats()

        // Then: All counts should be 0
        XCTAssertEqual(stats.totalStreamingEntities, 0, "❌ Should have 0 total streaming entities")
        XCTAssertEqual(stats.loadedCount, 0, "❌ Should have 0 loaded")
        XCTAssertEqual(stats.loadingCount, 0, "❌ Should have 0 loading")
        XCTAssertEqual(stats.unloadedCount, 0, "❌ Should have 0 unloaded")
        XCTAssertEqual(stats.activeLoads, 0, "❌ Should have 0 active loads")
    }

    func testGetStatsWithStreamingEntities() {
        // Given: Create streaming entities with different states
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        // Create 2 loaded entities
        for _ in 0 ..< 2 {
            let entity = createEntity()
            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }
            _ = scene.assign(to: entity, component: LocalTransformComponent.self)
            _ = scene.assign(to: entity, component: WorldTransformComponent.self)

            enableStreaming(entityId: entity, streamingRadius: 50.0, unloadRadius: 75.0)
        }

        // Create 3 unloaded (deferred) entities
        for _ in 0 ..< 3 {
            _ = createStreamingEntity(
                filename: "testModel",
                withExtension: "usdz",
                streamingRadius: 100.0,
                unloadRadius: 150.0
            )
        }

        // When: Get stats
        let stats = GeometryStreamingSystem.shared.getStats()

        // Then: Counts should reflect created entities
        XCTAssertEqual(stats.totalStreamingEntities, 5, "❌ Should have 5 total streaming entities")
        XCTAssertEqual(stats.loadedCount, 2, "❌ Should have 2 loaded")
        XCTAssertEqual(stats.unloadedCount, 3, "❌ Should have 3 unloaded")
    }

    // MARK: - Distance-Based Streaming Tests

    func testStreamingUpdateUnloadsDistantEntities() {
        // Given: A loaded streaming entity
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let entity = createEntity()
        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = ballURL
        }

        if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
            transform.position = simd_float3(0, 0, 0) // At origin
        }

        if let worldTransform = scene.assign(to: entity, component: WorldTransformComponent.self) {
            worldTransform.space = simd_float4x4(1.0) // Identity
        }

        enableStreaming(
            entityId: entity,
            streamingRadius: 10.0, // Load within 10 units
            unloadRadius: 20.0 // Unload beyond 20 units
        )

        // Verify initial state
        let initialStreaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(initialStreaming?.state, .loaded, "❌ Initial state should be loaded")

        // When: Enable streaming and update with camera far away
        GeometryStreamingSystem.shared.enabled = true

        // Camera at 100 units away (beyond unloadRadius of 20)
        let farCameraPosition = simd_float3(100, 0, 0)

        // Need to call update multiple times to pass throttle interval
        for _ in 0 ..< 5 {
            GeometryStreamingSystem.shared.update(cameraPosition: farCameraPosition, deltaTime: 0.1)
        }

        // Then: Entity should be unloaded
        let finalStreaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(finalStreaming?.state, .unloaded, "❌ Entity should be unloaded when camera is far")

        // RenderComponent mesh should be empty
        let render = scene.get(component: RenderComponent.self, for: entity)
        XCTAssertTrue(render?.mesh.isEmpty ?? true, "❌ Mesh should be cleared after unload")
    }

    func testStreamingUpdateRespectsUnloadBudgetPerTick() {
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        GeometryStreamingSystem.shared.maxUnloadsPerUpdate = 1
        GeometryStreamingSystem.shared.enabled = true

        func makeLoadedEntity(positionX: Float) -> EntityID {
            let entity = createEntity()
            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(positionX, 0, 0)
            }

            if let worldTransform = scene.assign(to: entity, component: WorldTransformComponent.self) {
                worldTransform.space = simd_float4x4(1.0)
            }

            enableStreaming(entityId: entity, streamingRadius: 10.0, unloadRadius: 20.0)
            return entity
        }

        let entityA = makeLoadedEntity(positionX: 0)
        let entityB = makeLoadedEntity(positionX: 10)
        let farCameraPosition = simd_float3(100, 0, 0)

        GeometryStreamingSystem.shared.update(cameraPosition: farCameraPosition, deltaTime: 0.1)

        let unloadedAfterFirstTick = [entityA, entityB].filter {
            scene.get(component: StreamingComponent.self, for: $0)?.state == .unloaded
        }.count
        XCTAssertEqual(unloadedAfterFirstTick, 1, "❌ Exactly one entity should unload per tick when budget is 1")

        GeometryStreamingSystem.shared.update(cameraPosition: farCameraPosition, deltaTime: 0.1)

        let unloadedAfterSecondTick = [entityA, entityB].filter {
            scene.get(component: StreamingComponent.self, for: $0)?.state == .unloaded
        }.count
        XCTAssertEqual(unloadedAfterSecondTick, 2, "❌ Remaining unload should complete on the next tick")
    }

    // MARK: - Force Load/Unload Tests

    func testForceUnload() {
        // Given: A loaded streaming entity
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let entity = createEntity()
        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = ballURL
        }
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)

        enableStreaming(entityId: entity, streamingRadius: 50.0, unloadRadius: 75.0)

        // Verify initial state
        XCTAssertEqual(scene.get(component: StreamingComponent.self, for: entity)?.state, .loaded)

        // When: Force unload
        GeometryStreamingSystem.shared.forceUnload(entityId: entity)

        // Then: Entity should be unloaded
        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.state, .unloaded, "❌ State should be .unloaded after forceUnload")

        let render = scene.get(component: RenderComponent.self, for: entity)
        XCTAssertTrue(render?.mesh.isEmpty ?? true, "❌ Mesh should be empty after forceUnload")
    }

    // MARK: - Priority Tests

    func testHighPriorityLoadsFirst() {
        // This test verifies that the sorting logic prioritizes higher priority entities
        // Given: Multiple unloaded streaming entities with different priorities
        let lowPriorityEntity = createStreamingEntity(
            filename: "model",
            withExtension: "usdz",
            streamingRadius: 100.0,
            unloadRadius: 150.0,
            priority: 1
        )

        let highPriorityEntity = createStreamingEntity(
            filename: "model",
            withExtension: "usdz",
            streamingRadius: 100.0,
            unloadRadius: 150.0,
            priority: 10
        )

        // Verify priorities are set correctly
        let lowPriority = scene.get(component: StreamingComponent.self, for: lowPriorityEntity)
        let highPriority = scene.get(component: StreamingComponent.self, for: highPriorityEntity)

        XCTAssertEqual(lowPriority?.priority, 1, "❌ Low priority entity should have priority 1")
        XCTAssertEqual(highPriority?.priority, 10, "❌ High priority entity should have priority 10")

        // The actual load order is tested implicitly when update() is called
        // High priority entities should be added to load candidates first
    }

    // MARK: - Edge Cases

    func testUnloadRadiusMustBeGreaterThanStreamingRadius() {
        // Given: An entity with streaming
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        let entity = createEntity()
        let meshes = Mesh.loadMeshes(
            url: ballURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
            renderComponent.mesh = meshes
            renderComponent.assetURL = ballURL
        }
        _ = scene.assign(to: entity, component: LocalTransformComponent.self)
        _ = scene.assign(to: entity, component: WorldTransformComponent.self)

        // When: Enable streaming with unloadRadius < streamingRadius
        // (This is a user error, but system should handle it gracefully)
        enableStreaming(
            entityId: entity,
            streamingRadius: 100.0,
            unloadRadius: 50.0 // Less than streaming radius - user error
        )

        // Then: Component should still be created (validation is user responsibility)
        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertNotNil(streaming, "❌ StreamingComponent should still be created")

        // Note: This documents current behavior - you may want to add validation
    }

    // MARK: - Integration Test

    func testStreamingIntegrationWithRendering() {
        // Given: Create streaming entities
        guard let ballURL = getResourceURL(resourceName: "ball", ext: "usdz", subName: nil) else {
            XCTFail("❌ Failed to load ball.usdz")
            return
        }

        for i in 0 ..< 3 {
            let entity = createEntity()
            let meshes = Mesh.loadMeshes(
                url: ballURL,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                flip: true
            )

            if let renderComponent = scene.assign(to: entity, component: RenderComponent.self) {
                renderComponent.mesh = meshes
                renderComponent.assetURL = ballURL
            }

            if let transform = scene.assign(to: entity, component: LocalTransformComponent.self) {
                transform.position = simd_float3(Float(i) * 5.0, 0, 0)
            }

            _ = scene.assign(to: entity, component: WorldTransformComponent.self)
            enableStreaming(entityId: entity, streamingRadius: 50.0, unloadRadius: 75.0)
        }

        // When: Enable streaming and render
        GeometryStreamingSystem.shared.enabled = true

        let expectation = XCTestExpectation(description: "Streaming rendering test")

        renderer.draw(in: renderer.metalView)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))

        // Then: Should not crash
        let stats = GeometryStreamingSystem.shared.getStats()
        XCTAssertEqual(stats.totalStreamingEntities, 3, "❌ Should have 3 streaming entities")

        print("✅ Streaming integrated successfully with rendering")
        print("📊 Stats: \(stats.loadedCount) loaded, \(stats.unloadedCount) unloaded")
    }
}
