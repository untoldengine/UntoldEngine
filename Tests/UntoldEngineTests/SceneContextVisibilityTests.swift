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

    func testUserCustomSceneChannelsUseReservedUpperBits() {
        XCTAssertEqual(SceneChannel.userCustom(index: 0).rawValue, UInt64(1) << 32)
        XCTAssertEqual(SceneChannel.userCustom(index: 31).rawValue, UInt64(1) << 63)
        XCTAssertTrue(SceneChannel.engineReservedMask.intersection(.userCustom(index: 0)).isEmpty)
        XCTAssertTrue(SceneChannel.userCustomMask.intersection(.contextGeometry).isEmpty)
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

    func testSceneChannelLightPortalDefaultsToDisabled() {
        XCTAssertEqual(getSceneChannelLightPortalMode(.contextGeometry), .disabled)
        XCTAssertFalse(shouldUseSceneChannelsAsLightPortals(.contextGeometry))
        XCTAssertFalse(hasSceneChannelLightPortalsEnabled())
    }

    func testSceneChannelLightPortalCanBeEnabledAndDisabled() {
        let windowChannel = SceneChannel.userCustom(index: 1)

        setSceneChannel(windowChannel, .lightPortal(.enabled(
            intensity: 1.25,
            range: 7.5,
            useRealWorldTint: true,
            maxActivePortals: 6,
            activationDistance: 18.0
        )))

        XCTAssertEqual(
            getSceneChannelLightPortalMode(windowChannel),
            .enabled(
                intensity: 1.25,
                range: 7.5,
                useRealWorldTint: true,
                maxActivePortals: 6,
                activationDistance: 18.0
            )
        )
        XCTAssertTrue(shouldUseSceneChannelsAsLightPortals(windowChannel))
        XCTAssertTrue(hasSceneChannelLightPortalsEnabled())

        setSceneChannel(windowChannel, .lightPortal(.disabled))

        XCTAssertEqual(getSceneChannelLightPortalMode(windowChannel), .disabled)
        XCTAssertFalse(shouldUseSceneChannelsAsLightPortals(windowChannel))
        XCTAssertFalse(hasSceneChannelLightPortalsEnabled())
    }

    func testSceneChannelLightPortalValuesAreClamped() {
        let windowChannel = SceneChannel.userCustom(index: 1)

        setSceneChannel(windowChannel, .lightPortal(.enabled(
            intensity: -1.0,
            range: -5.0,
            useRealWorldTint: false,
            maxActivePortals: -4,
            activationDistance: -.infinity
        )))

        XCTAssertEqual(
            getSceneChannelLightPortalMode(windowChannel),
            .enabled(
                intensity: 0.0,
                range: 0.001,
                useRealWorldTint: false,
                maxActivePortals: 0,
                activationDistance: 15.0
            )
        )
    }

    func testCombinedSceneChannelLightPortalUsesMostPermissiveValues() {
        let broadChannel = SceneChannel.userCustom(index: 1)
        let specificChannel = SceneChannel.userCustom(index: 2)

        setSceneChannel(broadChannel, .lightPortal(.enabled(
            intensity: 0.75,
            range: 4.0,
            useRealWorldTint: false,
            maxActivePortals: 4,
            activationDistance: 10.0
        )))
        setSceneChannel(specificChannel, .lightPortal(.enabled(
            intensity: 1.5,
            range: 8.0,
            useRealWorldTint: true,
            maxActivePortals: 2,
            activationDistance: 20.0
        )))

        XCTAssertEqual(
            sceneChannelLightPortalMode(for: [broadChannel, specificChannel]),
            .enabled(
                intensity: 1.5,
                range: 8.0,
                useRealWorldTint: true,
                maxActivePortals: 4,
                activationDistance: 20.0
            )
        )
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

    func testRegisteredPrefixAssignsUserCustomDefaultSceneChannel() {
        let ceilingChannel = SceneChannel.userCustom(index: 0)
        registerSceneChannelPrefix("CEIL_", channels: ceilingChannel)

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "CEIL_Level01_A")
        _ = scene.assign(to: entityId, component: RenderComponent.self)

        XCTAssertEqual(getEntitySceneChannels(entityId: entityId), ceilingChannel)

        setSceneChannel(ceilingChannel, .renderMode(.wireframe))

        XCTAssertTrue(shouldRenderSceneEntityAsWireframe(entityId: entityId))
        XCTAssertFalse(shouldRenderSceneChannelsOpaque(ceilingChannel))
    }

    func testRegisteredPrefixUsesLongestMatchingPrefix() {
        let broadChannel = SceneChannel.userCustom(index: 0)
        let specificChannel = SceneChannel.userCustom(index: 1)
        registerSceneChannelPrefix("WIN_", channels: broadChannel)
        registerSceneChannelPrefix("WIN_GLASS_", channels: specificChannel)

        XCTAssertEqual(defaultSceneChannels(forName: "WIN_Frame_01"), broadChannel)
        XCTAssertEqual(defaultSceneChannels(forName: "WIN_GLASS_Main_01"), specificChannel)
    }

    func testSelectablePrefixTakesPrecedenceOverRegisteredPrefix() {
        let customChannel = SceneChannel.userCustom(index: 0)
        registerSceneChannelPrefix("NM_", channels: customChannel)

        XCTAssertEqual(defaultSceneChannels(forName: "NM_Pipe_001"), [.selectableGeometry, .preserveIdentity])
    }

    func testUnregisteredPrefixFallsBackToContextGeometry() {
        let customChannel = SceneChannel.userCustom(index: 0)
        registerSceneChannelPrefix("CEIL_", channels: customChannel)
        unregisterSceneChannelPrefix("CEIL_")

        XCTAssertEqual(defaultSceneChannels(forName: "CEIL_Level01_A"), .contextGeometry)
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
