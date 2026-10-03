//
//  RenderSceneSnapshotTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// `RenderSceneSnapshot` must answer what the scene answers: the passes read entities
/// through it where they used to ask `scene` for each component.
@MainActor
final class RenderSceneSnapshotTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
    }

    @discardableResult
    private func makeRenderEntity() -> EntityID {
        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        return entityId
    }

    // MARK: - Which entities it knows

    func testAnEntityOfTheSceneIsFound() throws {
        let entityId = makeRenderEntity()

        let entity = try XCTUnwrap(RenderSceneSnapshot().entity(entityId))

        XCTAssertEqual(entity.entityId, entityId)
    }

    func testAnEntityWaitingToBeDestroyedIsNotFound() {
        let entityId = makeRenderEntity()
        destroyEntity(entityId: entityId)

        // `scene.mask(for:)`, which the passes asked first, hides it as well.
        XCTAssertNil(scene.mask(for: entityId))
        XCTAssertNil(RenderSceneSnapshot().entity(entityId))
    }

    func testADestroyedEntityIsNotFound() {
        let entityId = makeRenderEntity()
        destroyEntity(entityId: entityId)
        finalizePendingDestroys()

        XCTAssertNil(RenderSceneSnapshot().entity(entityId))
    }

    func testTheIdOfAnEntityThatHadTheIndexBeforeIsNotFound() throws {
        let first = makeRenderEntity()
        destroyEntity(entityId: first)
        finalizePendingDestroys()
        let second = makeRenderEntity()
        try XCTSkipUnless(getEntityIndex(first) == getEntityIndex(second), "The index was not handed out again")

        let snapshot = RenderSceneSnapshot()

        XCTAssertNil(snapshot.entity(first))
        XCTAssertNotNil(snapshot.entity(second))
    }

    func testAnIdPastTheEntitiesOfTheSceneIsNotFound() {
        makeRenderEntity()

        XCTAssertNil(RenderSceneSnapshot().entity(createEntityId(EntityIndex(5000), 0)))
    }

    func testAnEmptySceneHasNoEntities() {
        let snapshot = RenderSceneSnapshot()
        var visited = 0
        snapshot.forEachEntity(with: []) { _ in visited += 1 }

        XCTAssertEqual(snapshot.entityCapacity, 0)
        XCTAssertEqual(visited, 0)
    }

    // MARK: - Traits

    func testTraitsAreTheComponentsOfTheEntity() throws {
        let plain = createEntity()
        let cases: [(RenderEntityTraits, any Component.Type)] = [
            (.render, RenderComponent.self),
            (.gizmo, GizmoComponent.self),
            (.light, LightComponent.self),
            (.camera, CameraComponent.self),
            (.sceneCamera, SceneCameraComponent.self),
            (.sceneChannels, EntitySceneChannelsComponent.self),
            (.staticBatch, StaticBatchComponent.self),
            (.meshOccluder, MeshOccluderComponent.self),
            (.meshFade, MeshFadeComponent.self),
            (.tileRepresentationFade, TileRepresentationFadeComponent.self),
            (.lod, LODComponent.self),
            (.deformation, DeformationComponent.self),
            (.skeleton, SkeletonComponent.self),
            (.tileLODTag, TileLODTagComponent.self),
        ]
        var entities: [EntityID] = []
        for (_, componentType) in cases {
            let entityId = createEntity()
            registerComponent(entityId: entityId, componentType: componentType)
            entities.append(entityId)
        }

        let snapshot = RenderSceneSnapshot()

        // createEntity gives every entity its two transforms.
        let transforms: RenderEntityTraits = [.worldTransform, .localTransform]
        XCTAssertEqual(try XCTUnwrap(snapshot.entity(plain)).traits, transforms)
        for (index, (trait, componentType)) in cases.enumerated() {
            let traits = try XCTUnwrap(snapshot.entity(entities[index])).traits
            XCTAssertEqual(traits, transforms.union(trait), "\(componentType)")
        }
    }

    func testTraitsAgreeWithHasComponentForEveryEntity() {
        let components: [(RenderEntityTraits, any Component.Type)] = [
            (.render, RenderComponent.self),
            (.light, LightComponent.self),
            (.lod, LODComponent.self),
            (.meshFade, MeshFadeComponent.self),
            (.staticBatch, StaticBatchComponent.self),
        ]
        var generator = SystemRandomNumberGenerator()
        var entities: [EntityID] = []
        for _ in 0 ..< 200 {
            let entityId = createEntity()
            for (_, componentType) in components where Bool.random(using: &generator) {
                registerComponent(entityId: entityId, componentType: componentType)
            }
            entities.append(entityId)
        }

        let snapshot = RenderSceneSnapshot()

        for entityId in entities {
            guard let entity = snapshot.entity(entityId) else {
                XCTFail("Entity \(entityId) is missing")
                continue
            }
            for (trait, componentType) in components {
                XCTAssertEqual(
                    entity.traits.contains(trait),
                    hasComponent(entityId: entityId, componentType: componentType),
                    "\(componentType) of \(entityId)"
                )
            }
        }
    }

    // MARK: - Components

    func testDrawComponentsAreTheObjectsOfTheScene() throws {
        let entityId = makeRenderEntity()

        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))
        let components = try XCTUnwrap(snapshot.drawComponents(of: entity))

        XCTAssertTrue(components.render === scene.get(component: RenderComponent.self, for: entityId))
        XCTAssertTrue(components.world === scene.get(component: WorldTransformComponent.self, for: entityId))
        XCTAssertTrue(components.local === scene.get(component: LocalTransformComponent.self, for: entityId))
        XCTAssertTrue(snapshot.render(of: entity) === components.render)
        XCTAssertTrue(snapshot.worldTransform(of: entity) === components.world)
        XCTAssertTrue(snapshot.localTransform(of: entity) === components.local)
    }

    func testAnEntityWithoutARenderComponentHasNoDrawComponents() throws {
        let entityId = createEntity()

        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))

        XCTAssertNil(snapshot.drawComponents(of: entity))
        XCTAssertNil(snapshot.render(of: entity))
        XCTAssertNotNil(snapshot.worldTransform(of: entity))
    }

    func testOptionalComponentsAreTheObjectsOfTheScene() throws {
        let entityId = makeRenderEntity()
        registerComponent(entityId: entityId, componentType: LODComponent.self)
        registerComponent(entityId: entityId, componentType: MeshOccluderComponent.self)
        registerComponent(entityId: entityId, componentType: MeshFadeComponent.self)
        registerComponent(entityId: entityId, componentType: TileRepresentationFadeComponent.self)
        registerComponent(entityId: entityId, componentType: DeformationComponent.self)
        registerComponent(entityId: entityId, componentType: TileLODTagComponent.self)
        let bare = makeRenderEntity()

        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))
        let bareEntity = try XCTUnwrap(snapshot.entity(bare))

        XCTAssertTrue(snapshot.lod(of: entity) === scene.get(component: LODComponent.self, for: entityId))
        XCTAssertTrue(snapshot.meshOccluder(of: entity) === scene.get(component: MeshOccluderComponent.self, for: entityId))
        XCTAssertTrue(snapshot.meshFade(of: entity) === scene.get(component: MeshFadeComponent.self, for: entityId))
        XCTAssertTrue(snapshot.tileRepresentationFade(of: entity) === scene.get(component: TileRepresentationFadeComponent.self, for: entityId))
        XCTAssertTrue(snapshot.deformation(of: entity) === scene.get(component: DeformationComponent.self, for: entityId))
        XCTAssertTrue(snapshot.tileLODTag(of: entity) === scene.get(component: TileLODTagComponent.self, for: entityId))
        XCTAssertNil(snapshot.lod(of: bareEntity))
        XCTAssertNil(snapshot.meshOccluder(of: bareEntity))
        XCTAssertNil(snapshot.meshFade(of: bareEntity))
        XCTAssertNil(snapshot.tileRepresentationFade(of: bareEntity))
        XCTAssertNil(snapshot.deformation(of: bareEntity))
        XCTAssertNil(snapshot.tileLODTag(of: bareEntity))
    }

    func testAValueChangedAfterTheSnapshotIsSeenThroughIt() throws {
        let entityId = makeRenderEntity()
        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))

        scene.get(component: RenderComponent.self, for: entityId)?.isVisible = false

        XCTAssertEqual(snapshot.render(of: entity)?.isVisible, false)
    }

    // MARK: - Walking the scene

    func testTheWalkVisitsTheEntitiesTheSceneQueryReturns() {
        var generator = SystemRandomNumberGenerator()
        var entities: [EntityID] = []
        for _ in 0 ..< 300 {
            entities.append(Bool.random(using: &generator) ? makeRenderEntity() : createEntity())
        }
        // Holes, entities waiting to be destroyed, and indices handed out again.
        for entityId in entities where Int.random(in: 0 ..< 4, using: &generator) == 0 {
            destroyEntity(entityId: entityId)
        }
        finalizePendingDestroys()
        for _ in 0 ..< 40 {
            entities.append(makeRenderEntity())
        }
        for entityId in entities.suffix(10) {
            destroyEntity(entityId: entityId)
        }

        var visited: [EntityID] = []
        RenderSceneSnapshot().forEachEntity(with: .drawable) { visited.append($0.entityId) }

        let expected = queryEntitiesWithComponentIds(
            [
                getComponentId(for: RenderComponent.self),
                getComponentId(for: WorldTransformComponent.self),
                getComponentId(for: LocalTransformComponent.self),
            ],
            in: scene
        )
        XCTAssertEqual(Set(visited), Set(expected))
        XCTAssertEqual(visited.count, expected.count)
        XCTAssertFalse(visited.isEmpty)
        XCTAssertEqual(visited.map(getEntityIndex), visited.map(getEntityIndex).sorted(), "The walk follows the entity indices")
    }

    func testTheWalkWithNoTraitsVisitsEveryLiveEntity() {
        let kept = [createEntity(), makeRenderEntity(), createEntity()]
        let destroyed = createEntity()
        destroyEntity(entityId: destroyed)

        var visited: [EntityID] = []
        RenderSceneSnapshot().forEachEntity(with: []) { visited.append($0.entityId) }

        XCTAssertEqual(visited, kept)
        XCTAssertEqual(Set(visited), Set(scene.getAllEntities()))
    }

    // MARK: - A snapshot is the scene at one moment

    func testASnapshotKeepsTheComponentsItSaw() throws {
        let entityId = makeRenderEntity()
        let snapshot = RenderSceneSnapshot()

        scene.remove(component: RenderComponent.self, from: entityId)
        let later = makeRenderEntity()

        let entity = try XCTUnwrap(snapshot.entity(entityId))
        XCTAssertTrue(entity.traits.contains(.render))
        XCTAssertNotNil(snapshot.drawComponents(of: entity))
        XCTAssertNil(snapshot.entity(later), "An entity made after the snapshot is not in it")

        let next = RenderSceneSnapshot()
        XCTAssertFalse(try XCTUnwrap(next.entity(entityId)).traits.contains(.render))
        XCTAssertNotNil(next.entity(later))
    }

    // MARK: - Scene channels

    func testSceneChannelsComeFromTheChannelComponent() throws {
        let entityId = makeRenderEntity()
        setEntitySceneChannels(entityId: entityId, channels: [.ghostGeometry, .userCustom(index: 3)])

        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))

        XCTAssertEqual(snapshot.sceneChannels(of: entity), [.ghostGeometry, .userCustom(index: 3)])
        XCTAssertEqual(snapshot.sceneChannels(of: entity), getEntitySceneChannels(entityId: entityId))
    }

    func testAnEntityWithoutTheChannelComponentGetsTheChannelsOfItsName() throws {
        let context = makeRenderEntity()
        let selectable = makeRenderEntity()
        setEntityName(entityId: selectable, name: "\(selectableSceneEntityNamePrefix)Door")
        let notRenderable = createEntity()

        let snapshot = RenderSceneSnapshot()

        for entityId in [context, selectable, notRenderable] {
            let entity = try XCTUnwrap(snapshot.entity(entityId))
            XCTAssertFalse(entity.traits.contains(.sceneChannels))
            XCTAssertEqual(snapshot.sceneChannels(of: entity), getEntitySceneChannels(entityId: entityId))
        }
        try XCTAssertEqual(snapshot.sceneChannels(of: XCTUnwrap(snapshot.entity(context))), .contextGeometry)
        try XCTAssertEqual(snapshot.sceneChannels(of: XCTUnwrap(snapshot.entity(selectable))), [.selectableGeometry, .preserveIdentity])
        try XCTAssertEqual(snapshot.sceneChannels(of: XCTUnwrap(snapshot.entity(notRenderable))), [])
    }

    func testAChannelChangedAfterTheSnapshotIsSeenThroughIt() throws {
        let entityId = makeRenderEntity()
        setEntitySceneChannels(entityId: entityId, channels: .contextGeometry)
        let snapshot = RenderSceneSnapshot()
        let entity = try XCTUnwrap(snapshot.entity(entityId))

        setEntitySceneChannels(entityId: entityId, channels: .ghostGeometry)

        XCTAssertEqual(snapshot.sceneChannels(of: entity), .ghostGeometry)
    }

    // MARK: - Render mode memo

    func testTheMemoGivesTheRenderModeOfEachChannelSet() {
        setSceneChannel(.contextGeometry, .renderMode(.hidden))
        setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.25)))
        setSceneChannel(.userCustom(index: 1), .renderMode(.wireframe))
        var memo = SceneChannelRenderModeMemo()

        let sequence: [SceneChannel] = [
            .contextGeometry, .contextGeometry, .ghostGeometry, [], .userCustom(index: 1),
            .selectableGeometry, [.ghostGeometry, .userCustom(index: 1)], .contextGeometry, [],
        ]
        for channels in sequence {
            XCTAssertEqual(memo.mode(of: channels), getSceneChannelRenderMode(channels), "\(channels)")
        }
    }

    func testAMemoWithNoEntityBeforeAsksForTheModeOfTheEmptySet() {
        var memo = SceneChannelRenderModeMemo()

        XCTAssertEqual(memo.mode(of: []), .normal)
    }
}
