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
        setSceneChannel(.contextGeometry, .renderMode(.hidden))
        XCTAssertFalse(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .hidden)

        setSceneChannel(.contextGeometry, .renderMode(.normal))
        XCTAssertTrue(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .normal)
    }

    func testContextSceneChannelCanUseWireframeRenderMode() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        setSceneChannel(.contextGeometry, .renderMode(.wireframe))

        XCTAssertTrue(getSceneChannelVisible(.contextGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .wireframe)
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
        XCTAssertTrue(shouldRenderSceneEntityAsWireframe(entityId: entityId))
        XCTAssertTrue(shouldRenderSceneChannelsAsWireframe(.contextGeometry))
        XCTAssertFalse(shouldRenderSceneChannelsOpaque(.contextGeometry))
    }

    func testContextSceneChannelCanUsePassthroughGhostRenderMode() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .ghostGeometry)

        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        XCTAssertTrue(getSceneChannelVisible(.ghostGeometry))
        XCTAssertEqual(getSceneChannelRenderMode(.ghostGeometry), .passthroughGhost(opacity: 0.35))
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
        XCTAssertFalse(shouldRenderSceneEntityAsWireframe(entityId: entityId))
        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: entityId))
        XCTAssertFalse(shouldRenderSceneChannelsAsWireframe(.ghostGeometry))
        XCTAssertTrue(shouldRenderSceneChannelsOpaque(.ghostGeometry))
        XCTAssertEqual(passthroughGhostOpacity(for: .ghostGeometry), 0.35)
    }

    func testGhostGeometryIsDedicatedSelectableChannel() {
        let ghostWall = createEntity()
        let normalWall = createEntity()
        setEntitySceneChannels(entityId: ghostWall, channels: .ghostGeometry)
        setEntitySceneChannels(entityId: normalWall, channels: .contextGeometry)

        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        XCTAssertTrue(hasEntitySceneChannel(entityId: ghostWall, channel: .ghostGeometry))
        XCTAssertFalse(hasEntitySceneChannel(entityId: normalWall, channel: .ghostGeometry))
        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: ghostWall))
        XCTAssertFalse(shouldRenderSceneEntityAsPassthroughGhost(entityId: normalWall))
    }

    func testContextGeometryPassthroughGhostControlsWholeContextScene() {
        let wallA = createEntity()
        let wallB = createEntity()
        let selectedPipe = createEntity()
        setEntitySceneChannels(entityId: wallA, channels: .contextGeometry)
        setEntitySceneChannels(entityId: wallB, channels: .contextGeometry)
        setEntitySceneChannels(entityId: selectedPipe, channels: [.selectableGeometry, .preserveIdentity])

        setSceneChannel(.contextGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: wallA))
        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: wallB))
        XCTAssertFalse(shouldRenderSceneEntityAsPassthroughGhost(entityId: selectedPipe))
        XCTAssertEqual(passthroughGhostOpacity(for: .contextGeometry), 0.35)
    }

    func testAddGhostGeometryPreservesExistingChannels() {
        let wall = createEntity()
        setEntitySceneChannels(entityId: wall, channels: [.contextGeometry, .preserveIdentity])

        addEntitySceneChannels(entityId: wall, channels: .ghostGeometry)
        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))

        XCTAssertTrue(hasEntitySceneChannel(entityId: wall, channel: .contextGeometry))
        XCTAssertTrue(hasEntitySceneChannel(entityId: wall, channel: .ghostGeometry))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: wall))
        XCTAssertTrue(shouldRenderSceneEntityAsPassthroughGhost(entityId: wall))
    }

    func testPassthroughGhostOpacityIsClamped() {
        setSceneChannel(.contextGeometry, .renderMode(.passthroughGhost(opacity: 1.5)))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .passthroughGhost(opacity: 1.0))
        XCTAssertEqual(passthroughGhostOpacity(for: .contextGeometry), 1.0)

        setSceneChannel(.contextGeometry, .renderMode(.passthroughGhost(opacity: -0.25)))
        XCTAssertEqual(getSceneChannelRenderMode(.contextGeometry), .passthroughGhost(opacity: 0.0))
        XCTAssertEqual(passthroughGhostOpacity(for: .contextGeometry), 0.0)
    }

    func testHiddenAndWireframePrecedenceOverPassthroughGhost() {
        setSceneChannel(.contextGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
        setSceneChannel(.selectableGeometry, .renderMode(.wireframe))
        XCTAssertEqual(getSceneChannelRenderMode([.contextGeometry, .selectableGeometry]), .wireframe)

        setSceneChannel(.preserveIdentity, .renderMode(.hidden))
        XCTAssertEqual(getSceneChannelRenderMode([.contextGeometry, .selectableGeometry, .preserveIdentity]), .hidden)
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

        setSceneChannel(.contextGeometry, .renderMode(.hidden))

        XCTAssertFalse(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(isNonSelectableSceneContextEntity(entityId: entityId))
        XCTAssertTrue(shouldHideSceneEntity(entityId: entityId))
    }

    func testExplicitSceneChannelsOverrideNameFallback() {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "Wall_North")
        setEntitySceneChannels(entityId: entityId, channels: [.selectableGeometry, .preserveIdentity])

        setSceneChannel(.contextGeometry, .renderMode(.hidden))

        XCTAssertTrue(isSelectableSceneEntity(entityId: entityId))
        XCTAssertTrue(shouldPreserveSceneEntityIdentity(entityId: entityId))
        XCTAssertFalse(isNonSelectableSceneContextEntity(entityId: entityId))
        XCTAssertFalse(shouldHideSceneEntity(entityId: entityId))
    }

    func testSceneChannelVisibilityCanHideExplicitChannel() {
        let entityId = createEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)

        setSceneChannel(.contextGeometry, .renderMode(.hidden))

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
