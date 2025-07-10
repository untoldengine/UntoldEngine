//
//  TransformSystemTest.swift
//
//
//  Created by Harold Serrano on 12/17/24.
//

import simd
@testable import UntoldEngine
import XCTest

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

        let expectedMatrix = transformQuaternionToMatrix3x3(q: simd_quatf(angle: degreesToRadians(degrees: angle), axis: axis))

        //XCTAssertEqual(result, expectedMatrix)
        XCTAssertEqual(result.columns.0.x, expectedMatrix.columns.0.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.y, expectedMatrix.columns.0.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.z, expectedMatrix.columns.0.z, accuracy: 0.01)
        
        XCTAssertEqual(result.columns.1.x, expectedMatrix.columns.1.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.y, expectedMatrix.columns.1.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.z, expectedMatrix.columns.1.z, accuracy: 0.01)
        
        XCTAssertEqual(result.columns.2.x, expectedMatrix.columns.2.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.y, expectedMatrix.columns.2.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.z, expectedMatrix.columns.2.z, accuracy: 0.01)
        
        
    }

    func testRotateBy() {
        let angle: Float = 45
        let axis = simd_float3(0, 0, 1)
        rotateBy(entityId: entityId, angle: angle, axis: axis)

        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }

    func testGetLocalOrientationEuler() {
        let angle: Float = 45.0
        let axis = simd_float3(0, 1, 0)
        rotateTo(entityId: entityId, angle: angle, axis: axis)

        let result = getLocalOrientationEuler(entityId: entityId)

        XCTAssertEqual(result.pitch, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.yaw, radiansToDegrees(radians: 0.7853981), accuracy: 0.01)
        XCTAssertEqual(result.roll, 0.0, accuracy: 0.01)
    }

    func testRotateToEuler() {
        rotateTo(entityId: entityId, pitch: 45.0, yaw: 60.0, roll: 30.0)

        let m = getLocalOrientation(entityId: entityId)

        XCTAssertEqual(m.columns.0.x, 0.4330127, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.y, 0.2500000, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.z, -0.8660254, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.1.x, 0.1767767, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.y, 0.9185587, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.z, 0.3535534, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.2.x, 0.8838835, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.y, -0.3061862, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.z, 0.3535534, accuracy: 0.001, "component should be equal")
    }

    func testApplyAxisRotation() {
        applyAxisRotations(entityId: entityId, axis: simd_float3(45.0, 0.0, 0.0))
        let m = getLocalOrientation(entityId: entityId)

        XCTAssertEqual(m.columns.0.x, 1.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.y, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.0.z, 0.0, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.1.x, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.y, 0.7071068, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.1.z, 0.7071068, accuracy: 0.001, "component should be equal")

        XCTAssertEqual(m.columns.2.x, 0.0, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.y, -0.7071068, accuracy: 0.001, "component should be equal")
        XCTAssertEqual(m.columns.2.z, 0.7071068, accuracy: 0.001, "component should be equal")
    }
}
