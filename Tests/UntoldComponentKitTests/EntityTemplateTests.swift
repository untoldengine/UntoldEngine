//
//  EntityTemplateTests.swift
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
final class EntityTemplateTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    func testDefaultsComeFromTheTypeName() {
        XCTAssertEqual(MarkerEntityTemplate.typeName, "MarkerEntityTemplate")
        XCTAssertEqual(MarkerEntityTemplate.displayName, "Marker", "a trailing EntityTemplate, Template or Entity is dropped")
        XCTAssertEqual(MarkerEntityTemplate.shelf, .entities)
        XCTAssertEqual(MarkerEntityTemplate.systemImage, "flag")
        XCTAssertEqual(RulesTemplate.displayName, "Game Rules")
        XCTAssertEqual(EntityTemplate.systemImage, "cube.transparent")
        XCTAssertEqual(UntoldEntityShelf.allCases.map(\.title), ["Primitives", "Lights", "Entities"])
    }

    func testRegistryListsTemplatesByShelf() {
        XCTAssertTrue(EntityTemplateRegistry.shared.register(MarkerEntityTemplate.self, revision: 4))
        XCTAssertTrue(EntityTemplateRegistry.shared.register(RulesTemplate.self))
        XCTAssertTrue(EntityTemplateRegistry.shared.register(MarkerEntityTemplate.self), "registering the same type again is fine")

        XCTAssertEqual(EntityTemplateRegistry.shared.entries.map(\.name), ["RulesTemplate", "MarkerEntityTemplate"], "sorted by display name")
        XCTAssertEqual(EntityTemplateRegistry.shared.entries(on: .entities).map(\.name), ["MarkerEntityTemplate"])
        XCTAssertEqual(EntityTemplateRegistry.shared.entries(on: .lights).map(\.name), ["RulesTemplate"])
        XCTAssertTrue(EntityTemplateRegistry.shared.entries(on: .primitives).isEmpty)

        EntityTemplateRegistry.shared.unregister(name: "RulesTemplate")
        XCTAssertNil(EntityTemplateRegistry.shared.type(named: "RulesTemplate"))
        XCTAssertNotNil(EntityTemplateRegistry.shared.type(named: "MarkerEntityTemplate"))
    }

    func testDiscoveryFindsTemplatesAndNothingElse() throws {
        let imagePath = try XCTUnwrap(ImageDiscovery.imagePath(containing: MarkerEntityTemplate.self))
        let names = EntityTemplateRegistry.shared.discover(imagePath: imagePath, revision: 2)

        XCTAssertEqual(names, ["MarkerEntityTemplate", "RulesTemplate"])
        XCTAssertEqual(EntityTemplateRegistry.shared.entries.first { $0.name == "RulesTemplate" }?.revision, 2)
        XCTAssertTrue(EntityTemplateRegistry.shared.discover(imagePath: "/nonexistent/image.dylib").isEmpty)
    }

    func testInstantiateBuildsNamesAndPlacesTheEntity() throws {
        EntityTemplateRegistry.shared.register(MarkerEntityTemplate.self)

        let entity = try XCTUnwrap(EntityTemplateRegistry.shared.instantiate("MarkerEntityTemplate", at: SIMD3<Float>(1, 2, 3)))
        XCTAssertEqual(getEntityName(entityId: entity), "Marker")
        XCTAssertEqual(getLocalPosition(entityId: entity), SIMD3<Float>(1, 2, 3))

        let marker = try XCTUnwrap(CodeComponentSystem.shared.component(named: "MarkerComponent", on: entity) as? MarkerComponent)
        XCTAssertEqual(marker.team, 7, "values set in build are the entity's starting values")
        XCTAssertTrue(marker.isAttached)

        let named = try XCTUnwrap(EntityTemplateRegistry.shared.instantiate("MarkerEntityTemplate", entityName: "Spawn A"))
        XCTAssertEqual(getEntityName(entityId: named), "Spawn A")
        XCTAssertNil(EntityTemplateRegistry.shared.instantiate("Missing"))
    }

    func testTheEditorRepresentationBelongsToTheComponent() {
        XCTAssertEqual(SpinnerComponent.editorRepresentation, .none)
        XCTAssertEqual(MarkerComponent.editorRepresentation, .icon(systemImage: "flag.fill", tint: SIMD3<Float>(0.2, 0.8, 0.4)))
        XCTAssertEqual(EditorRepresentation.icon(systemImage: "flag"), .icon(systemImage: "flag", tint: SIMD3<Float>(1, 1, 1)))
    }

    func testAnEntityMadeFromATemplateSurvivesASceneRoundTrip() throws {
        EntityTemplateRegistry.shared.register(MarkerEntityTemplate.self)
        let entity = try XCTUnwrap(EntityTemplateRegistry.shared.instantiate("MarkerEntityTemplate", entityName: "Spawn A"))
        let marker = try XCTUnwrap(CodeComponentSystem.shared.component(named: "MarkerComponent", on: entity) as? MarkerComponent)
        marker.team = 3

        let saved = serializeScene()
        resetKitTestState()
        CodeComponentRegistry.shared.register(MarkerComponent.self)
        deserializeScene(sceneData: saved)
        CodeComponentSystem.shared.bindPending()

        let restored = try XCTUnwrap(findEntity(name: "Spawn A"))
        let restoredMarker = try XCTUnwrap(CodeComponentSystem.shared.component(named: "MarkerComponent", on: restored) as? MarkerComponent)
        XCTAssertEqual(restoredMarker.team, 3, "the template is gone after creation; the component carries the entity")
        XCTAssertEqual(type(of: restoredMarker).editorRepresentation, MarkerComponent.editorRepresentation)
    }
}
