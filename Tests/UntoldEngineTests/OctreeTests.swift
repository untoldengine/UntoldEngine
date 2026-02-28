//
//  OctreeTests.swift
//  UntoldEngineTests
//
import simd
@testable import UntoldEngine
import XCTest

final class OctreeTests: XCTestCase {
    // MARK: - AABB Tests

    func testAABBContainsPoint() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))

        XCTAssertTrue(box.contains(simd_float3(5, 5, 5)))
        XCTAssertTrue(box.contains(simd_float3(0, 0, 0)))
        XCTAssertTrue(box.contains(simd_float3(10, 10, 10)))
        XCTAssertFalse(box.contains(simd_float3(-1, 5, 5)))
        XCTAssertFalse(box.contains(simd_float3(11, 5, 5)))
    }

    func testAABBIntersectsAABB() {
        let box1 = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let box2 = AABB(min: simd_float3(5, 5, 5), max: simd_float3(15, 15, 15))
        let box3 = AABB(min: simd_float3(20, 20, 20), max: simd_float3(30, 30, 30))

        XCTAssertTrue(box1.intersects(box2))
        XCTAssertFalse(box1.intersects(box3))
    }

    func testAABBIntersectsSphere() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let sphereInside = BoundingSphere(center: simd_float3(5, 5, 5), radius: 2)
        let sphereOutside = BoundingSphere(center: simd_float3(20, 20, 20), radius: 2)
        let sphereTouching = BoundingSphere(center: simd_float3(12, 5, 5), radius: 3)

        XCTAssertTrue(box.intersects(sphereInside))
        XCTAssertFalse(box.intersects(sphereOutside))
        XCTAssertTrue(box.intersects(sphereTouching))
    }

    func testAABBSubdivide() {
        let box = AABB(min: simd_float3(0, 0, 0), max: simd_float3(10, 10, 10))
        let children = box.subdivide()

        XCTAssertEqual(children.count, 8)

        // All children should be half size
        for child in children {
            XCTAssertEqual(child.size.x, 5, accuracy: 0.001)
            XCTAssertEqual(child.size.y, 5, accuracy: 0.001)
            XCTAssertEqual(child.size.z, 5, accuracy: 0.001)
        }
    }

    // MARK: - Octree Tests

    func testOctreeInsertAndQuery() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-100, -100, -100),
            max: simd_float3(100, 100, 100)
        ))

        // Insert some entities
        let entity1: EntityID = 1
        let entity2: EntityID = 2
        let entity3: EntityID = 3

        octree.insert(entityId: entity1, bounds: AABB(
            min: simd_float3(0, 0, 0),
            max: simd_float3(5, 5, 5)
        ))

        octree.insert(entityId: entity2, bounds: AABB(
            min: simd_float3(10, 10, 10),
            max: simd_float3(15, 15, 15)
        ))

        octree.insert(entityId: entity3, bounds: AABB(
            min: simd_float3(50, 50, 50),
            max: simd_float3(55, 55, 55)
        ))

        XCTAssertEqual(octree.entryCount, 3)

        // Query near origin - should find entity1 and entity2
        let nearOrigin = octree.query(sphere: BoundingSphere(
            center: simd_float3(5, 5, 5),
            radius: 15
        ))

        XCTAssertTrue(nearOrigin.contains(entity1))
        XCTAssertTrue(nearOrigin.contains(entity2))
        XCTAssertFalse(nearOrigin.contains(entity3))

        // Query far corner - should only find entity3
        let farCorner = octree.query(sphere: BoundingSphere(
            center: simd_float3(52, 52, 52),
            radius: 10
        ))

        XCTAssertFalse(farCorner.contains(entity1))
        XCTAssertFalse(farCorner.contains(entity2))
        XCTAssertTrue(farCorner.contains(entity3))
    }

    func testOctreeRemove() {
        let octree = Octree()

        let entity1: EntityID = 1
        let entity2: EntityID = 2

        octree.insert(entityId: entity1, bounds: AABB(
            min: simd_float3(0, 0, 0),
            max: simd_float3(5, 5, 5)
        ))

        octree.insert(entityId: entity2, bounds: AABB(
            min: simd_float3(10, 10, 10),
            max: simd_float3(15, 15, 15)
        ))

        XCTAssertEqual(octree.entryCount, 2)
        XCTAssertTrue(octree.contains(entityId: entity1))

        octree.remove(entityId: entity1)

        XCTAssertEqual(octree.entryCount, 1)
        XCTAssertFalse(octree.contains(entityId: entity1))
        XCTAssertTrue(octree.contains(entityId: entity2))
    }

    func testOctreeUpdate() {
        let octree = Octree()

        let entity1: EntityID = 1

        octree.insert(entityId: entity1, bounds: AABB(
            min: simd_float3(0, 0, 0),
            max: simd_float3(5, 5, 5)
        ))

        // Should find it near origin
        var results = octree.query(sphere: BoundingSphere(
            center: simd_float3(2.5, 2.5, 2.5),
            radius: 5
        ))
        XCTAssertTrue(results.contains(entity1))

        // Move it far away
        octree.update(entityId: entity1, newBounds: AABB(
            min: simd_float3(100, 100, 100),
            max: simd_float3(105, 105, 105)
        ))

        // Should NOT find it near origin anymore
        results = octree.query(sphere: BoundingSphere(
            center: simd_float3(2.5, 2.5, 2.5),
            radius: 5
        ))
        XCTAssertFalse(results.contains(entity1))

        // Should find it at new location
        results = octree.query(sphere: BoundingSphere(
            center: simd_float3(102, 102, 102),
            radius: 10
        ))
        XCTAssertTrue(results.contains(entity1))
    }

    func testOctreeSubdivision() {
        let octree = Octree(
            worldBounds: AABB(
                min: simd_float3(-100, -100, -100),
                max: simd_float3(100, 100, 100)
            ),
            maxDepth: 4,
            maxEntriesPerLeaf: 4,
            minNodeSize: 1.0
        )

        // Insert many entities in same area to trigger subdivision
        for i in 0 ..< 20 {
            let offset = Float(i) * 0.1
            octree.insert(entityId: EntityID(i), bounds: AABB(
                min: simd_float3(offset, offset, offset),
                max: simd_float3(offset + 1, offset + 1, offset + 1)
            ))
        }

        let stats = octree.stats
        XCTAssertGreaterThan(stats.nodeCount, 1) // Should have subdivided
        XCTAssertEqual(stats.totalEntries, 20)
    }

    // MARK: - Ray Query Tests

    func testOctreeRayQueryHitsEntity() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-100, -100, -100),
            max: simd_float3(100, 100, 100)
        ))

        let entity: EntityID = 1
        octree.insert(entityId: entity, bounds: AABB(
            min: simd_float3(4, -1, -1),
            max: simd_float3(6, 1, 1)
        ))

        let results = octree.query(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].0, entity)
        XCTAssertEqual(results[0].1, 4.0, accuracy: 0.001)
    }

    func testOctreeRayQueryMissesEntityNotInPath() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-100, -100, -100),
            max: simd_float3(100, 100, 100)
        ))

        let entity: EntityID = 1
        octree.insert(entityId: entity, bounds: AABB(
            min: simd_float3(4, 10, 10),
            max: simd_float3(6, 12, 12)
        ))

        let results = octree.query(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertTrue(results.isEmpty, "Ray along X axis should miss entity offset in Y/Z")
    }

    func testOctreeRayQueryRespectsMaxDistance() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-100, -100, -100),
            max: simd_float3(100, 100, 100)
        ))

        let entity: EntityID = 1
        octree.insert(entityId: entity, bounds: AABB(
            min: simd_float3(9, -1, -1),
            max: simd_float3(11, 1, 1)
        ))

        let withinRange = octree.query(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            maxDistance: 10.0
        )
        XCTAssertEqual(withinRange.count, 1)

        let outOfRange = octree.query(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0),
            maxDistance: 8.0
        )
        XCTAssertTrue(outOfRange.isEmpty, "Entity beyond maxDistance should not be returned")
    }

    func testOctreeRayQueryReturnsSortedByDistance() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-100, -100, -100),
            max: simd_float3(100, 100, 100)
        ))

        let far: EntityID = 1
        let near: EntityID = 2
        let mid: EntityID = 3

        octree.insert(entityId: far, bounds: AABB(
            min: simd_float3(20, -1, -1), max: simd_float3(22, 1, 1)
        ))
        octree.insert(entityId: near, bounds: AABB(
            min: simd_float3(4, -1, -1), max: simd_float3(6, 1, 1)
        ))
        octree.insert(entityId: mid, bounds: AABB(
            min: simd_float3(10, -1, -1), max: simd_float3(12, 1, 1)
        ))

        let results = octree.query(
            rayOrigin: simd_float3(0, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].0, near)
        XCTAssertEqual(results[1].0, mid)
        XCTAssertEqual(results[2].0, far)
    }

    func testOctreeRayQueryFindsSpanningEntities() {
        // Entity sits on the boundary between two octants.
        // With the contains-based insertion it stays at the parent level,
        // so the ray should still find it regardless of which child the ray enters.
        let octree = Octree(
            worldBounds: AABB(
                min: simd_float3(-100, -100, -100),
                max: simd_float3(100, 100, 100)
            ),
            maxDepth: 4,
            maxEntriesPerLeaf: 2,
            minNodeSize: 1.0
        )

        // Insert enough entities to trigger subdivision
        for i in 0 ..< 5 {
            let offset = Float(i) * 10 + 20
            octree.insert(entityId: EntityID(i + 10), bounds: AABB(
                min: simd_float3(offset, offset, offset),
                max: simd_float3(offset + 2, offset + 2, offset + 2)
            ))
        }

        // Insert entity that spans the origin boundary (crosses octant boundaries)
        let spanningEntity: EntityID = 99
        octree.insert(entityId: spanningEntity, bounds: AABB(
            min: simd_float3(-2, -2, -2),
            max: simd_float3(2, 2, 2)
        ))

        // Ray along +X should find the spanning entity
        let resultsPositiveX = octree.query(
            rayOrigin: simd_float3(-50, 0, 0),
            rayDirection: simd_float3(1, 0, 0)
        )
        let foundPositiveX = resultsPositiveX.contains { $0.0 == spanningEntity }
        XCTAssertTrue(foundPositiveX, "Ray along +X should find entity spanning octant boundary")

        // Ray along -X should also find it
        let resultsNegativeX = octree.query(
            rayOrigin: simd_float3(50, 0, 0),
            rayDirection: simd_float3(-1, 0, 0)
        )
        let foundNegativeX = resultsNegativeX.contains { $0.0 == spanningEntity }
        XCTAssertTrue(foundNegativeX, "Ray along -X should find entity spanning octant boundary")

        // Ray along +Y should also find it
        let resultsPositiveY = octree.query(
            rayOrigin: simd_float3(0, -50, 0),
            rayDirection: simd_float3(0, 1, 0)
        )
        let foundPositiveY = resultsPositiveY.contains { $0.0 == spanningEntity }
        XCTAssertTrue(foundPositiveY, "Ray along +Y should find entity spanning octant boundary")
    }

    // MARK: - Performance Tests

    func testOctreeQueryPerformance() {
        let octree = Octree(worldBounds: AABB(
            min: simd_float3(-500, -500, -500),
            max: simd_float3(500, 500, 500)
        ))

        // Insert 5000 entities scattered around
        for i in 0 ..< 5000 {
            let x = Float.random(in: -500 ... 500)
            let y = Float.random(in: -500 ... 500)
            let z = Float.random(in: -500 ... 500)

            octree.insert(entityId: EntityID(i), bounds: AABB(
                min: simd_float3(x, y, z),
                max: simd_float3(x + 5, y + 5, z + 5)
            ))
        }

        // Measure query time
        measure {
            for _ in 0 ..< 100 {
                let x = Float.random(in: -400 ... 400)
                let y = Float.random(in: -400 ... 400)
                let z = Float.random(in: -400 ... 400)

                _ = octree.query(sphere: BoundingSphere(
                    center: simd_float3(x, y, z),
                    radius: 100
                ))
            }
        }
    }
}
