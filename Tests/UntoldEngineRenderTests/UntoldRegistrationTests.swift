//
//  UntoldRegistrationTests.swift
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

final class UntoldRegistrationTests: BaseRenderSetup {
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
}
