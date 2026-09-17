//
//  CodeComponentSystemTests.swift
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
final class CodeComponentSystemTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    override func tearDown() async throws {
        CodeComponentSystem.shared.stopPlayMode()
        gameMode = false
    }

    func testInstallRegistersTheExtensionOnce() {
        CodeComponentSystem.install()
        CodeComponentSystem.install()
        let ids = EngineExtensionRegistry.shared.registeredIDs().filter { $0 == CodeComponentSystem.extensionID }
        XCTAssertEqual(ids.count, 1)
    }

    func testAddBindsAttachesAndIsIdempotentPerType() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertEqual(spinner.entity, entity)
        XCTAssertTrue(spinner.isAttached)
        XCTAssertEqual(spinner.events, ["attach"])
        XCTAssertTrue(hasComponent(entityId: entity, componentType: CodeComponentsComponent.self))

        let again = CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity)
        XCTAssertTrue(again === spinner)
        XCTAssertEqual(CodeComponentSystem.shared.components(on: entity).count, 1)
    }

    func testAddToAMissingEntityDoesNothing() {
        XCTAssertNil(CodeComponentSystem.shared.add(SpinnerComponent.self, to: .invalid))
    }

    func testASlotForAnUnknownTypeBindsWhenTheTypeArrives() throws {
        let entity = createEntity()
        XCTAssertNil(CodeComponentSystem.shared.add("SpinnerComponent", to: entity))
        XCTAssertEqual(CodeComponentSystem.shared.slots(on: entity).map(\.isBound), [false])

        CodeComponentRegistry.shared.register(SpinnerComponent.self)
        CodeComponentSystem.shared.update(deltaTime: 0.016, context: makeKitTestContext())

        let spinner = try XCTUnwrap(CodeComponentRegistry.component(SpinnerComponent.self, on: entity))
        XCTAssertEqual(spinner.events, ["attach"])
        XCTAssertEqual(CodeComponentRegistry.entities(with: SpinnerComponent.self), [entity])
    }

    func testUpdateRunsOnlyWhilePlayingInGameMode() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))
        let context = makeKitTestContext()

        CodeComponentSystem.shared.update(deltaTime: 0.5, context: context)
        XCTAssertEqual(spinner.events, ["attach"], "edit mode must not tick components")

        gameMode = true
        CodeComponentSystem.shared.startPlayMode()
        CodeComponentSystem.shared.update(deltaTime: 0.5, context: context)
        CodeComponentSystem.shared.fixedUpdate(deltaTime: 0.25, context: context)
        XCTAssertEqual(spinner.events, ["attach", "start", "update:0.5", "fixed:0.25"])

        gameMode = false
        CodeComponentSystem.shared.update(deltaTime: 0.5, context: context)
        XCTAssertEqual(spinner.events.count, 4, "leaving game mode pauses updates")

        CodeComponentSystem.shared.stopPlayMode()
        XCTAssertEqual(spinner.events.last, "stop")
        XCTAssertFalse(CodeComponentSystem.shared.isPlaying)
    }

    func testAComponentAddedDuringPlayStartsImmediately() throws {
        gameMode = true
        CodeComponentSystem.shared.startPlayMode()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: createEntity()))
        XCTAssertEqual(spinner.events, ["attach", "start"])
    }

    func testRemoveStopsDetachesAndDropsTheStorageWhenEmpty() throws {
        gameMode = true
        CodeComponentSystem.shared.startPlayMode()
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertTrue(CodeComponentSystem.shared.remove(SpinnerComponent.self, from: entity))
        XCTAssertEqual(spinner.events, ["attach", "start", "stop", "detach"])
        XCTAssertFalse(spinner.isAttached)
        XCTAssertFalse(hasComponent(entityId: entity, componentType: CodeComponentsComponent.self))
        XCTAssertFalse(CodeComponentSystem.shared.remove(SpinnerComponent.self, from: entity))
    }

    func testDestroyingTheEntityDetachesItsComponents() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))

        destroyEntity(entityId: entity)
        finalizePendingDestroys()

        XCTAssertEqual(spinner.events, ["attach", "detach"])
        XCTAssertFalse(spinner.isAttached)
    }

    func testEditorWritesNotifyTheComponentOutsidePlayOnly() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))
        let system = CodeComponentSystem.shared

        XCTAssertTrue(system.setAttribute("speed", of: "SpinnerComponent", on: entity, to: .number(7)))
        XCTAssertEqual(spinner.speed, 7)
        XCTAssertEqual(spinner.events.last, "edited:speed")

        XCTAssertFalse(system.setAttribute("speed", of: "SpinnerComponent", on: entity, to: .bool(true)))
        XCTAssertFalse(system.setAttribute("nope", of: "SpinnerComponent", on: entity, to: .number(1)))

        gameMode = true
        system.startPlayMode()
        XCTAssertTrue(system.setAttribute("speed", of: "SpinnerComponent", on: entity, to: .number(8)))
        XCTAssertEqual(spinner.events.last, "start", "no edit callback while playing")
    }

    func testActionsRunFromTheEditorAndFromUSC() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertTrue(CodeComponentSystem.shared.performAction("Jump", of: "SpinnerComponent", on: entity))
        XCTAssertFalse(CodeComponentSystem.shared.performAction("Fly", of: "SpinnerComponent", on: entity))

        let uscAction = try XCTUnwrap(USCActionRegistry.shared.resolve(name: "SpinnerComponent.Jump"))
        _ = uscAction(USCContext(entityId: entity, script: nil), [:])
        XCTAssertEqual(spinner.events.filter { $0 == "jump" }.count, 2)

        _ = uscAction(USCContext(entityId: createEntity(), script: nil), [:])
        XCTAssertEqual(spinner.events.filter { $0 == "jump" }.count, 2, "an entity without the component is a no-op")

        CodeComponentRegistry.shared.unregister(name: "SpinnerComponent")
        XCTAssertNil(USCActionRegistry.shared.resolve(name: "SpinnerComponent.Jump"))
    }

    func testReloadCarriesValuesAcrossToTheNewTypeByPropertyName() throws {
        let registry = CodeComponentRegistry.shared
        let system = CodeComponentSystem.shared
        XCTAssertEqual(registry.register(RevisionA.Reloadable.self, revision: 1, policy: .replace), .registered)

        let entity = createEntity()
        let old = try XCTUnwrap(system.add("Reloadable", to: entity) as? RevisionA.Reloadable)
        old.speed = 9
        old.legacy = 8

        system.prepareForReload()
        XCTAssertTrue(old.detached)
        XCTAssertEqual(system.slots(on: entity).map(\.isBound), [false])

        XCTAssertEqual(registry.register(RevisionB.Reloadable.self, revision: 2, policy: .replace), .replaced)
        system.finishReload()

        let fresh = try XCTUnwrap(system.component(named: "Reloadable", on: entity) as? RevisionB.Reloadable)
        XCTAssertEqual(fresh.speed, 9, "a property both revisions declare keeps its value")
        XCTAssertTrue(fresh.fresh, "a property only the new revision declares takes its default")
        XCTAssertEqual(fresh.entity, entity)
        XCTAssertEqual(registry.entries.first { $0.name == "Reloadable" }?.revision, 2)
    }

    func testATypeThatDisappearsKeepsItsValuesUnbound() throws {
        let system = CodeComponentSystem.shared
        CodeComponentRegistry.shared.register(RevisionA.Reloadable.self, policy: .replace)
        let entity = createEntity()
        let old = try XCTUnwrap(system.add("Reloadable", to: entity) as? RevisionA.Reloadable)
        old.speed = 9

        system.prepareForReload()
        CodeComponentRegistry.shared.unregister(name: "Reloadable")
        system.finishReload()

        let slot = try XCTUnwrap(system.slots(on: entity).first)
        XCTAssertFalse(slot.isBound)
        XCTAssertEqual(slot.payload["speed"], .number(9))
        XCTAssertNil(system.component(named: "Reloadable", on: entity))
    }

    func testADifferentTypeUnderAnExistingNameIsRefusedUnlessReplacing() {
        let registry = CodeComponentRegistry.shared
        XCTAssertEqual(registry.register(RevisionA.Reloadable.self), .registered)
        XCTAssertEqual(registry.register(RevisionA.Reloadable.self), .unchanged)
        XCTAssertEqual(registry.register(RevisionB.Reloadable.self), .rejectedDuplicate)
        XCTAssertTrue(registry.type(named: "Reloadable") == RevisionA.Reloadable.self)
        XCTAssertEqual(registry.register(RevisionB.Reloadable.self, policy: .replace), .replaced)
    }
}
