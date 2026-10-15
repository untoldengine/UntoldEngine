//
//  InstancedDrawListTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// A pass gathers the entities it draws instanced in an `InstancedDrawList`, which decides
/// where each instance's record goes, and borrows the buffer for the records from
/// `InstanceRecordBufferPool`. These tests pin the layout of the records, their values,
/// and the comings and goings of the buffers.
@MainActor
final class InstancedDrawListTests: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Helpers

    private func component(_ meshes: [Mesh]) -> RenderComponent {
        let component = RenderComponent()
        component.mesh = meshes
        return component
    }

    private func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
        matrix4x4Translation(x, y, z)
    }

    /// A transform with a turn and an uneven scale: its normal matrix is not its own
    /// upper left.
    private func space(_ seed: Float) -> simd_float4x4 {
        let turn = simd_float4x4(simd_quatf(angle: 0.3 + seed, axis: simd_normalize(simd_float3(0.2, 1, 0.4))))
        var scale = matrix_identity_float4x4
        scale.columns.0.x = 1 + seed
        scale.columns.1.y = 0.5
        scale.columns.2.z = 2
        return translation(seed * 3, 1, -seed) * turn * scale
    }

    private func modelRecords(of list: inout InstancedDrawList, viewMatrix: simd_float4x4) -> [ModelInstanceUniform] {
        var records = [ModelInstanceUniform](repeating: ModelInstanceUniform(), count: list.recordCount)
        records.withUnsafeMutableBufferPointer { list.writeModelRecords(to: $0.baseAddress!, viewMatrix: viewMatrix) }
        return records
    }

    private func shadowRecords(of list: inout InstancedDrawList) -> [simd_float4x4] {
        var records = [simd_float4x4](repeating: simd_float4x4(), count: list.recordCount)
        records.withUnsafeMutableBufferPointer { list.writeShadowRecords(to: $0.baseAddress!) }
        return records
    }

    // MARK: - Groups

    func testEntitiesWithTheSameKeyAreOneGroupInTheOrderTheyCame() {
        let cube = component(BasicPrimitives.createCube(extent: 1))
        let sphere = component(BasicPrimitives.createSphere(extent: 1))
        var list = InstancedDrawList()
        XCTAssertTrue(list.isEmpty)

        // Keys 7, 2, 7, 7, 2: the group of 7 comes first, as its first entity did.
        list.add(keyID: 7, component: cube, space: translation(0, 0, 0))
        list.add(keyID: 2, component: sphere, space: translation(1, 0, 0))
        list.add(keyID: 7, component: cube, space: translation(2, 0, 0))
        list.add(keyID: 7, component: cube, space: translation(3, 0, 0))
        list.add(keyID: 2, component: sphere, space: translation(4, 0, 0))
        list.layOutRecords()

        XCTAssertEqual(list.instanceCount, 5)
        XCTAssertEqual(list.groups.map(\.keyID), [7, 2])
        XCTAssertEqual(list.groups.map(\.instanceCount), [3, 2])
        XCTAssertTrue(list.groupComponents[0] === cube)
        XCTAssertTrue(list.groupComponents[1] === sphere)
        XCTAssertEqual(list.recordCount, 5)
        XCTAssertEqual(list.baseInstance(of: list.groups[0], meshIndex: 0), 0)
        XCTAssertEqual(list.baseInstance(of: list.groups[1], meshIndex: 0), 3)

        // The records of a group follow each other, in the order its entities came.
        let records = shadowRecords(of: &list)
        XCTAssertEqual(records.map(\.columns.3.x), [0, 2, 3, 1, 4])
    }

    func testAnEmptiedListStartsOver() {
        let cube = component(BasicPrimitives.createCube(extent: 1))
        var list = InstancedDrawList()
        list.add(keyID: 3000, component: cube, space: translation(0, 0, 0))
        list.add(keyID: 5, component: cube, space: translation(1, 0, 0))
        list.layOutRecords()

        list.removeAll()

        XCTAssertTrue(list.isEmpty)
        XCTAssertTrue(list.groups.isEmpty)
        XCTAssertTrue(list.groupComponents.isEmpty, "the list lets go of the components it grouped")
        XCTAssertEqual(list.recordCount, 0)

        // The keys of the pass before mean nothing now.
        list.add(keyID: 5, component: cube, space: translation(2, 0, 0))
        list.layOutRecords()
        XCTAssertEqual(list.groups.map(\.keyID), [5])
        XCTAssertEqual(list.groups[0].instanceCount, 1)
        XCTAssertEqual(list.recordCount, 1)
    }

    // MARK: - Records

    func testAModelRecordHoldsWhatThePassComputesForAnEntityDrawnAlone() {
        let cube = component(BasicPrimitives.createCube(extent: 1))
        let view = translation(0, -2, -10)
        var list = InstancedDrawList()
        let spaces = [space(0.1), space(0.7), space(1.3)]
        for space in spaces {
            list.add(keyID: 0, component: cube, space: space)
        }
        list.layOutRecords()

        let records = modelRecords(of: &list, viewMatrix: view)

        XCTAssertEqual(records.count, 3)
        for (index, space) in spaces.enumerated() {
            let modelMatrix = simd_mul(space, cube.mesh[0].localSpace)
            XCTAssertEqual(records[index].modelMatrix, modelMatrix)
            XCTAssertEqual(records[index].modelViewMatrix, simd_mul(view, modelMatrix))
            XCTAssertEqual(records[index].normalMatrix, matrix3x3_upper_left(modelMatrix).inverse.transpose)
            // An entity that is where it was: its previous model matrix is this frame's.
            XCTAssertEqual(records[index].prevModelMatrix, modelMatrix)
        }
    }

    func testEntitiesOfAGhostOpacityAreAGroupOfTheirOwn() {
        // The opacity is the draw's, so a key has a group per opacity among its entities.
        let cube = component(BasicPrimitives.createCube(extent: 1))
        var list = InstancedDrawList()
        list.add(keyID: 4, component: cube, space: translation(0, 0, 0))
        list.add(keyID: 4, component: cube, space: translation(1, 0, 0), passthroughAlpha: 0.35)
        list.add(keyID: 4, component: cube, space: translation(2, 0, 0))
        list.add(keyID: 4, component: cube, space: translation(3, 0, 0), passthroughAlpha: 0.35)
        list.add(keyID: 4, component: cube, space: translation(4, 0, 0), passthroughAlpha: 0.6)

        XCTAssertEqual(list.groups.map(\.keyID), [4, 4, 4])
        XCTAssertEqual(list.groups.map(\.passthroughAlpha), [1, 0.35, 0.6])
        XCTAssertEqual(list.groups.map(\.instanceCount), [2, 2, 1])
        XCTAssertEqual(list.instanceCount, 5)

        // Emptied, the ghost groups are forgotten with the others.
        list.removeAll()
        list.add(keyID: 4, component: cube, space: translation(0, 0, 0), passthroughAlpha: 0.35)
        XCTAssertEqual(list.groups.map(\.passthroughAlpha), [0.35])
        XCTAssertEqual(list.groups.map(\.instanceCount), [1])
    }

    func testAModelRecordHoldsWhereTheEntityWasThePreviousFrame() {
        let cube = component(BasicPrimitives.createCube(extent: 1))
        var list = InstancedDrawList()
        list.add(keyID: 0, component: cube, space: translation(3, 0, 0), previousSpace: translation(1, 0, 0))
        list.add(keyID: 0, component: cube, space: translation(5, 0, 0))
        list.layOutRecords()

        let records = modelRecords(of: &list, viewMatrix: matrix_identity_float4x4)

        XCTAssertEqual(records.count, 2)
        let localSpace = cube.mesh[0].localSpace
        XCTAssertEqual(records[0].modelMatrix, simd_mul(translation(3, 0, 0), localSpace))
        XCTAssertEqual(records[0].prevModelMatrix, simd_mul(translation(1, 0, 0), localSpace), "the previous transform times the mesh's local one, as for a single draw")
        XCTAssertEqual(records[1].prevModelMatrix, records[1].modelMatrix, "an entity that gave no previous transform is where it was")
    }

    func testMeshesWithTheirOwnLocalTransformGetARunOfRecordsEach() {
        // Four meshes: the first two share a local transform, the third has its own, the
        // fourth has the first's again but does not follow it.
        let cube = BasicPrimitives.createCube(extent: 1)
        var meshes = cube + cube + cube + cube
        let left = translation(-1, 0, 0)
        let right = translation(1, 0, 0)
        meshes[0].localSpace = left
        meshes[1].localSpace = left
        meshes[2].localSpace = right
        meshes[3].localSpace = left
        let group = component(meshes)
        let single = component(cube)

        var list = InstancedDrawList()
        list.add(keyID: 0, component: group, space: translation(0, 10, 0))
        list.add(keyID: 1, component: single, space: translation(0, 20, 0))
        list.add(keyID: 0, component: group, space: translation(0, 30, 0))
        list.layOutRecords()

        // Three runs of two records for the first group, then the second group's record.
        XCTAssertEqual(list.groups[0].runCount, 3)
        XCTAssertEqual(list.groups[1].runCount, 1)
        XCTAssertEqual(list.recordCount, 7)
        XCTAssertEqual((0 ..< 4).map { list.baseInstance(of: list.groups[0], meshIndex: $0) }, [0, 0, 2, 4])
        XCTAssertEqual(list.baseInstance(of: list.groups[1], meshIndex: 0), 6)

        let records = shadowRecords(of: &list)
        let positions = records.map { simd_make_float3($0.columns.3) }
        XCTAssertEqual(positions, [
            simd_float3(-1, 10, 0), simd_float3(-1, 30, 0), // meshes 0 and 1
            simd_float3(1, 10, 0), simd_float3(1, 30, 0), // mesh 2
            simd_float3(-1, 10, 0), simd_float3(-1, 30, 0), // mesh 3
            simd_float3(0, 20, 0),
        ])
    }

    func testTheRecordIsLaidOutAsTheShaderReadsIt() {
        // modelViewMatrix, modelMatrix, normalMatrix (three padded columns), parameters.
        XCTAssertEqual(MemoryLayout<ModelInstanceUniform>.stride, 240)
        XCTAssertEqual(MemoryLayout<ModelInstanceUniform>.offset(of: \.modelViewMatrix), 0)
        XCTAssertEqual(MemoryLayout<ModelInstanceUniform>.offset(of: \.modelMatrix), 64)
        XCTAssertEqual(MemoryLayout<ModelInstanceUniform>.offset(of: \.prevModelMatrix), 128)
        XCTAssertEqual(MemoryLayout<ModelInstanceUniform>.offset(of: \.normalMatrix), 192)
    }

    // MARK: - Buffers

    func testABufferGivenBackIsLentAgain() throws {
        let pool = InstanceRecordBufferPool()
        let device = try XCTUnwrap(renderInfo.device)

        let first = try XCTUnwrap(pool.borrow(length: 1000, device: device))
        XCTAssertGreaterThanOrEqual(first.buffer.length, InstanceRecordBufferPool.minimumLength)
        let second = try XCTUnwrap(pool.borrow(length: 1000, device: device))
        XCTAssertFalse(first.buffer === second.buffer, "a buffer in use is not lent twice")
        XCTAssertNotEqual(first.token, second.token)
        XCTAssertEqual(pool.bufferCounts.lent, 2)

        pool.giveBack(first.token)
        XCTAssertEqual(pool.bufferCounts.free, 1)
        XCTAssertEqual(pool.bufferCounts.lent, 1)
        let third = try XCTUnwrap(pool.borrow(length: 2000, device: device))
        XCTAssertTrue(third.buffer === first.buffer)

        // A token that is not out does nothing.
        pool.giveBack(first.token)
        XCTAssertEqual(pool.bufferCounts.lent, 2)
    }

    func testTheSmallestBufferThatFitsIsLent() throws {
        let pool = InstanceRecordBufferPool()
        let device = try XCTUnwrap(renderInfo.device)
        let small = try XCTUnwrap(pool.borrow(length: 10, device: device))
        let large = try XCTUnwrap(pool.borrow(length: InstanceRecordBufferPool.minimumLength * 8, device: device))
        XCTAssertGreaterThanOrEqual(large.buffer.length, InstanceRecordBufferPool.minimumLength * 8)
        pool.giveBack(large.token)
        pool.giveBack(small.token)

        XCTAssertTrue(try XCTUnwrap(pool.borrow(length: 100, device: device)).buffer === small.buffer)
        XCTAssertTrue(try XCTUnwrap(pool.borrow(length: InstanceRecordBufferPool.minimumLength + 1, device: device)).buffer === large.buffer)
        // Nothing free is large enough: a new one.
        let larger = try XCTUnwrap(pool.borrow(length: InstanceRecordBufferPool.minimumLength * 20, device: device))
        XCTAssertGreaterThanOrEqual(larger.buffer.length, InstanceRecordBufferPool.minimumLength * 20)
    }

    func testThePoolKeepsOnlySoManyFreeBuffers() throws {
        let pool = InstanceRecordBufferPool()
        let device = try XCTUnwrap(renderInfo.device)
        let borrowed = try (0 ..< InstanceRecordBufferPool.maximumFreeBuffers + 3).map { index in
            try XCTUnwrap(pool.borrow(length: InstanceRecordBufferPool.minimumLength << (index % 3), device: device))
        }

        for loan in borrowed {
            pool.giveBack(loan.token)
        }

        XCTAssertEqual(pool.bufferCounts.lent, 0)
        XCTAssertEqual(pool.bufferCounts.free, InstanceRecordBufferPool.maximumFreeBuffers)
    }
}
