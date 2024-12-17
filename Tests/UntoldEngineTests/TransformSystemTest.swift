//
//  TransformSystemTest.swift
//
//
//  Created by Harold Serrano on 12/17/24.
//

import XCTest
import simd
@testable import UntoldEngine

final class TransformSystemTests: XCTestCase {
    
    var entityId: EntityID!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        
        entityId = createEntity()
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
    }
    
    override func tearDown() {
        
        destroyEntity(entityId: entityId)
        super.tearDown()
    }
    
    // MARK: - Position Tests
    
    func testGetLocalPosition() {
        let position = simd_float3(1.0, 2.0, 3.0)
        
        translateTo(entityId: entityId, position: position)
        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, position)
    }
    
    // MARK: - Orientation Tests
        
    func testGetLocalOrientation() {
        let rotationMatrix = simd_float4x4(columns: (
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(0, 0, 0, 1)
        ))
        
        rotateTo(entityId: entityId, rotation: rotationMatrix)
        
        let orientation = getLocalOrientation(entityId: entityId)
        let expectedOrientation = matrix3x3_upper_left(rotationMatrix)
        
        XCTAssertEqual(orientation, expectedOrientation)
    }
    
    // MARK: - Translation Tests
        
    func testTranslateTo() {
        let position = simd_float3(10.0, 20.0, 30.0)
        translateTo(entityId: entityId, position: position)
        
        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, position)
    }
    
    func testTranslateBy() {
        
        translateBy(entityId: entityId, position: simd_float3(1, 2, 3))
        
        let result = getLocalPosition(entityId: entityId)
        XCTAssertEqual(result, simd_float3(1, 2, 3))
    }
    
    // MARK: - Axis Tests
        
    func testGetForwardAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let forward = getForwardAxisVector(entityId: entityId)
        XCTAssertEqual(forward, simd_float3(0, 0, 1))
    }
    
    func testGetRightAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let right = getRightAxisVector(entityId: entityId)
        XCTAssertEqual(right, simd_float3(1, 0, 0))
    }
    
    func testGetUpAxisVector() {
        rotateTo(entityId: entityId, rotation: simd_float4x4.identity)
        let up = getUpAxisVector(entityId: entityId)
        XCTAssertEqual(up, simd_float3(0, 1, 0))
    }
    
    // MARK: - Rotation Tests
    
    func testRotateTo() {
        let angle: Float = 90
        let axis = simd_float3(0, 1, 0)
        rotateTo(entityId: entityId, angle: angle, axis: axis)
        
        let result = getLocalOrientation(entityId: entityId)
        let expectedMatrix = matrix3x3_upper_left(matrix4x4Rotation(radians: degreesToRadians(degrees: angle), axis: axis))
        
        XCTAssertEqual(result, expectedMatrix)
    }
    
    func testRotateBy() {
        
        let angle: Float = 45
        let axis = simd_float3(0, 0, 1)
        rotateBy(entityId: entityId, angle: angle, axis: axis)
        
        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }
}
