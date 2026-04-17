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

        // The root entity always gets transform + scenegraph components.
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        // redplayer.untold is hierarchical: the skinned mesh lives on a child entity,
        // not the root. Resolve down to the entity that carries the render component.
        let renderEntityId = resolveEntityForAnimationBinding(entityId: entityId) ?? entityId
        XCTAssertTrue(hasComponent(entityId: renderEntityId, componentType: RenderComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: renderEntityId) else {
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
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        // redplayer.untold is hierarchical: the skinned mesh lives on a child entity,
        // not the root. Resolve down to the entity that carries the render component.
        let renderEntityId = resolveEntityForAnimationBinding(entityId: entityId) ?? entityId
        XCTAssertTrue(hasComponent(entityId: renderEntityId, componentType: RenderComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: renderEntityId) else {
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

    func testSetEntityAnimations_resolvesHierarchicalUntoldRootToSkinnedDescendant() throws {
        guard let modelURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold")
            return
        }
        guard let animationURL = Bundle.module.url(forResource: "running", withExtension: "untold") else {
            XCTFail("Failed to locate running.untold")
            return
        }

        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, subName in
            if name == "redplayer", ext == "untold" {
                return modelURL
            }
            if name == "running", ext == "untold" {
                return animationURL
            }
            return getResourceURL(resourceName: name, ext: ext, subName: subName)
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        let rootEntity = createEntity()
        setEntityName(entityId: rootEntity, name: "HierarchicalUntoldRoot")

        setEntityMesh(entityId: rootEntity, filename: "redplayer", withExtension: "untold")

        let bindingEntity = try XCTUnwrap(resolveEntityForAnimationBinding(entityId: rootEntity))
        XCTAssertNotEqual(bindingEntity, rootEntity)
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: SkeletonComponent.self))
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: RenderComponent.self))

        setEntityAnimations(entityId: rootEntity, filename: "running", withExtension: "untold", name: "running")

        let clipNames = getAllAnimationClips(entityId: rootEntity)
        XCTAssertTrue(clipNames.contains("running"))
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: AnimationComponent.self))

        changeAnimation(entityId: rootEntity, name: "running")

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: bindingEntity) else {
            XCTFail("AnimationComponent should exist on the resolved binding entity")
            return
        }

        XCTAssertNotNil(animationComponent.currentAnimation)
    }
}
