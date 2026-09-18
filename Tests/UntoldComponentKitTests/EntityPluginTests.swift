//
//  EntityPluginTests.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldComponentKit
@testable import UntoldEngine
import XCTest

@MainActor
final class EntityPluginTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    // MARK: The kind

    func testDefaultsComeFromTheTypeName() {
        XCTAssertEqual(MarkerEntity.typeName, "MarkerEntity")
        XCTAssertEqual(MarkerEntity.displayName, "Marker", "a trailing EntityPlugin, Plugin or Entity is dropped")
        XCTAssertEqual(PathEntity.displayName, "Path")
        XCTAssertEqual(RulesEntityPlugin.displayName, "Game Rules", "an override wins")
        XCTAssertEqual(MarkerEntity.shelf, .entities)
        XCTAssertEqual(MarkerEntity.systemImage, "flag")
        XCTAssertEqual(EntityPlugin.systemImage, "cube.transparent")
        XCTAssertEqual(UntoldEntityShelf.allCases.map(\.title), ["Primitives", "Lights", "Entities"])
        XCTAssertEqual(SpinnerComponent.displayName, "Spinner Component", "component names are left as written")
    }

    func testRegistryListsKindsByShelf() {
        XCTAssertTrue(EntityPluginRegistry.shared.register(MarkerEntity.self, revision: 4))
        XCTAssertTrue(EntityPluginRegistry.shared.register(RulesEntityPlugin.self))
        XCTAssertTrue(EntityPluginRegistry.shared.register(MarkerEntity.self), "registering the same type again is fine")
        XCTAssertEqual(EntityPluginRegistry.shared.entries.first { $0.name == "MarkerEntity" }?.revision, 4, "and changes nothing, not even the revision")

        XCTAssertEqual(EntityPluginRegistry.shared.entries.map(\.name), ["RulesEntityPlugin", "MarkerEntity"], "sorted by display name")
        XCTAssertEqual(EntityPluginRegistry.shared.entries(on: .entities).map(\.name), ["MarkerEntity"])
        XCTAssertEqual(EntityPluginRegistry.shared.entries(on: .lights).map(\.name), ["RulesEntityPlugin"])
        XCTAssertTrue(EntityPluginRegistry.shared.entries(on: .primitives).isEmpty)

        EntityPluginRegistry.shared.unregister(name: "RulesEntityPlugin")
        XCTAssertNil(EntityPluginRegistry.shared.type(named: "RulesEntityPlugin"))
        XCTAssertNotNil(EntityPluginRegistry.shared.type(named: "MarkerEntity"))
    }

    func testDiscoveryFindsEntityPluginsAndNothingElse() throws {
        let imagePath = try XCTUnwrap(ImageDiscovery.imagePath(containing: MarkerEntity.self))
        let names = EntityPluginRegistry.shared.discover(imagePath: imagePath, revision: 2)

        XCTAssertEqual(names, ["MarkerEntity", "PathEntity", "RulesEntityPlugin"])
        XCTAssertEqual(EntityPluginRegistry.shared.entries.first { $0.name == "PathEntity" }?.revision, 2)
        XCTAssertTrue(EntityPluginRegistry.shared.discover(imagePath: "/nonexistent/image.dylib").isEmpty)

        let components = ComponentPluginRegistry.shared.discover(imagePath: imagePath)
        XCTAssertFalse(components.registered.contains("MarkerEntity"), "a kind of entity is not a component")
        XCTAssertTrue(components.registered.contains("SpinnerComponent"))
    }

    // MARK: The entity

    func testInstantiateBindsThePluginThenTellsItItIsNew() throws {
        EntityPluginRegistry.shared.register(MarkerEntity.self)

        let entity = try XCTUnwrap(EntityPluginRegistry.shared.instantiate("MarkerEntity", at: SIMD3<Float>(1, 2, 3)))
        XCTAssertEqual(getEntityName(entityId: entity), "Marker")
        XCTAssertEqual(getLocalPosition(entityId: entity), SIMD3<Float>(1, 2, 3))

        let marker = try XCTUnwrap(EntityPluginRegistry.plugin(MarkerEntity.self, on: entity))
        XCTAssertEqual(marker.entity, entity)
        XCTAssertTrue(marker.isAttached)
        XCTAssertEqual(marker.events, ["attach", "create"], "bound first, so onCreate can work on the entity")
        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.typeName), ["SpinnerComponent"], "what onCreate added")
        XCTAssertEqual(ComponentPluginRegistry.component(SpinnerComponent.self, on: entity)?.speed, 7)

        XCTAssertEqual(EntityPluginRegistry.entities(of: MarkerEntity.self), [entity])
        XCTAssertNil(EntityPluginRegistry.plugin(PathEntity.self, on: entity), "it is a marker, not a path")
        XCTAssertNil(EntityPluginRegistry.shared.instantiate("Missing"))

        let typed = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(PathEntity.self, entityName: "Route"))
        XCTAssertEqual(getEntityName(entityId: typed.entity), "Route")
    }

    func testTheEntitysOwnPropertiesAreEditedLikeAComponents() throws {
        let rules = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(RulesEntityPlugin.self))
        let entity = rules.entity

        let slot = try XCTUnwrap(ScenePluginSystem.shared.entitySlot(on: entity))
        XCTAssertEqual(slot.typeName, "RulesEntityPlugin")
        XCTAssertTrue(slot.isBound)
        XCTAssertEqual(slot.payload, ["limit": .number(3)])
        XCTAssertEqual(rules.untoldAttributes().map(\.displayLabel), ["Score To Win"])
        XCTAssertTrue(ScenePluginSystem.shared.slots(on: entity).isEmpty, "its properties are not a component")

        XCTAssertTrue(ScenePluginSystem.shared.setAttribute("limit", of: "RulesEntityPlugin", on: entity, to: .number(9)))
        XCTAssertEqual(rules.limit, 9)
        XCTAssertEqual(rules.events, ["edited:limit"])

        XCTAssertTrue(ScenePluginSystem.shared.performAction("Reset", of: "RulesEntityPlugin", on: entity))
        XCTAssertEqual(rules.limit, 3)
        XCTAssertFalse(ScenePluginSystem.shared.setAttribute("limit", of: "SomethingElse", on: entity, to: .number(1)))
    }

    func testAnEntityPluginLivesThroughPlayLikeAComponent() throws {
        let rules = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(RulesEntityPlugin.self))
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: rules.entity))
        spinner.events.removeAll()

        gameMode = true
        ScenePluginSystem.shared.startPlayMode()
        ScenePluginSystem.shared.update(deltaTime: 0.25, context: makeKitTestContext())
        ScenePluginSystem.shared.stopPlayMode()
        gameMode = false

        XCTAssertEqual(rules.events, ["start", "update:0.25", "stop"])
        XCTAssertEqual(spinner.events, ["start", "update:0.25", "stop"])
    }

    func testTheEditorRepresentationBelongsToTheEntityAndFollowsItsProperties() throws {
        XCTAssertEqual(try XCTUnwrap(EntityPluginRegistry.shared.instantiate(RulesEntityPlugin.self)).editorRepresentation, .none)
        XCTAssertTrue(EditorRepresentation.none.isEmpty)

        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self))
        XCTAssertEqual(marker.editorRepresentation, .icon(systemImage: "flag.fill", tint: SIMD3<Float>(0.2, 0.8, 0.4)))
        marker.team = 2
        XCTAssertEqual(marker.editorRepresentation, .icon(systemImage: "flag.fill", tint: SIMD3<Float>(0.9, 0.3, 0.3)))
        XCTAssertEqual(EditorRepresentation.icon(systemImage: "flag").items, [.icon(systemImage: "flag", tint: SIMD3<Float>(1, 1, 1))])
        XCTAssertEqual(
            EditorRepresentation([.handles(properties: ["start", "end"], tint: .one)]).items,
            [.handles(properties: ["start", "end"], tint: SIMD3<Float>(1, 1, 1))]
        )

        let path = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(PathEntity.self))
        path.end = SIMD3<Float>(0, 2, 0)
        XCTAssertEqual(path.editorRepresentation.items, [
            .polyline([.zero, SIMD3<Float>(0, 2, 0)], closed: false),
            .points([.zero, SIMD3<Float>(0, 2, 0)], tint: SIMD3<Float>(1, 1, 0)),
        ])
        XCTAssertFalse(path.ownsGeneratedMesh, "only setGeneratedMesh claims the entity's mesh")
    }

    // MARK: Saving, reloading, removing

    func testAnEntityOfAKindSurvivesASceneRoundTripWithoutBeingCreatedAgain() throws {
        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self, entityName: "Spawn A"))
        marker.team = 2
        ScenePluginSystem.shared.remove(SpinnerComponent.self, from: marker.entity)

        let saved = serializeScene()
        resetKitTestState()
        EntityPluginRegistry.shared.register(MarkerEntity.self)
        deserializeScene(sceneData: saved)
        ScenePluginSystem.shared.bindPending()

        let restored = try XCTUnwrap(findEntity(name: "Spawn A"))
        let restoredMarker = try XCTUnwrap(EntityPluginRegistry.plugin(MarkerEntity.self, on: restored))
        XCTAssertEqual(restoredMarker.team, 2)
        XCTAssertEqual(restoredMarker.events, ["attach"], "loaded, not created: onCreate does not run again")
        XCTAssertTrue(ScenePluginSystem.shared.slots(on: restored).isEmpty, "so the spinner that was removed stays removed")
    }

    func testAKindThatIsNotLoadedKeepsItsValuesAndBindsWhenItArrives() throws {
        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self, entityName: "Spawn B"))
        marker.team = 2
        let saved = serializeScene()

        resetKitTestState()
        deserializeScene(sceneData: saved)
        ScenePluginSystem.shared.bindPending()
        let entity = try XCTUnwrap(findEntity(name: "Spawn B"))
        XCTAssertNil(ScenePluginSystem.shared.entityPlugin(on: entity))
        let slot = try XCTUnwrap(ScenePluginSystem.shared.entitySlot(on: entity))
        XCTAssertFalse(slot.isBound)
        XCTAssertEqual(slot.payload["team"], .number(2))

        EntityPluginRegistry.shared.register(MarkerEntity.self)
        ScenePluginSystem.shared.bindPending()
        XCTAssertEqual(EntityPluginRegistry.plugin(MarkerEntity.self, on: entity)?.team, 2)
    }

    func testAReloadRebindsTheEntityPluginAndItsComponents() throws {
        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self))
        let entity = marker.entity
        marker.team = 2

        ScenePluginSystem.shared.prepareForReload()
        XCTAssertFalse(marker.isAttached)
        XCTAssertEqual(marker.events.last, "detach")
        XCTAssertNil(ScenePluginSystem.shared.entityPlugin(on: entity))

        ScenePluginSystem.shared.finishReload()
        let rebound = try XCTUnwrap(EntityPluginRegistry.plugin(MarkerEntity.self, on: entity))
        XCTAssertFalse(rebound === marker)
        XCTAssertEqual(rebound.team, 2)
        XCTAssertEqual(rebound.events, ["attach"])
        XCTAssertNotNil(ComponentPluginRegistry.component(SpinnerComponent.self, on: entity))
    }

    func testDestroyingTheEntityDetachesItsPlugin() throws {
        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self))
        destroyEntity(entityId: marker.entity)
        finalizePendingDestroys()
        XCTAssertFalse(marker.isAttached)
        XCTAssertEqual(marker.events.last, "detach")
    }

    func testAnEntityIsOfOneKindAtMostAndCanLoseIt() throws {
        EntityPluginRegistry.shared.register(MarkerEntity.self)
        EntityPluginRegistry.shared.register(PathEntity.self)
        let entity = createEntity()

        let marker = try XCTUnwrap(ScenePluginSystem.shared.setEntityPlugin("MarkerEntity", on: entity) as? MarkerEntity)
        XCTAssertEqual(marker.createCount, 0, "onCreate belongs to instantiate, not to binding")
        XCTAssertTrue(ScenePluginSystem.shared.setEntityPlugin("MarkerEntity", on: entity) === marker, "same kind again changes nothing")

        XCTAssertNotNil(ScenePluginSystem.shared.setEntityPlugin("PathEntity", on: entity) as? PathEntity)
        XCTAssertFalse(marker.isAttached, "a different kind replaces the one it had")

        XCTAssertTrue(ScenePluginSystem.shared.removeEntityPlugin(from: entity))
        XCTAssertNil(ScenePluginSystem.shared.entitySlot(on: entity))
        XCTAssertFalse(hasComponent(entityId: entity, componentType: ScenePluginsComponent.self), "nothing left to store")
        XCTAssertFalse(ScenePluginSystem.shared.removeEntityPlugin(from: entity))
    }

    func testTheSceneFileKeepsTheEntityApartFromItsComponents() throws {
        let marker = try XCTUnwrap(EntityPluginRegistry.shared.instantiate(MarkerEntity.self))
        let storage = try XCTUnwrap(scene.get(component: ScenePluginsComponent.self, for: marker.entity))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(storage)) as? [String: Any])

        let entity = try XCTUnwrap(json["entity"] as? [String: Any])
        XCTAssertEqual(entity["type"] as? String, "MarkerEntity")
        XCTAssertEqual((entity["properties"] as? [String: Any])?["team"] as? Double, 1)
        let components = try XCTUnwrap(json["components"] as? [[String: Any]])
        XCTAssertEqual(components.map { $0["type"] as? String }, ["SpinnerComponent"])
    }
}
