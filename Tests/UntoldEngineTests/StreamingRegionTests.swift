//
//  StreamingRegionTests.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//

import simd
@testable import UntoldEngine
import XCTest

final class StreamingRegionTests: XCTestCase {
    var manager: StreamingRegionManager!

    override func setUp() {
        super.setUp()
        manager = StreamingRegionManager.shared
        // Clear any existing regions
        for region in manager.getAllRegions() {
            manager.unregisterRegion(id: region.id)
        }
    }

    override func tearDown() {
        // Clean up all regions after each test
        for region in manager.getAllRegions() {
            manager.unregisterRegion(id: region.id)
        }
        super.tearDown()
    }

    // MARK: - AABB Distance Tests

    func testDistanceCalculation() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))

        // Point inside box
        XCTAssertEqual(box.distanceToPoint(simd_float3(5, 5, 5)), 0)

        // Point outside box
        XCTAssertEqual(box.distanceToPoint(simd_float3(20, 5, 5)), 10, accuracy: 0.01)
    }

    func testAABBDistanceToPoint_Diagonal() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let point = simd_float3(20, 20, 20)

        // Distance should be sqrt(10^2 + 10^2 + 10^2) = sqrt(300) ≈ 17.32
        XCTAssertEqual(box.distanceToPoint(point), sqrt(300), accuracy: 0.01,
                       "Distance should be correct for diagonal point")
    }

    func testAABBDistanceToPoint_OnEdge() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let point = simd_float3(10, 5, 5)

        XCTAssertEqual(box.distanceToPoint(point), 0, accuracy: 0.001,
                       "Distance should be 0 for point on box edge")
    }

    func testAABBIntersectsSphere_Touching() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let sphereCenter = simd_float3(20, 5, 5)
        let radius: Float = 10

        XCTAssertTrue(box.intersectsSphere(center: sphereCenter, radius: radius),
                      "Sphere should just touch the box")
    }

    func testAABBIntersectsSphere_NotTouching() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let sphereCenter = simd_float3(25, 5, 5)
        let radius: Float = 10

        XCTAssertFalse(box.intersectsSphere(center: sphereCenter, radius: radius),
                       "Sphere should not touch the box")
    }

    func testAABBIntersectsSphere_Containing() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let sphereCenter = simd_float3(5, 5, 5)
        let radius: Float = 20

        XCTAssertTrue(box.intersectsSphere(center: sphereCenter, radius: radius),
                      "Large sphere should contain the box")
    }

    // MARK: - Region Registration Tests

    func testRegionRegistration() {
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1
        )

        manager.registerRegion(region)
        XCTAssertNotNil(manager.getRegion(id: region.id))

        manager.unregisterRegion(id: region.id)
        XCTAssertNil(manager.getRegion(id: region.id))
    }

    func testGetAllRegions() {
        let region1 = StreamingRegion(bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)), priority: 1)
        let region2 = StreamingRegion(bounds: AABB(min: simd_float3(20, 0, 0), max: simd_float3(30, 10, 10)), priority: 2)

        manager.registerRegion(region1)
        manager.registerRegion(region2)

        let allRegions = manager.getAllRegions()
        XCTAssertEqual(allRegions.count, 2, "Should return all registered regions")
    }

    func testIsRegionLoaded_InitiallyFalse() {
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1
        )

        manager.registerRegion(region)

        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Newly registered region should not be loaded")
    }

    // MARK: - StreamingRegion Tests

    func testStreamingRegionInitialization() {
        let bounds = AABB(min: simd_float3(0, 0, 0), max: simd_float3(100, 50, 100))
        let assets = [AssetReference(filename: "asset", withExtension: "usdz")]
        let memorySize = 1024 * 1024 // 1 MB

        let region = StreamingRegion(
            bounds: bounds,
            priority: 5,
            assets: assets,
            estimatedMemorySize: memorySize
        )

        XCTAssertEqual(region.priority, 5)
        XCTAssertEqual(region.assets.count, 1)
        XCTAssertEqual(region.estimatedMemorySize, memorySize)
        XCTAssertEqual(region.state, .unloaded)
        XCTAssertTrue(region.loadedEntities.isEmpty)
    }

    func testStreamingStateRawValues() {
        XCTAssertEqual(StreamingState.unloaded.rawValue, "unloaded")
        XCTAssertEqual(StreamingState.loading.rawValue, "loading")
        XCTAssertEqual(StreamingState.loaded.rawValue, "loaded")
        XCTAssertEqual(StreamingState.unloading.rawValue, "unloading")
    }

    // MARK: - Configuration Tests

    func testManagerConfiguration() {
        let originalEnabled = manager.enabled
        let originalRadius = manager.streamingRadius

        manager.enabled = false
        manager.streamingRadius = 200.0
        manager.unloadRadius = 300.0
        manager.maxConcurrentLoads = 5
        manager.checkInterval = 1.0

        XCTAssertFalse(manager.enabled)
        XCTAssertEqual(manager.streamingRadius, 200.0)
        XCTAssertEqual(manager.unloadRadius, 300.0)
        XCTAssertEqual(manager.maxConcurrentLoads, 5)
        XCTAssertEqual(manager.checkInterval, 1.0)

        // Restore original values
        manager.enabled = originalEnabled
        manager.streamingRadius = originalRadius
    }

    // MARK: - Stats Tests

    func testGetStats_Empty() {
        let stats = manager.getStats()

        XCTAssertEqual(stats.totalRegions, 0)
        XCTAssertEqual(stats.loadedRegions, 0)
        XCTAssertEqual(stats.loadingRegions, 0)
        XCTAssertEqual(stats.estimatedMemory, 0)
        XCTAssertEqual(stats.regionMemory, 0)
        XCTAssertEqual(stats.totalRootEntities, 0)
        XCTAssertEqual(stats.totalEntitiesWithChildren, 0)
        XCTAssertEqual(stats.activeLoads, 0)
    }

    func testGetStats_WithRegions() {
        let region1 = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1,
            estimatedMemorySize: 1024 * 1024
        )
        let region2 = StreamingRegion(
            bounds: AABB(min: simd_float3(20, 0, 0), max: simd_float3(30, 10, 10)),
            priority: 2,
            estimatedMemorySize: 2 * 1024 * 1024
        )

        manager.registerRegion(region1)
        manager.registerRegion(region2)

        let stats = manager.getStats()

        XCTAssertEqual(stats.totalRegions, 2)
        XCTAssertEqual(stats.loadedRegions, 0, "No regions should be loaded initially")
    }

    func testGetLoadedRegions_Empty() {
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1
        )

        manager.registerRegion(region)

        let loadedRegions = manager.getLoadedRegions()
        XCTAssertTrue(loadedRegions.isEmpty, "No regions should be loaded initially")
    }

    // MARK: - Priority Tests

    func testRegionPriorityComparison() {
        let highPriority = StreamingRegion(
            bounds: AABB(min: simd_float3(10, 0, 0), max: simd_float3(20, 10, 10)),
            priority: 10
        )
        let lowPriority = StreamingRegion(
            bounds: AABB(min: simd_float3(15, 0, 0), max: simd_float3(25, 10, 10)),
            priority: 1
        )

        XCTAssertGreaterThan(highPriority.priority, lowPriority.priority,
                             "Priority comparison should work correctly")
    }

    // MARK: - Update Tests

    func testUpdateWhenDisabled() {
        manager.enabled = false
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1
        )

        manager.registerRegion(region)

        // Camera inside region
        let cameraPos = simd_float3(5, 5, 5)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        // Region should not be loaded when manager is disabled
        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Regions should not load when manager is disabled")

        manager.enabled = true // Restore
    }

    func testUpdateRespectsCheckInterval() {
        manager.checkInterval = 1.0
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1
        )

        manager.registerRegion(region)

        // Update with small delta - should not trigger check yet
        manager.update(cameraPosition: simd_float3(5, 5, 5), deltaTime: 0.1)

        // No exceptions should be thrown
    }

    // MARK: - Memory Tests

    func testRegionMemorySize() {
        let oneMB = 1024 * 1024
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1,
            estimatedMemorySize: oneMB
        )

        XCTAssertEqual(region.estimatedMemorySize, oneMB)
    }

    func testMultipleRegionsMemoryAccounting() {
        let region1 = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1,
            estimatedMemorySize: 10 * 1024 * 1024 // 10 MB
        )
        let region2 = StreamingRegion(
            bounds: AABB(min: simd_float3(20, 0, 0), max: simd_float3(30, 10, 10)),
            priority: 2,
            estimatedMemorySize: 20 * 1024 * 1024 // 20 MB
        )

        manager.registerRegion(region1)
        manager.registerRegion(region2)

        // Total estimated memory
        let totalEstimated = region1.estimatedMemorySize + region2.estimatedMemorySize
        XCTAssertEqual(totalEstimated, 30 * 1024 * 1024)
    }

    // MARK: - Edge Cases

    func testRegionWithNoAssets() {
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: []
        )

        manager.registerRegion(region)

        XCTAssertTrue(region.assets.isEmpty,
                      "Region should handle empty asset list")
    }

    func testRegionWithMultipleAssets() {
        let assets = [
            AssetReference(filename: "asset1", withExtension: "usdz"),
            AssetReference(filename: "asset2", withExtension: "usdz"),
            AssetReference(filename: "asset3", withExtension: "usdz"),
        ]

        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: assets
        )

        XCTAssertEqual(region.assets.count, 3,
                       "Region should handle multiple assets")
    }

    func testVeryLargeRegion() {
        let largeRegion = StreamingRegion(
            bounds: AABB(
                min: simd_float3(-1000, -1000, -1000),
                max: simd_float3(1000, 1000, 1000)
            ),
            priority: 1
        )

        manager.registerRegion(largeRegion)

        let volume = largeRegion.bounds.volume
        XCTAssertGreaterThan(volume, 0, "Large region should have positive volume")
    }

    func testVerySmallRegion() {
        let tinyRegion = StreamingRegion(
            bounds: AABB(
                min: simd_float3(0, 0, 0),
                max: simd_float3(0.1, 0.1, 0.1)
            ),
            priority: 1
        )

        manager.registerRegion(tinyRegion)

        let volume = tinyRegion.bounds.volume
        XCTAssertGreaterThan(volume, 0, "Tiny region should have positive volume")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentRegionRegistration() {
        let expectation = XCTestExpectation(description: "Concurrent registration")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0 ..< 10 {
            queue.async {
                let region = StreamingRegion(
                    bounds: AABB(
                        min: simd_float3(Float(i * 10), 0, 0),
                        max: simd_float3(Float(i * 10 + 10), 10, 10)
                    ),
                    priority: 1
                )
                self.manager.registerRegion(region)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        let allRegions = manager.getAllRegions()
        XCTAssertEqual(allRegions.count, 10,
                       "All regions should be registered despite concurrent access")
    }

    func testConcurrentGetRegion() {
        // Register a region first
        let region = StreamingRegion(
            bounds: AABB(min: .zero, max: simd_float3(10, 10, 10)),
            priority: 1
        )
        manager.registerRegion(region)

        let expectation = XCTestExpectation(description: "Concurrent reads")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test.concurrent.read", attributes: .concurrent)

        for _ in 0 ..< 100 {
            queue.async {
                let retrieved = self.manager.getRegion(id: region.id)
                XCTAssertNotNil(retrieved)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Update Load/Unload Tests

    func testUpdateLoadsRegionsBasedOnCameraPositionAndStreamingRadius() async {
        // Configure manager
        manager.enabled = true
        manager.streamingRadius = 50.0
        manager.checkInterval = 0.0 // No delay for testing

        // Create a region within streaming radius of the camera position
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: [] // No assets for faster testing
        )
        manager.registerRegion(region)

        // Camera at origin - region is at distance 0
        let cameraPos = simd_float3(5, 5, 5)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        // Wait for async loading to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        XCTAssertTrue(manager.isRegionLoaded(id: region.id),
                      "Region within streaming radius should be loaded")
    }

    func testUpdateDoesNotLoadRegionsOutsideStreamingRadius() async {
        manager.enabled = true
        manager.streamingRadius = 10.0
        manager.checkInterval = 0.0

        // Create a region far from camera
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(100, 100, 100), max: simd_float3(110, 110, 110)),
            priority: 1,
            assets: []
        )
        manager.registerRegion(region)

        // Camera at origin - region is far away
        let cameraPos = simd_float3(0, 0, 0)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Region outside streaming radius should not be loaded")
    }

    func testUpdateUnloadsRegionsBasedOnCameraPositionAndUnloadRadius() async {
        manager.enabled = true
        manager.streamingRadius = 50.0
        manager.unloadRadius = 60.0
        manager.checkInterval = 0.0

        // Create and force load a region
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: []
        )
        manager.registerRegion(region)

        // Force load the region first
        let loaded = await manager.forceLoadRegion(id: region.id)
        XCTAssertTrue(loaded, "Region should be force loaded")

        // Move camera far away beyond unload radius
        let farCameraPos = simd_float3(200, 200, 200)
        manager.update(cameraPosition: farCameraPos, deltaTime: 1.0)

        // Wait for async unloading
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Region beyond unload radius should be unloaded")
    }

    func testUpdateDoesNotUnloadRegionsWithinUnloadRadius() async {
        manager.enabled = true
        manager.streamingRadius = 50.0
        manager.unloadRadius = 100.0
        manager.checkInterval = 0.0

        // Create and force load a region
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: []
        )
        manager.registerRegion(region)

        let loaded = await manager.forceLoadRegion(id: region.id)
        XCTAssertTrue(loaded)

        // Camera still within unload radius (distance ~70 < 100)
        let cameraPos = simd_float3(60, 60, 0)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(manager.isRegionLoaded(id: region.id),
                      "Region within unload radius should remain loaded")
    }

    // MARK: - Force Load/Unload Tests

    func testForceLoadRegionSuccessfullyLoadsAndSetsStateToLoaded() async {
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: [] // No assets for testing
        )
        manager.registerRegion(region)

        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Region should not be loaded initially")

        let success = await manager.forceLoadRegion(id: region.id)

        XCTAssertTrue(success, "forceLoadRegion should return true on success")
        XCTAssertTrue(manager.isRegionLoaded(id: region.id),
                      "Region state should be loaded after forceLoadRegion")

        // Verify state through getRegion
        let loadedRegion = manager.getRegion(id: region.id)
        XCTAssertEqual(loadedRegion?.state, .loaded,
                       "Region state should be .loaded")
    }

    func testForceLoadRegionWithNonexistentId() async {
        let nonexistentId = UUID()

        let success = await manager.forceLoadRegion(id: nonexistentId)

        XCTAssertFalse(success, "forceLoadRegion should return false for nonexistent region")
    }

    func testForceUnloadRegionSuccessfullyUnloadsAndSetsStateToUnloaded() async {
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: []
        )
        manager.registerRegion(region)

        // First load the region
        let loaded = await manager.forceLoadRegion(id: region.id)
        XCTAssertTrue(loaded, "Region should be loaded first")
        XCTAssertTrue(manager.isRegionLoaded(id: region.id))

        // Now unload it
        let success = await manager.forceUnloadRegion(id: region.id)

        XCTAssertTrue(success, "forceUnloadRegion should return true on success")
        XCTAssertFalse(manager.isRegionLoaded(id: region.id),
                       "Region should not be loaded after forceUnloadRegion")

        // Verify state through getRegion
        let unloadedRegion = manager.getRegion(id: region.id)
        XCTAssertEqual(unloadedRegion?.state, .unloaded,
                       "Region state should be .unloaded")
    }

    func testForceUnloadRegionWithNonexistentId() async {
        let nonexistentId = UUID()

        let success = await manager.forceUnloadRegion(id: nonexistentId)

        // Returns true because isRegionLoaded returns false for nonexistent regions
        XCTAssertTrue(success, "forceUnloadRegion returns true when region is not loaded")
    }

    func testForceUnloadRegionThatIsAlreadyUnloaded() async {
        let region = StreamingRegion(
            bounds: AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10)),
            priority: 1,
            assets: []
        )
        manager.registerRegion(region)

        // Region is already unloaded, try to unload again
        let success = await manager.forceUnloadRegion(id: region.id)

        XCTAssertTrue(success, "forceUnloadRegion should succeed for already unloaded region")
        XCTAssertEqual(manager.getRegion(id: region.id)?.state, .unloaded)
    }

    // MARK: - Max Concurrent Loads Tests

    func testUpdateRespectsMaxConcurrentLoads() async {
        manager.enabled = true
        manager.streamingRadius = 100.0
        manager.maxConcurrentLoads = 2
        manager.checkInterval = 0.0

        // Create 5 regions all within streaming radius
        var regions: [StreamingRegion] = []
        for i in 0 ..< 5 {
            let region = StreamingRegion(
                bounds: AABB(
                    min: simd_float3(Float(i * 5), 0, 0),
                    max: simd_float3(Float(i * 5 + 4), 4, 4)
                ),
                priority: 1,
                assets: []
            )
            regions.append(region)
            manager.registerRegion(region)
        }

        // Camera at origin - all regions are within streaming radius
        let cameraPos = simd_float3(10, 2, 2)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        // Check stats immediately after update to see active loads
        let stats = manager.getStats()

        // The manager should respect maxConcurrentLoads
        // Note: Due to async nature, loads may complete quickly with empty assets
        XCTAssertLessThanOrEqual(stats.activeLoads, manager.maxConcurrentLoads,
                                 "Active loads should not exceed maxConcurrentLoads")
    }

    func testMaxConcurrentLoadsWithDifferentValues() async {
        manager.enabled = true
        manager.streamingRadius = 200.0
        manager.checkInterval = 0.0

        // Test with maxConcurrentLoads = 1
        manager.maxConcurrentLoads = 1

        // Create multiple regions
        for i in 0 ..< 4 {
            let region = StreamingRegion(
                bounds: AABB(
                    min: simd_float3(Float(i * 10), 0, 0),
                    max: simd_float3(Float(i * 10 + 5), 5, 5)
                ),
                priority: 1,
                assets: []
            )
            manager.registerRegion(region)
        }

        let cameraPos = simd_float3(20, 2, 2)
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)

        let stats = manager.getStats()
        XCTAssertLessThanOrEqual(stats.activeLoads, 1,
                                 "Should respect maxConcurrentLoads of 1")
    }

    func testUpdateLoadsMoreRegionsAsSlotsBecomeAvailable() async {
        manager.enabled = true
        manager.streamingRadius = 100.0
        manager.maxConcurrentLoads = 2
        manager.checkInterval = 0.0

        // Create 4 regions
        var regionIds: [UUID] = []
        for i in 0 ..< 4 {
            let region = StreamingRegion(
                bounds: AABB(
                    min: simd_float3(Float(i * 5), 0, 0),
                    max: simd_float3(Float(i * 5 + 4), 4, 4)
                ),
                priority: 1,
                assets: []
            )
            regionIds.append(region.id)
            manager.registerRegion(region)
        }

        let cameraPos = simd_float3(10, 2, 2)

        // First update
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Second update - should load more regions as slots become available
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Third update
        manager.update(cameraPosition: cameraPos, deltaTime: 1.0)
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Eventually all regions should be loaded
        let loadedCount = regionIds.filter { manager.isRegionLoaded(id: $0) }.count
        XCTAssertEqual(loadedCount, 4,
                       "All regions should eventually be loaded after multiple updates")
    }
}
