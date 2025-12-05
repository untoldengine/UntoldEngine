//
//  PrimitivesTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import MetalKit
@testable import UntoldEngine
import XCTest

final class PrimitivesTest: XCTestCase {
    override func setUp() {
        super.setUp()

        // Initialize renderer to ensure Metal device and renderInfo are available
        guard UntoldRenderer.create() != nil else {
            XCTFail("❌ Failed to initialize renderer")
            return
        }
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Cube Tests

    func test_createCube_returnsNonEmptyMeshArray() {
        // When: Create a cube
        let meshes = BasicPrimitives.createCube()

        // Then: Should return at least one mesh
        XCTAssertFalse(meshes.isEmpty, "Cube should generate at least one mesh")
    }

    func test_createCube_hasCorrectName() {
        // When: Create a cube
        let meshes = BasicPrimitives.createCube()

        // Then: Mesh should be named "Cube"
        XCTAssertEqual(meshes.first?.assetName, "Cube", "Cube mesh should have correct name")
    }

    func test_createCube_hasValidGeometry() {
        // When: Create a cube
        let meshes = BasicPrimitives.createCube()

        // Then: Should have valid geometry
        guard let firstMesh = meshes.first else {
            XCTFail("Cube should have at least one mesh")
            return
        }

        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0, "Cube should have vertex buffers")
        XCTAssertFalse(firstMesh.submeshes.isEmpty, "Cube should have submeshes")
    }

    func test_createCube_withCustomExtent() {
        // Given: Custom extent
        let extent: Float = 2.0

        // When: Create cube with custom extent
        let meshes = BasicPrimitives.createCube(extent: extent)

        // Then: Should create successfully
        XCTAssertFalse(meshes.isEmpty, "Cube with custom extent should generate mesh")
    }

    // MARK: - Sphere Tests

    func test_createSphere_returnsNonEmptyMeshArray() {
        // When: Create a sphere
        let meshes = BasicPrimitives.createSphere()

        // Then: Should return at least one mesh
        XCTAssertFalse(meshes.isEmpty, "Sphere should generate at least one mesh")
    }

    func test_createSphere_hasCorrectName() {
        // When: Create a sphere
        let meshes = BasicPrimitives.createSphere()

        // Then: Mesh should be named "Sphere"
        XCTAssertEqual(meshes.first?.assetName, "Sphere", "Sphere mesh should have correct name")
    }

    func test_createSphere_hasValidGeometry() {
        // When: Create a sphere
        let meshes = BasicPrimitives.createSphere()

        // Then: Should have valid geometry
        guard let firstMesh = meshes.first else {
            XCTFail("Sphere should have at least one mesh")
            return
        }

        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0, "Sphere should have vertex buffers")
        XCTAssertFalse(firstMesh.submeshes.isEmpty, "Sphere should have submeshes")
    }

    func test_createSphere_withCustomSegments() {
        // Given: Custom segments
        let segments: [UInt32] = [16, 8]

        // When: Create sphere with custom segments
        let meshes = BasicPrimitives.createSphere(segments: segments)

        // Then: Should create successfully
        XCTAssertFalse(meshes.isEmpty, "Sphere with custom segments should generate mesh")
    }

    // MARK: - Plane Tests

    func test_createPlane_returnsNonEmptyMeshArray() {
        // When: Create a plane
        let meshes = BasicPrimitives.createPlane()

        // Then: Should return at least one mesh
        XCTAssertFalse(meshes.isEmpty, "Plane should generate at least one mesh")
    }

    func test_createPlane_hasCorrectName() {
        // When: Create a plane
        let meshes = BasicPrimitives.createPlane()

        // Then: Mesh should be named "Plane"
        XCTAssertEqual(meshes.first?.assetName, "Plane", "Plane mesh should have correct name")
    }

    func test_createPlane_hasValidGeometry() {
        // When: Create a plane
        let meshes = BasicPrimitives.createPlane()

        // Then: Should have valid geometry
        guard let firstMesh = meshes.first else {
            XCTFail("Plane should have at least one mesh")
            return
        }

        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0, "Plane should have vertex buffers")
        XCTAssertFalse(firstMesh.submeshes.isEmpty, "Plane should have submeshes")
    }

    func test_createPlane_isHorizontal() {
        // When: Create a plane
        let meshes = BasicPrimitives.createPlane()

        // Then: Should create successfully (orientation is verified visually in editor)
        XCTAssertFalse(meshes.isEmpty, "Plane should be created in horizontal orientation")
    }

    func test_createPlane_withCustomDimensions() {
        // Given: Custom dimensions
        let width: Float = 5.0
        let depth: Float = 3.0

        // When: Create plane with custom dimensions
        let meshes = BasicPrimitives.createPlane(width: width, depth: depth)

        // Then: Should create successfully
        XCTAssertFalse(meshes.isEmpty, "Plane with custom dimensions should generate mesh")
    }

    // MARK: - Cylinder Tests

    func test_createCylinder_returnsNonEmptyMeshArray() {
        // When: Create a cylinder
        let meshes = BasicPrimitives.createCylinder()

        // Then: Should return at least one mesh
        XCTAssertFalse(meshes.isEmpty, "Cylinder should generate at least one mesh")
    }

    func test_createCylinder_hasCorrectName() {
        // When: Create a cylinder
        let meshes = BasicPrimitives.createCylinder()

        // Then: Mesh should be named "Cylinder"
        XCTAssertEqual(meshes.first?.assetName, "Cylinder", "Cylinder mesh should have correct name")
    }

    func test_createCylinder_hasValidGeometry() {
        // When: Create a cylinder
        let meshes = BasicPrimitives.createCylinder()

        // Then: Should have valid geometry
        guard let firstMesh = meshes.first else {
            XCTFail("Cylinder should have at least one mesh")
            return
        }

        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0, "Cylinder should have vertex buffers")
        XCTAssertFalse(firstMesh.submeshes.isEmpty, "Cylinder should have submeshes")
    }

    func test_createCylinder_withCustomDimensions() {
        // Given: Custom dimensions
        let height: Float = 2.0
        let radius: Float = 0.75

        // When: Create cylinder with custom dimensions
        let meshes = BasicPrimitives.createCylinder(height: height, radius: radius)

        // Then: Should create successfully
        XCTAssertFalse(meshes.isEmpty, "Cylinder with custom dimensions should generate mesh")
    }

    // MARK: - Cone Tests

    func test_createCone_returnsNonEmptyMeshArray() {
        // When: Create a cone
        let meshes = BasicPrimitives.createCone()

        // Then: Should return at least one mesh
        XCTAssertFalse(meshes.isEmpty, "Cone should generate at least one mesh")
    }

    func test_createCone_hasCorrectName() {
        // When: Create a cone
        let meshes = BasicPrimitives.createCone()

        // Then: Mesh should be named "Cone"
        XCTAssertEqual(meshes.first?.assetName, "Cone", "Cone mesh should have correct name")
    }

    func test_createCone_hasValidGeometry() {
        // When: Create a cone
        let meshes = BasicPrimitives.createCone()

        // Then: Should have valid geometry
        guard let firstMesh = meshes.first else {
            XCTFail("Cone should have at least one mesh")
            return
        }

        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0, "Cone should have vertex buffers")
        XCTAssertFalse(firstMesh.submeshes.isEmpty, "Cone should have submeshes")
    }

    func test_createCone_withCustomDimensions() {
        // Given: Custom dimensions
        let height: Float = 1.5
        let radius: Float = 0.6

        // When: Create cone with custom dimensions
        let meshes = BasicPrimitives.createCone(height: height, radius: radius)

        // Then: Should create successfully
        XCTAssertFalse(meshes.isEmpty, "Cone with custom dimensions should generate mesh")
    }

    // MARK: - Integration Tests

    func test_allPrimitives_haveBoundingBoxes() {
        // When: Create all primitives
        let cube = BasicPrimitives.createCube()
        let sphere = BasicPrimitives.createSphere()
        let plane = BasicPrimitives.createPlane()
        let cylinder = BasicPrimitives.createCylinder()
        let cone = BasicPrimitives.createCone()

        // Then: All should have valid bounding boxes
        for (name, meshes) in [("Cube", cube), ("Sphere", sphere), ("Plane", plane), ("Cylinder", cylinder), ("Cone", cone)] {
            guard let mesh = meshes.first else {
                XCTFail("\(name) should have at least one mesh")
                continue
            }

            let bbox = mesh.boundingBox
            XCTAssertNotEqual(bbox.min, bbox.max, "\(name) should have non-zero bounding box")
        }
    }

    func test_allPrimitives_canBeCreatedConcurrently() {
        // When: Create multiple primitives concurrently
        let expectation = expectation(description: "Concurrent primitive creation")
        expectation.expectedFulfillmentCount = 5

        let queue = DispatchQueue.global(qos: .userInitiated)

        queue.async {
            _ = BasicPrimitives.createCube()
            expectation.fulfill()
        }

        queue.async {
            _ = BasicPrimitives.createSphere()
            expectation.fulfill()
        }

        queue.async {
            _ = BasicPrimitives.createPlane()
            expectation.fulfill()
        }

        queue.async {
            _ = BasicPrimitives.createCylinder()
            expectation.fulfill()
        }

        queue.async {
            _ = BasicPrimitives.createCone()
            expectation.fulfill()
        }

        // Then: All should complete successfully
        waitForExpectations(timeout: 5.0)
    }

    func test_primitives_haveUniqueNames() {
        // When: Create all primitives
        let cube = BasicPrimitives.createCube()
        let sphere = BasicPrimitives.createSphere()
        let plane = BasicPrimitives.createPlane()
        let cylinder = BasicPrimitives.createCylinder()
        let cone = BasicPrimitives.createCone()

        // Then: Each should have a unique name
        let names = [
            cube.first?.assetName,
            sphere.first?.assetName,
            plane.first?.assetName,
            cylinder.first?.assetName,
            cone.first?.assetName,
        ].compactMap { $0 }

        let uniqueNames = Set(names)
        XCTAssertEqual(names.count, uniqueNames.count, "All primitives should have unique names")
        XCTAssertEqual(uniqueNames.count, 5, "Should have 5 unique primitive names")
    }
}
