//
//  NativeFormatRegistrationTests.swift
//  UntoldEngine
//
//  Verifies that `.untold` assets can flow through the public registration APIs
//  and produce renderable entities without the USD/ModelIO file-loading path.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@preconcurrency @testable import UntoldEngine
import XCTest

final class NativeFormatRegistrationTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
    }

    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    func testSetEntityMesh_loadsUntoldMesh() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "UntoldSyncEntity")

        setEntityMesh(entityId: entityId, filename: "redplayer", withExtension: "untold")

        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("RenderComponent should exist for .untold sync load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Sync .untold load should register at least one mesh")
        XCTAssertEqual(renderComponent.assetURL.pathExtension, "untold")
        XCTAssertFalse(renderComponent.assetName.isEmpty, "Sync .untold load should register an asset name")
    }

    func testSetEntityMeshAsync_loadsUntoldMesh() async {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "UntoldAsyncEntity")

        let expectation = XCTestExpectation(description: "Untold mesh loaded asynchronously")
        var loadSuccess = false

        setEntityMeshAsync(
            entityId: entityId,
            filename: "redplayer",
            withExtension: "untold"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertTrue(loadSuccess, "Async .untold load should succeed")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: RenderComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("RenderComponent should exist for .untold async load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Async .untold load should register at least one mesh")
        XCTAssertEqual(renderComponent.assetURL.pathExtension, "untold")
        XCTAssertFalse(renderComponent.assetName.isEmpty, "Async .untold load should register an asset name")
        XCTAssertTrue(renderComponent.isVisible, "Async .untold load should leave the entity visible")
    }

    func testSetEntityMesh_loadsNamedNodeFromUntold() async throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold")
            return
        }

        // Discover the first node that has renderable primitives.
        let asset = try await NativeFormatLoader().loadAsset(from: untoldURL)
        guard let nodeName = asset.nodes.first(where: { !$0.primitives.isEmpty })?.name else {
            XCTFail("redplayer.untold has no nodes with primitives")
            return
        }

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "NamedNodeEntity")

        setEntityMesh(entityId: entityId, filename: "redplayer", withExtension: "untold", assetName: nodeName)

        // Named-node load registers the mesh directly on entityId — no child entities.
        XCTAssertTrue(
            hasComponent(entityId: entityId, componentType: RenderComponent.self),
            "Named-node load must register RenderComponent on entityId for node '\(nodeName)'"
        )
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("RenderComponent must exist after named-node load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Named-node load must produce at least one mesh")
        XCTAssertEqual(renderComponent.assetName, nodeName, "RenderComponent assetName must match requested node name")
    }

    func testSetEntityMesh_returnsFalseForUnknownNodeName() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "BadNameEntity")

        // An unknown assetName should fall back to the fallback mesh, not crash.
        setEntityMesh(entityId: entityId, filename: "redplayer", withExtension: "untold", assetName: "nonexistent_node_xyz")

        // The entity should still have components (fallback mesh registers them),
        // but no RenderComponent with the bad name.
        if let rc = scene.get(component: RenderComponent.self, for: entityId) {
            XCTAssertNotEqual(rc.assetName, "nonexistent_node_xyz", "Fallback must not claim the bad node name")
        }
    }
}
