//
//  SceneContextVisibilityTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

@MainActor
final class SceneContextVisibilityTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    func testContextSceneChannelVisibilityDefaultsToVisible() {
        XCTAssertTrue(getSceneChannelVisible(.contextGeometry))
    }

    func testContextSceneChannelVisibilityCanToggle() {
        setSceneChannelVisible(.contextGeometry, false)
        XCTAssertFalse(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .hidden)

        setSceneChannelVisible(.contextGeometry, true)
        XCTAssertTrue(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .normal)
    }

    func testContextSceneChannelCanUseWireframeRenderMode() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        setSceneChannelRenderMode(.contextGeometry, .wireframe)

        XCTAssertTrue(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .wireframe)
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
        XCTAssertTrue(shouldRenderSceneEntityAsWireframe(entityId: entityId))
        XCTAssertTrue(shouldRenderSceneChannelsAsWireframe(.contextGeometry))
        XCTAssertFalse(shouldRenderSceneChannelsOpaque(.contextGeometry))
    }

    func testNMNamedEntityIsSelectableSceneEntity() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "NM_Pipe_001")

        XCTAssertTrue(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(hasEntitySceneChannel(entityId: entityId, channel: .selectableGeometry))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: entityId))
        XCTAssertFalse(isNonSelectableSceneContextEntity(entityId: entityId))
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
    }

    func testNonNMEntityIsHiddenWhenNonSelectableSceneIsHidden() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "Wall_North")
        _ = scene.assign(to: entityId, component: RenderComponent.self)

        setSceneChannelVisible(.contextGeometry, false)

        XCTAssertFalse(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(isNonSelectableSceneContextEntity(entityId: entityId))
        XCTAssertTrue(shouldHideSceneEntity(entityId: entityId))
    }

    func testExplicitSceneChannelsOverrideNameFallback() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "Wall_North")
        setEntitySceneChannels(entityId: entityId, channels: [.selectableGeometry, .preserveIdentity])

        setSceneChannelVisible(.contextGeometry, false)

        XCTAssertTrue(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: entityId))
        XCTAssertFalse(isNonSelectableSceneContextEntity(entityId: entityId))
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
    }

    func testSceneChannelVisibilityCanHideExplicitChannel() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        setSceneChannelVisible(.contextGeometry, false)

        XCTAssertTrue(hasEntitySceneChannel(entityId: entityId, channel: .contextGeometry))
        XCTAssertTrue(shouldHideSceneEntity(entityId: entityId))
    }

    func testRemovingLastSceneChannelRemovesComponent() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        removeEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        XCTAssertNil(scene.get(component: EntitySceneChannelsComponent.self, for: entityId))
    }

    func testDefaultSceneChannelsRefreshWhenEntityNameChanges() {
        let entityId = createEntity()
        _ = scene.assign(to: entityId, component: RenderComponent.self)
        setDefaultEntitySceneChannels(entityId: entityId, channels: defaultSceneChannels(forName: "Wall_North"))

        setEntityName(entityId: entityId, name: "NM_Pipe_001")

        XCTAssertTrue(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: entityId))
        XCTAssertFalse(isNonSelectableSceneContextEntity(entityId: entityId))
    }

    func testExplicitSceneChannelsDoNotRefreshWhenEntityNameChanges() {
        let entityId = createEntity()
        _ = scene.assign(to: entityId, component: RenderComponent.self)
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        setEntityName(entityId: entityId, name: "NM_Pipe_001")

        XCTAssertFalse(isSelectableSceneEntity(entityId: entityId))
        XCTAssertFalse(shouldPreserveSceneEntityIdentity(entityId: entityId))
        XCTAssertTrue(isNonSelectableSceneContextEntity(entityId: entityId))
    }
}
