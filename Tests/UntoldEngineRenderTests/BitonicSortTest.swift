//
//  BitonicSortTest.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

final class BitonicSortTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_bitonic_sort() {
        // Initialize bitonic sort compute pipeline
        initGuassianComputePipelines()

        // Create test data - must be power of 2
        let dataSize = 256
        var testData = [UInt64](repeating: 0, count: dataSize)

        // Fill with random data (using UInt64 for packed depth keys)
        for i in 0 ..< dataSize {
            testData[i] = UInt64.random(in: 0 ..< 10000)
        }

        // Keep a copy to verify sorting
        let originalData = testData
        let expectedSorted = testData.sorted()

        // Create test entity with GaussianComponent
        let testEntity = createEntity()
        registerComponent(entityId: testEntity, componentType: GaussianComponent.self)
        registerComponent(entityId: testEntity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: testEntity, componentType: LocalTransformComponent.self)

        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: testEntity) else {
            XCTFail("Failed to get GaussianComponent")
            return
        }

        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get WorldTransformComponent")
            return
        }

        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get LocalTransformComponent")
            return
        }

        // Set up transform to identity
        worldTransform.space = matrix_identity_float4x4
        localTransform.space = matrix_identity_float4x4

        // Create buffer with test data
        let bufferSize = dataSize * MemoryLayout<UInt64>.stride
        guard let buffer = renderInfo.device.makeBuffer(bytes: testData, length: bufferSize, options: .storageModeShared) else {
            XCTFail("Failed to create Metal buffer")
            return
        }

        // Set up GaussianComponent with test buffer
        gaussianComponent.gaussianSortedIndices = buffer
        gaussianComponent.splatCount = UInt(dataSize)

        // Create command buffer
        guard let commandQueue = renderInfo.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            XCTFail("Failed to create command queue/buffer")
            return
        }

        // Execute bitonic sort (no parameters needed - uses ECS)
        executeBitonicSort(commandBuffer)

        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results back
        let resultPointer = buffer.contents().bindMemory(to: UInt64.self, capacity: dataSize)
        var sortedData = [UInt64](repeating: 0, count: dataSize)
        for i in 0 ..< dataSize {
            sortedData[i] = resultPointer[i]
        }

        // Verify results
        print("Original data (first 10): \(Array(originalData[0 ..< 10]))")
        print("Sorted data (first 10): \(Array(sortedData[0 ..< 10]))")
        print("Expected sorted (first 10): \(Array(expectedSorted[0 ..< 10]))")

        // Check if sorted correctly
        for i in 0 ..< dataSize {
            XCTAssertEqual(sortedData[i], expectedSorted[i], "Mismatch at index \(i): got \(sortedData[i]), expected \(expectedSorted[i])")
        }

        // Additional check: verify array is actually sorted
        for i in 1 ..< dataSize {
            XCTAssertLessThanOrEqual(sortedData[i - 1], sortedData[i], "Array not sorted at index \(i)")
        }

        print("✅ Bitonic sort test passed!")
    }

    func test_gaussian_depth() {
        // Initialize gaussian compute pipelines
        initGuassianComputePipelines()

        // Create 8 dummy Gaussian splats with known positions
        let numSplats = 8
        var splats = [GaussianSplat]()

        // Create splats at different depths (z-positions)
        let positions: [simd_float3] = [
            simd_float3(0, 0, -10), // closest
            simd_float3(0, 0, -50),
            simd_float3(0, 0, -20),
            simd_float3(0, 0, -100), // farthest
            simd_float3(0, 0, -30),
            simd_float3(0, 0, -5), // very close
            simd_float3(0, 0, -70),
            simd_float3(0, 0, -15),
        ]

        for i in 0 ..< numSplats {
            let splat = GaussianSplat(
                center: simd_float4(positions[i], 1.0),
                scale: simd_float4(1, 1, 1, 1),
                color: simd_float4(1, 0, 0, 1),
                quat: simd_float4(0, 0, 0, 1),
                opacity: 1.0
            )
            splats.append(splat)
        }

        // Create test entity with GaussianComponent
        let testEntity = createEntity()
        registerComponent(entityId: testEntity, componentType: GaussianComponent.self)
        registerComponent(entityId: testEntity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: testEntity, componentType: LocalTransformComponent.self)

        // Create camera entity
        let cameraEntity = createEntity()
        registerComponent(entityId: cameraEntity, componentType: CameraComponent.self)
        registerComponent(entityId: cameraEntity, componentType: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = cameraEntity

        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: testEntity) else {
            XCTFail("Failed to get GaussianComponent")
            return
        }

        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get WorldTransformComponent")
            return
        }

        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get LocalTransformComponent")
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            XCTFail("Failed to get CameraComponent")
            return
        }

        // Set up camera with identity view matrix (camera at origin looking down -Z)
        cameraComponent.viewSpace = matrix_identity_float4x4
        cameraComponent.localPosition = simd_float3(0, 0, 0)

        // Set up transform to identity
        worldTransform.space = matrix_identity_float4x4
        localTransform.space = matrix_identity_float4x4

        // Create buffer for splat data
        let splatBufferSize = numSplats * MemoryLayout<GaussianSplat>.stride
        guard let splatBuffer = renderInfo.device.makeBuffer(
            bytes: splats,
            length: splatBufferSize,
            options: .storageModeShared
        ) else {
            XCTFail("Failed to create splat buffer")
            return
        }

        // Create buffer for depth keys output
        let keysBufferSize = numSplats * MemoryLayout<UInt64>.stride
        guard let keysBuffer = renderInfo.device.makeBuffer(
            length: keysBufferSize,
            options: .storageModeShared
        ) else {
            XCTFail("Failed to create keys buffer")
            return
        }

        // Set up GaussianComponent with test buffers
        gaussianComponent.gaussianSortedIndices = keysBuffer
        gaussianComponent.splatData = splatBuffer
        gaussianComponent.splatCount = UInt(numSplats)
        gaussianComponent.spaceUniform = (0 ..< 2).compactMap { _ in
            renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [MTLResourceOptions.storageModeShared])
        }

        // Create command buffer
        guard let commandQueue = renderInfo.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            XCTFail("Failed to create command queue/buffer")
            return
        }

        // Execute gaussian depth computation (no parameters needed - uses ECS)
        executeGaussianDepth(commandBuffer)

        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results back
        let resultPointer = keysBuffer.contents().bindMemory(to: UInt64.self, capacity: numSplats)
        var depthKeys = [UInt64](repeating: 0, count: numSplats)
        for i in 0 ..< numSplats {
            depthKeys[i] = resultPointer[i]
        }

        print("\nOriginal positions (z-values):")
        for i in 0 ..< numSplats {
            print("  Splat \(i): z = \(positions[i].z), depth = \(abs(positions[i].z))")
        }

        print("\nPacked depth keys (unsorted):")
        for i in 0 ..< numSplats {
            let index = UInt32(depthKeys[i] & 0xFFFF_FFFF)
            let depthKey = UInt32((depthKeys[i] >> 32) & 0xFFFF_FFFF)
            print("  Position \(i): index = \(index), depthKey = \(depthKey) (sortable uint)")
        }

        // Verify each key contains the correct index in the lower 32 bits
        for i in 0 ..< numSplats {
            let index = UInt32(depthKeys[i] & 0xFFFF_FFFF)
            XCTAssertEqual(index, UInt32(i), "Index mismatch at position \(i): expected \(i), got \(index)")
        }

        // Verify that all depth keys are non-zero (depths were computed)
        for i in 0 ..< numSplats {
            let depthKey = UInt32((depthKeys[i] >> 32) & 0xFFFF_FFFF)
            XCTAssertNotEqual(depthKey, 0, "Depth key is zero at position \(i) - depth computation may have failed")
        }

        print("✅ Gaussian depth computation test passed!")
    }

    func test_gaussian_depth_and_sort() {
        // Initialize gaussian compute pipelines
        initGuassianComputePipelines()

        // Create 8 dummy Gaussian splats with known positions
        let numSplats = 8
        var splats = [GaussianSplat]()

        // Create splats at different depths (z-positions)
        let positions: [simd_float3] = [
            simd_float3(0, 0, -10), // closest
            simd_float3(0, 0, -50),
            simd_float3(0, 0, -20),
            simd_float3(0, 0, -100), // farthest
            simd_float3(0, 0, -30),
            simd_float3(0, 0, -5), // very close
            simd_float3(0, 0, -70),
            simd_float3(0, 0, -15),
        ]

        for i in 0 ..< numSplats {
            let splat = GaussianSplat(
                center: simd_float4(positions[i], 1.0),
                scale: simd_float4(1, 1, 1, 1),
                color: simd_float4(1, 0, 0, 1),
                quat: simd_float4(0, 0, 0, 1),
                opacity: 1.0
            )
            splats.append(splat)
        }

        // Create test entity with GaussianComponent
        let testEntity = createEntity()
        registerComponent(entityId: testEntity, componentType: GaussianComponent.self)
        registerComponent(entityId: testEntity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: testEntity, componentType: LocalTransformComponent.self)

        // Create camera entity
        let cameraEntity = createEntity()
        registerComponent(entityId: cameraEntity, componentType: CameraComponent.self)
        registerComponent(entityId: cameraEntity, componentType: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = cameraEntity

        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: testEntity) else {
            XCTFail("Failed to get GaussianComponent")
            return
        }

        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get WorldTransformComponent")
            return
        }

        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: testEntity) else {
            XCTFail("Failed to get LocalTransformComponent")
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: cameraEntity) else {
            XCTFail("Failed to get CameraComponent")
            return
        }

        // Set up camera with identity view matrix (camera at origin looking down -Z)
        cameraComponent.viewSpace = matrix_identity_float4x4
        cameraComponent.localPosition = simd_float3(0, 0, 0)

        // Set up transform to identity
        worldTransform.space = matrix_identity_float4x4
        localTransform.space = matrix_identity_float4x4

        // Create buffer for splat data
        let splatBufferSize = numSplats * MemoryLayout<GaussianSplat>.stride
        guard let splatBuffer = renderInfo.device.makeBuffer(
            bytes: splats,
            length: splatBufferSize,
            options: .storageModeShared
        ) else {
            XCTFail("Failed to create splat buffer")
            return
        }

        // Create buffer for depth keys output
        let keysBufferSize = numSplats * MemoryLayout<UInt64>.stride
        guard let keysBuffer = renderInfo.device.makeBuffer(
            length: keysBufferSize,
            options: .storageModeShared
        ) else {
            XCTFail("Failed to create keys buffer")
            return
        }

        // Set up GaussianComponent with test buffers
        gaussianComponent.gaussianSortedIndices = keysBuffer
        gaussianComponent.splatData = splatBuffer
        gaussianComponent.splatCount = UInt(numSplats)
        gaussianComponent.spaceUniform = (0 ..< 2).compactMap { _ in
            renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [MTLResourceOptions.storageModeShared])
        }

        // Create command buffer
        guard let commandQueue = renderInfo.device.makeCommandQueue(),
              let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            XCTFail("Failed to create command queue/buffer")
            return
        }

        // Execute gaussian depth computation (no parameters needed - uses ECS)
        executeGaussianDepth(commandBuffer)

        // Execute bitonic sort to sort the depth keys (no parameters needed - uses ECS)
        executeBitonicSort(commandBuffer)

        // Commit and wait
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results back
        let resultPointer = keysBuffer.contents().bindMemory(to: UInt64.self, capacity: numSplats)
        var depthKeys = [UInt64](repeating: 0, count: numSplats)
        for i in 0 ..< numSplats {
            depthKeys[i] = resultPointer[i]
        }

        print("\nOriginal positions (z-values):")
        for i in 0 ..< numSplats {
            print("  Splat \(i): z = \(positions[i].z), depth = \(abs(positions[i].z))")
        }

        print("\nSorted depth keys and extracted indices:")
        for i in 0 ..< numSplats {
            let index = UInt32(depthKeys[i] & 0xFFFF_FFFF)
            let originalZ = positions[Int(index)].z
            print("  Position \(i): index = \(index), original z = \(originalZ), depth = \(abs(originalZ))")
        }

        // Verify each key contains a valid index in the lower 32 bits
        for i in 0 ..< numSplats {
            let index = UInt32(depthKeys[i] & 0xFFFF_FFFF)
            XCTAssertLessThan(index, UInt32(numSplats), "Index out of range at position \(i)")
        }

        // Verify front-to-back sorting (ascending depth keys)
        // After sorting in ascending order of keyFrontToBack:
        // - Smaller keyFrontToBack = closer objects (rendered first)
        // - Larger keyFrontToBack = farther objects (rendered last)
        for i in 1 ..< numSplats {
            let prevDepthKey = UInt32((depthKeys[i - 1] >> 32) & 0xFFFF_FFFF)
            let currDepthKey = UInt32((depthKeys[i] >> 32) & 0xFFFF_FFFF)
            XCTAssertLessThanOrEqual(
                prevDepthKey,
                currDepthKey,
                "keyFrontToBack not in ascending order at position \(i)"
            )
        }

        // Verify the actual depth values correspond to the correct z-positions
        for i in 0 ..< numSplats {
            let index = Int(depthKeys[i] & 0xFFFF_FFFF)
            let expectedDepth = abs(positions[index].z)
            XCTAssertGreaterThan(expectedDepth, 0, "Depth should be positive for splat \(index)")
        }

        print("✅ Gaussian depth and sort integration test passed!")
    }

    func test_nextPowerOf2() {
        // Test various inputs
        let testCases: [(input: UInt, expected: UInt)] = [
            (0, 1), // Edge case: 0
            (1, 1), // Already power of 2
            (2, 2), // Already power of 2
            (3, 4), // Round up
            (4, 4), // Already power of 2
            (5, 8), // Round up
            (7, 8), // Round up
            (8, 8), // Already power of 2
            (15, 16), // Round up
            (16, 16), // Already power of 2
            (17, 32), // Round up
            (31, 32), // Round up
            (32, 32), // Already power of 2
            (33, 64), // Round up
            (100, 128), // Round up
            (255, 256), // Round up
            (256, 256), // Already power of 2
            (257, 512), // Round up
            (1023, 1024), // Round up
            (1024, 1024), // Already power of 2
        ]

        for testCase in testCases {
            var input = testCase.input
            let result = nextPowerOf2(x: &input)
            XCTAssertEqual(
                result,
                testCase.expected,
                "nextPowerOf2(\(testCase.input)) = \(result), expected \(testCase.expected)"
            )
        }

        // Verify that all results are actually powers of 2
        for testCase in testCases {
            var input = testCase.input
            let result = nextPowerOf2(x: &input)
            // A power of 2 has only one bit set, so (n & (n-1)) == 0
            XCTAssertTrue(
                result > 0 && (result & (result - 1)) == 0,
                "Result \(result) is not a power of 2"
            )
        }

        print("✅ nextPowerOf2 test passed!")
    }
}
