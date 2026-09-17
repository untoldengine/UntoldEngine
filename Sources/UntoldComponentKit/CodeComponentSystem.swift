//
//  CodeComponentSystem.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// What the editor needs to list an entity's code components, including ones whose type is
/// not loaded.
public struct CodeComponentSlotInfo: Equatable, Sendable {
    public let typeName: String
    /// `false` when the type is not registered; the payload is still kept and saved.
    public let isBound: Bool
    public let payload: [String: UntoldAttributeValue]
}

/// Owns the life of every code component: binding saved slots to registered types, play mode,
/// per-frame dispatch, removal, and the detach/re-attach cycle a library reload needs.
///
/// It is an `EngineExtension`, so the engine ticks it after input and scene-graph traversal.
/// Callbacks run on the engine's simulation thread: main on macOS and iOS, the compositor
/// render thread on visionOS.
public final class CodeComponentSystem: EngineExtension, @unchecked Sendable {
    public static let shared = CodeComponentSystem()
    public static let extensionID = "com.untoldengine.componentkit"

    public let id = CodeComponentSystem.extensionID

    private let lock = NSRecursiveLock()
    private var installed = false
    private var playing = false
    private var bindRequested = false

    private init() {}

    // MARK: Installation

    /// Registers the system with the engine, the storage component with the scene serializer,
    /// and the cleanup that detaches components when an entity is destroyed. Idempotent.
    public static func install() {
        shared.installIfNeeded()
    }

    public static func uninstall() {
        EngineExtensionRegistry.shared.unregister(id: extensionID)
    }

    private func installIfNeeded() {
        lock.lock()
        let alreadyInstalled = installed
        installed = true
        lock.unlock()
        guard alreadyInstalled == false else { return }

        // `merge` is required: the serializer decodes into a temporary and the pooled instance
        // only changes through it.
        encodeCustomComponent(type: CodeComponentsComponent.self) { existing, decoded in
            existing.slots = decoded.slots
            CodeComponentSystem.shared.setNeedsBind()
        }
        ComponentRegistry.register(
            componentType: CodeComponentsComponent.self,
            handlerId: Self.extensionID
        ) { entityId in
            CodeComponentSystem.shared.detachAll(from: entityId, keepPayloads: false)
            scene.remove(component: CodeComponentsComponent.self, from: entityId)
        }
        EngineExtensionRegistry.shared.register(self)
        setNeedsBind()
    }

    public func willUnregister() {
        if isPlaying {
            stopPlayMode()
        }
        lock.lock()
        installed = false
        lock.unlock()
    }

    // MARK: Play mode

    public var isPlaying: Bool {
        lock.lock()
        defer { lock.unlock() }
        return playing
    }

    /// Binds anything pending, then starts every component. Mirrors `USCSystem.startPlayMode()`.
    public func startPlayMode() {
        bindPending()
        lock.lock()
        playing = true
        lock.unlock()
        for instance in liveInstances() where instance.isAttached && instance.hasStarted == false {
            instance.hasStarted = true
            instance.onStart()
        }
    }

    public func stopPlayMode() {
        for instance in liveInstances() where instance.hasStarted {
            instance.hasStarted = false
            instance.onStop()
        }
        lock.lock()
        playing = false
        lock.unlock()
    }

    // MARK: EngineExtension

    public func update(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        bindPendingIfRequested()
        guard isPlaying, gameMode else { return }
        for instance in liveInstances() where instance.isAttached && instance.hasStarted {
            instance.onUpdate(deltaTime: deltaTime)
        }
    }

    public func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        guard isPlaying else { return }
        for instance in liveInstances() where instance.isAttached && instance.hasStarted {
            instance.onFixedUpdate(deltaTime: deltaTime)
        }
    }

    // MARK: Binding

    /// Asks for a bind pass on the next tick. Called when a scene finishes decoding and when
    /// types are registered, so slots saved for a type that arrives later still come alive.
    public func setNeedsBind() {
        lock.lock()
        bindRequested = true
        lock.unlock()
    }

    private func bindPendingIfRequested() {
        lock.lock()
        let requested = bindRequested
        lock.unlock()
        if requested {
            bindPending()
        }
    }

    /// Creates an instance for every slot whose type is registered and that has none yet.
    public func bindPending() {
        lock.lock()
        bindRequested = false
        lock.unlock()
        for entityId in storageEntities() {
            bind(entityId: entityId)
        }
    }

    private func bind(entityId: EntityID) {
        guard let storage = storage(for: entityId) else { return }
        var index = 0
        // Index-based on purpose: onAttach/onStart may add or remove components on this entity.
        while index < storage.slots.count {
            defer { index += 1 }
            guard storage.slots[index].instance == nil,
                  let type = CodeComponentRegistry.shared.type(named: storage.slots[index].typeName)
            else { continue }

            let typeName = storage.slots[index].typeName
            let instance = type.init()
            instance.entity = entityId
            let report = instance.applyAttributePayload(storage.slots[index].payload)
            if report.dropped.isEmpty == false {
                Logger.logWarning(
                    message: "[ComponentKit] \(typeName): saved values with no matching property were dropped: \(report.dropped.joined(separator: ", "))",
                    category: LogCategory.ecs.rawValue
                )
            }
            if report.rejected.isEmpty == false {
                Logger.logWarning(
                    message: "[ComponentKit] \(typeName): saved values of the wrong type were ignored, defaults kept: \(report.rejected.joined(separator: ", "))",
                    category: LogCategory.ecs.rawValue
                )
            }

            storage.slots[index].instance = instance
            instance.isAttached = true
            instance.onAttach()
            if isPlaying, instance.isAttached {
                instance.hasStarted = true
                instance.onStart()
            }
        }
    }

    // MARK: Adding and removing

    /// Adds a component by type name. Returns the live instance, or `nil` when the type is not
    /// registered, in which case the slot is still created and binds when the type arrives.
    /// An entity carries at most one component of a given type; adding again returns it.
    @discardableResult
    public func add(_ typeName: String, to entityId: EntityID) -> CodeComponent? {
        Self.install()
        guard scene.mask(for: entityId) != nil else { return nil }
        if storage(for: entityId) == nil {
            registerComponent(entityId: entityId, componentType: CodeComponentsComponent.self)
        }
        guard let storage = storage(for: entityId) else { return nil }
        if storage.slots.contains(where: { $0.typeName == typeName }) == false {
            storage.slots.append(CodeComponentsComponent.Slot(typeName: typeName))
        }
        bind(entityId: entityId)
        return storage.slots.first(where: { $0.typeName == typeName })?.instance
    }

    /// Adds a component by type, registering the type if needed.
    @discardableResult
    public func add<T: CodeComponent>(_ type: T.Type, to entityId: EntityID) -> T? {
        guard CodeComponentRegistry.shared.register(type) != .rejectedDuplicate else { return nil }
        return add(T.typeName, to: entityId) as? T
    }

    /// Removes a component and its saved values. Returns `false` when the entity had none.
    @discardableResult
    public func remove(_ typeName: String, from entityId: EntityID) -> Bool {
        guard let storage = storage(for: entityId),
              let index = storage.slots.firstIndex(where: { $0.typeName == typeName })
        else { return false }

        if let instance = storage.slots[index].instance {
            detach(instance)
        }
        storage.slots.removeAll { $0.typeName == typeName }
        if storage.slots.isEmpty {
            scene.remove(component: CodeComponentsComponent.self, from: entityId)
        }
        return true
    }

    @discardableResult
    public func remove<T: CodeComponent>(_: T.Type, from entityId: EntityID) -> Bool {
        remove(T.typeName, from: entityId)
    }

    // MARK: Queries

    /// Live components on `entityId`, in slot order.
    public func components(on entityId: EntityID) -> [CodeComponent] {
        storage(for: entityId)?.slots.compactMap(\.instance) ?? []
    }

    public func component(named typeName: String, on entityId: EntityID) -> CodeComponent? {
        storage(for: entityId)?.slots.first(where: { $0.typeName == typeName })?.instance
    }

    /// Every slot on `entityId`, bound or not, with the values an inspector should show.
    public func slots(on entityId: EntityID) -> [CodeComponentSlotInfo] {
        guard let storage = storage(for: entityId) else { return [] }
        return storage.slots.map { slot in
            CodeComponentSlotInfo(
                typeName: slot.typeName,
                isBound: slot.instance != nil,
                payload: slot.instance?.attributePayload() ?? slot.payload
            )
        }
    }

    public func entities(withComponentNamed typeName: String) -> [EntityID] {
        storageEntities().filter { component(named: typeName, on: $0) != nil }
    }

    // MARK: Editor support

    /// Writes one attribute from the editor and, outside play, tells the component about it.
    @discardableResult
    public func setAttribute(
        _ property: String,
        of typeName: String,
        on entityId: EntityID,
        to value: UntoldAttributeValue
    ) -> Bool {
        guard let instance = component(named: typeName, on: entityId),
              let entry = instance.untoldAttributes().first(where: { $0.name == property }),
              entry.attribute.setAttributeValue(value)
        else { return false }
        if isPlaying == false {
            instance.onEditorChanged(property: property)
        }
        return true
    }

    /// Runs one of the component's exposed actions, as an editor button does.
    @discardableResult
    public func performAction(_ actionName: String, of typeName: String, on entityId: EntityID) -> Bool {
        guard let instance = component(named: typeName, on: entityId),
              let action = type(of: instance).actions.first(where: { $0.name == actionName })
        else { return false }
        action.perform(on: instance)
        return true
    }

    // MARK: Reload support

    /// First half of a library reload: every live instance (or only those of `typeNames`) is
    /// snapshotted into its slot and detached. Register the new types, then call
    /// `finishReload()`.
    public func prepareForReload(typeNames: Set<String>? = nil) {
        for entityId in storageEntities() {
            detachAll(from: entityId, keepPayloads: true, only: typeNames)
        }
    }

    /// Second half of a reload: slots bind to whatever types are registered now. A type that
    /// no longer exists leaves its slot unbound with its values intact.
    public func finishReload() {
        bindPending()
    }

    // MARK: Internals

    func detachAll(from entityId: EntityID, keepPayloads: Bool, only typeNames: Set<String>? = nil) {
        guard let storage = storage(for: entityId) else { return }
        for index in storage.slots.indices {
            guard let instance = storage.slots[index].instance else { continue }
            if let typeNames, typeNames.contains(storage.slots[index].typeName) == false {
                continue
            }
            if keepPayloads {
                storage.slots[index].payload = instance.attributePayload()
            }
            detach(instance)
            storage.slots[index].instance = nil
        }
    }

    private func detach(_ instance: CodeComponent) {
        if instance.hasStarted {
            instance.hasStarted = false
            instance.onStop()
        }
        if instance.isAttached {
            instance.isAttached = false
            instance.onDetach()
        }
    }

    /// Deliberately not `scene.mask(for:)`: that hides entities pending destruction, and the
    /// cleanup handler runs exactly then and still has to reach the instances to detach them.
    private func storage(for entityId: EntityID) -> CodeComponentsComponent? {
        guard hasComponent(entityId: entityId, componentType: CodeComponentsComponent.self) else { return nil }
        return scene.get(component: CodeComponentsComponent.self, for: entityId)
    }

    /// Sorted so dispatch order is stable from frame to frame.
    private func storageEntities() -> [EntityID] {
        queryEntities(with: [CodeComponentsComponent.self]).sorted()
    }

    private func liveInstances() -> [CodeComponent] {
        storageEntities().flatMap { components(on: $0) }
    }
}
