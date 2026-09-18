//
//  ScenePluginSystemTests.swift
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
final class ScenePluginSystemTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    override func tearDown() async throws {
        ScenePluginSystem.shared.stopPlayMode()
        gameMode = false
    }

    func testInstallRegistersTheExtensionOnce() {
        ScenePluginSystem.install()
        ScenePluginSystem.install()
        let ids = EngineExtensionRegistry.shared.registeredIDs().filter { $0 == ScenePluginSystem.extensionID }
        XCTAssertEqual(ids.count, 1)
    }

    func testAddBindsAttachesAndIsIdempotentPerType() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertEqual(spinner.entity, entity)
        XCTAssertTrue(spinner.isAttached)
        XCTAssertEqual(spinner.events, ["attach"])
        XCTAssertTrue(hasComponent(entityId: entity, componentType: ScenePluginsComponent.self))

        let again = ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity)
        XCTAssertTrue(again === spinner)
        XCTAssertEqual(ScenePluginSystem.shared.components(on: entity).count, 1)
    }

    func testAddToAMissingEntityDoesNothing() {
        XCTAssertNil(ScenePluginSystem.shared.add(SpinnerComponent.self, to: .invalid))
    }

    func testASlotForAnUnknownTypeBindsWhenTheTypeArrives() throws {
        let entity = createEntity()
        XCTAssertNil(ScenePluginSystem.shared.add("SpinnerComponent", to: entity))
        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.isBound), [false])

        ComponentPluginRegistry.shared.register(SpinnerComponent.self)
        ScenePluginSystem.shared.update(deltaTime: 0.016, context: makeKitTestContext())

        let spinner = try XCTUnwrap(ComponentPluginRegistry.component(SpinnerComponent.self, on: entity))
        XCTAssertEqual(spinner.events, ["attach"])
        XCTAssertEqual(ComponentPluginRegistry.entities(with: SpinnerComponent.self), [entity])
    }

    // MARK: Components that change the entity while a bind pass is running

    /// Slots for types that are not registered yet, so one bind pass later binds them all.
    private func entityWithPendingSlots(_ typeNames: [String]) -> EntityID {
        let entity = createEntity()
        for typeName in typeNames {
            ScenePluginSystem.shared.add(typeName, to: entity)
        }
        return entity
    }

    func testRemovingAnEarlierSiblingDuringAttachDoesNotSkipTheNextOne() throws {
        ComponentPluginRegistry.shared.register(SpinnerComponent.self)
        let entity = entityWithPendingSlots(["SpinnerComponent", "RemovesEarlierSibling", "Bystander"])
        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.isBound), [true, false, false])

        ComponentPluginRegistry.shared.register(RemovesEarlierSibling.self)
        ComponentPluginRegistry.shared.register(Bystander.self)
        ScenePluginSystem.shared.bindPending()

        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.typeName), ["RemovesEarlierSibling", "Bystander"])
        let bystander = try XCTUnwrap(ComponentPluginRegistry.component(Bystander.self, on: entity))
        XCTAssertEqual(bystander.attachCount, 1, "the slot that shifted into the removed one's place is still bound, once")
    }

    func testRemovingALaterSiblingDuringAttachLeavesTheRestBoundOnce() {
        let entity = entityWithPendingSlots(["RemovesLaterSibling", "Bystander", "SpinnerComponent"])

        ComponentPluginRegistry.shared.register(RemovesLaterSibling.self)
        ComponentPluginRegistry.shared.register(Bystander.self)
        ComponentPluginRegistry.shared.register(SpinnerComponent.self)
        ScenePluginSystem.shared.bindPending()

        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.typeName), ["RemovesLaterSibling", "SpinnerComponent"])
        XCTAssertNil(ComponentPluginRegistry.component(Bystander.self, on: entity), "removed before it was bound, so it never was")
        XCTAssertEqual(ComponentPluginRegistry.component(SpinnerComponent.self, on: entity)?.events, ["attach"])
    }

    func testAddingASiblingDuringAttachBindsItOnce() {
        let entity = entityWithPendingSlots(["AddsASibling"])
        ComponentPluginRegistry.shared.register(Bystander.self)
        ComponentPluginRegistry.shared.register(AddsASibling.self)
        ScenePluginSystem.shared.bindPending()

        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.typeName), ["AddsASibling", "Bystander"])
        XCTAssertEqual(ComponentPluginRegistry.component(Bystander.self, on: entity)?.attachCount, 1, "bound by the add itself, not again by the pass")
    }

    func testAComponentThatRemovesItselfDuringAttachDoesNotSkipTheNextOne() {
        let entity = entityWithPendingSlots(["RemovesItself", "Bystander"])
        ComponentPluginRegistry.shared.register(RemovesItself.self)
        ComponentPluginRegistry.shared.register(Bystander.self)
        ScenePluginSystem.shared.bindPending()

        XCTAssertEqual(ScenePluginSystem.shared.slots(on: entity).map(\.typeName), ["Bystander"])
        XCTAssertEqual(ComponentPluginRegistry.component(Bystander.self, on: entity)?.attachCount, 1)
    }

    func testUpdateRunsOnlyWhilePlayingInGameMode() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))
        let context = makeKitTestContext()

        ScenePluginSystem.shared.update(deltaTime: 0.5, context: context)
        XCTAssertEqual(spinner.events, ["attach"], "edit mode must not tick components")

        gameMode = true
        ScenePluginSystem.shared.startPlayMode()
        ScenePluginSystem.shared.update(deltaTime: 0.5, context: context)
        ScenePluginSystem.shared.fixedUpdate(deltaTime: 0.25, context: context)
        XCTAssertEqual(spinner.events, ["attach", "start", "update:0.5", "fixed:0.25"])

        gameMode = false
        ScenePluginSystem.shared.update(deltaTime: 0.5, context: context)
        XCTAssertEqual(spinner.events.count, 4, "leaving game mode pauses updates")

        ScenePluginSystem.shared.stopPlayMode()
        XCTAssertEqual(spinner.events.last, "stop")
        XCTAssertFalse(ScenePluginSystem.shared.isPlaying)
    }

    func testAComponentAddedDuringPlayStartsImmediately() throws {
        gameMode = true
        ScenePluginSystem.shared.startPlayMode()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: createEntity()))
        XCTAssertEqual(spinner.events, ["attach", "start"])
    }

    func testRemoveStopsDetachesAndDropsTheStorageWhenEmpty() throws {
        gameMode = true
        ScenePluginSystem.shared.startPlayMode()
        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertTrue(ScenePluginSystem.shared.remove(SpinnerComponent.self, from: entity))
        XCTAssertEqual(spinner.events, ["attach", "start", "stop", "detach"])
        XCTAssertFalse(spinner.isAttached)
        XCTAssertFalse(hasComponent(entityId: entity, componentType: ScenePluginsComponent.self))
        XCTAssertFalse(ScenePluginSystem.shared.remove(SpinnerComponent.self, from: entity))
    }

    func testDestroyingTheEntityDetachesItsComponents() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))

        destroyEntity(entityId: entity)
        finalizePendingDestroys()

        XCTAssertEqual(spinner.events, ["attach", "detach"])
        XCTAssertFalse(spinner.isAttached)
    }

    func testEditorWritesNotifyTheComponentOutsidePlayOnly() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))
        let system = ScenePluginSystem.shared

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
        let spinner = try XCTUnwrap(ScenePluginSystem.shared.add(SpinnerComponent.self, to: entity))

        XCTAssertTrue(ScenePluginSystem.shared.performAction("Jump", of: "SpinnerComponent", on: entity))
        XCTAssertFalse(ScenePluginSystem.shared.performAction("Fly", of: "SpinnerComponent", on: entity))

        let uscAction = try XCTUnwrap(USCActionRegistry.shared.resolve(name: "SpinnerComponent.Jump"))
        _ = uscAction(USCContext(entityId: entity, script: nil), [:])
        XCTAssertEqual(spinner.events.filter { $0 == "jump" }.count, 2)

        _ = uscAction(USCContext(entityId: createEntity(), script: nil), [:])
        XCTAssertEqual(spinner.events.filter { $0 == "jump" }.count, 2, "an entity without the component is a no-op")

        ComponentPluginRegistry.shared.unregister(name: "SpinnerComponent")
        XCTAssertNil(USCActionRegistry.shared.resolve(name: "SpinnerComponent.Jump"))
    }

    func testReloadCarriesValuesAcrossToTheNewTypeByPropertyName() throws {
        let registry = ComponentPluginRegistry.shared
        let system = ScenePluginSystem.shared
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
        let system = ScenePluginSystem.shared
        ComponentPluginRegistry.shared.register(RevisionA.Reloadable.self, policy: .replace)
        let entity = createEntity()
        let old = try XCTUnwrap(system.add("Reloadable", to: entity) as? RevisionA.Reloadable)
        old.speed = 9

        system.prepareForReload()
        ComponentPluginRegistry.shared.unregister(name: "Reloadable")
        system.finishReload()

        let slot = try XCTUnwrap(system.slots(on: entity).first)
        XCTAssertFalse(slot.isBound)
        XCTAssertEqual(slot.payload["speed"], .number(9))
        XCTAssertNil(system.component(named: "Reloadable", on: entity))
    }

    func testADifferentTypeUnderAnExistingNameIsRefusedUnlessReplacing() {
        let registry = ComponentPluginRegistry.shared
        XCTAssertEqual(registry.register(RevisionA.Reloadable.self), .registered)
        XCTAssertEqual(registry.register(RevisionA.Reloadable.self), .unchanged)
        XCTAssertEqual(registry.register(RevisionB.Reloadable.self), .rejectedDuplicate)
        XCTAssertTrue(registry.type(named: "Reloadable") == RevisionA.Reloadable.self)
        XCTAssertEqual(registry.register(RevisionB.Reloadable.self, policy: .replace), .replaced)
    }
}
