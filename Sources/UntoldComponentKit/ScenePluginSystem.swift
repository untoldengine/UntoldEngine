//
//  ScenePluginSystem.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// What the editor needs to show one plugin of an entity, its entity plugin or a component,
/// including one whose type is not loaded.
public struct ScenePluginSlotInfo: Equatable, Sendable {
    public let typeName: String
    /// `false` when the type is not registered; the payload is still kept and saved.
    public let isBound: Bool
    public let payload: [String: UntoldAttributeValue]
}

/// Owns the life of every plugin bound to an entity, entity plugins and component plugins
/// alike: binding saved slots to registered types, play mode, per-frame dispatch, removal, and
/// the detach/re-attach cycle a library reload needs. On each entity its own plugin goes
/// first, then its components in the order they were added.
///
/// It is an `EngineExtension`, so the engine ticks it after input and scene-graph traversal.
/// Callbacks run on the engine's simulation thread: main on macOS and iOS, the compositor
/// render thread on visionOS.
public final class ScenePluginSystem: EngineExtension, @unchecked Sendable {
    public static let shared = ScenePluginSystem()
    public static let extensionID = "com.untoldengine.componentkit"

    public let id = ScenePluginSystem.extensionID

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
        encodeCustomComponent(type: ScenePluginsComponent.self) { existing, decoded in
            existing.entitySlot = decoded.entitySlot
            existing.slots = decoded.slots
            ScenePluginSystem.shared.setNeedsBind()
        }
        ComponentRegistry.register(
            componentType: ScenePluginsComponent.self,
            handlerId: Self.extensionID
        ) { entityId in
            ScenePluginSystem.shared.detachAll(from: entityId, keepPayloads: false)
            scene.remove(component: ScenePluginsComponent.self, from: entityId)
        }
        EngineExtensionRegistry.shared.register(self)
        setNeedsBind()
    }

    /// Registers the plugins that are part of the app, component plugins and entity plugins:
    /// those in its main executable, in the debug dylib Xcode splits an app's code into, and
    /// in frameworks embedded in its bundle. Call once at startup, before loading scenes.
    public static func discoverInApp() {
        var components: [String] = []
        var entities: [String] = []
        for path in ImageDiscovery.appImagePaths() {
            let report = ComponentPluginRegistry.shared.discover(imagePath: path)
            components += report.registered + report.replaced
            entities += EntityPluginRegistry.shared.discover(imagePath: path)
        }
        Logger.log(
            message: components.isEmpty
                ? "[ComponentKit] No component plugins found in the app."
                : "[ComponentKit] Component plugins in the app: \(components.sorted().joined(separator: ", "))",
            category: LogCategory.ecs.rawValue
        )
        if entities.isEmpty == false {
            Logger.log(
                message: "[ComponentKit] Entity plugins in the app: \(entities.sorted().joined(separator: ", "))",
                category: LogCategory.ecs.rawValue
            )
        }
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

        // The entity's own plugin first: its components may count on what it sets up.
        if let slot = storage.entitySlot, slot.instance == nil,
           let type = EntityPluginRegistry.shared.type(named: slot.typeName)
        {
            let instance = makeInstance(of: type, typeName: slot.typeName, payload: slot.payload, entityId: entityId)
            storage.entitySlot?.instance = instance
            start(instance)
        }

        // Then its components, by name. `onAttach` and `onStart` may add or remove components
        // on this entity, so the slot array can change under the pass; a name is therefore
        // looked up again just before it is bound. A slot removed meanwhile is skipped, one a
        // nested pass already bound (`add` during `onAttach` binds at once) is skipped, and one
        // added meanwhile was bound by that nested pass. Names are unique per entity, so nothing
        // is bound twice, and removing a sibling never shifts the pass past another one.
        let pending = storage.slots.compactMap { $0.instance == nil ? $0.typeName : nil }
        for typeName in pending {
            guard let index = storage.slots.firstIndex(where: { $0.typeName == typeName }),
                  storage.slots[index].instance == nil,
                  let type = ComponentPluginRegistry.shared.type(named: typeName)
            else { continue }

            let slot = storage.slots[index]
            let instance = makeInstance(of: type, typeName: slot.typeName, payload: slot.payload, entityId: entityId)
            storage.slots[index].instance = instance
            start(instance)
        }
    }

    private func makeInstance(
        of type: ScenePlugin.Type,
        typeName: String,
        payload: [String: UntoldAttributeValue],
        entityId: EntityID
    ) -> ScenePlugin {
        let instance = type.init()
        instance.entity = entityId
        let report = instance.applyAttributePayload(payload)
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
        return instance
    }

    /// The slot already holds `instance`, so what `onAttach` does to the entity finds it there.
    private func start(_ instance: ScenePlugin) {
        instance.isAttached = true
        instance.onAttach()
        if isPlaying, instance.isAttached {
            instance.hasStarted = true
            instance.onStart()
        }
    }

    // MARK: Adding and removing

    /// Adds a component by type name. Returns the live instance, or `nil` when the type is not
    /// registered, in which case the slot is still created and binds when the type arrives.
    /// An entity carries at most one component of a given type; adding again returns it.
    @discardableResult
    public func add(_ typeName: String, to entityId: EntityID) -> ComponentPlugin? {
        Self.install()
        guard scene.mask(for: entityId) != nil else { return nil }
        if storage(for: entityId) == nil {
            registerComponent(entityId: entityId, componentType: ScenePluginsComponent.self)
        }
        guard let storage = storage(for: entityId) else { return nil }
        if storage.slots.contains(where: { $0.typeName == typeName }) == false {
            storage.slots.append(ScenePluginsComponent.Slot(typeName: typeName))
        }
        bind(entityId: entityId)
        return storage.slots.first(where: { $0.typeName == typeName })?.instance as? ComponentPlugin
    }

    /// Adds a component by type, registering the type if needed.
    @discardableResult
    public func add<T: ComponentPlugin>(_ type: T.Type, to entityId: EntityID) -> T? {
        guard ComponentPluginRegistry.shared.register(type) != .rejectedDuplicate else { return nil }
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
        if storage.isEmpty {
            scene.remove(component: ScenePluginsComponent.self, from: entityId)
        }
        return true
    }

    @discardableResult
    public func remove<T: ComponentPlugin>(_: T.Type, from entityId: EntityID) -> Bool {
        remove(T.typeName, from: entityId)
    }

    // MARK: The entity's own plugin

    /// Makes `entityId` an entity of the named kind and returns its plugin, or `nil` when the
    /// type is not registered, in which case the slot is still created and binds when the type
    /// arrives. An entity is of one kind at most: a different kind replaces the one it had.
    /// `EntityPluginRegistry.instantiate` is the usual way in; this is for an entity that
    /// already exists.
    @discardableResult
    public func setEntityPlugin(_ typeName: String, on entityId: EntityID) -> EntityPlugin? {
        Self.install()
        guard scene.mask(for: entityId) != nil else { return nil }
        if storage(for: entityId) == nil {
            registerComponent(entityId: entityId, componentType: ScenePluginsComponent.self)
        }
        guard let storage = storage(for: entityId) else { return nil }
        if let current = storage.entitySlot, current.typeName != typeName {
            if let instance = current.instance {
                detach(instance)
            }
            storage.entitySlot = nil
        }
        if storage.entitySlot == nil {
            storage.entitySlot = ScenePluginsComponent.Slot(typeName: typeName)
        }
        bind(entityId: entityId)
        return storage.entitySlot?.instance as? EntityPlugin
    }

    /// Takes the kind away from the entity, with its saved values. The entity, its components
    /// and whatever mesh it has stay. Returns `false` when the entity was of no kind.
    @discardableResult
    public func removeEntityPlugin(from entityId: EntityID) -> Bool {
        guard let storage = storage(for: entityId), let slot = storage.entitySlot else { return false }
        if let instance = slot.instance {
            detach(instance)
        }
        storage.entitySlot = nil
        if storage.isEmpty {
            scene.remove(component: ScenePluginsComponent.self, from: entityId)
        }
        return true
    }

    /// The live plugin that makes `entityId` what it is, if it is of a kind.
    public func entityPlugin(on entityId: EntityID) -> EntityPlugin? {
        storage(for: entityId)?.entitySlot?.instance as? EntityPlugin
    }

    /// The entity's kind, bound or not, with the values an inspector should show.
    public func entitySlot(on entityId: EntityID) -> ScenePluginSlotInfo? {
        guard let slot = storage(for: entityId)?.entitySlot else { return nil }
        return ScenePluginSlotInfo(
            typeName: slot.typeName,
            isBound: slot.instance != nil,
            payload: slot.instance?.attributePayload() ?? slot.payload
        )
    }

    public func entities(withEntityPluginNamed typeName: String) -> [EntityID] {
        storageEntities().filter { entityId in
            guard let slot = storage(for: entityId)?.entitySlot else { return false }
            return slot.typeName == typeName && slot.instance != nil
        }
    }

    // MARK: Queries

    /// Live components on `entityId`, in slot order.
    public func components(on entityId: EntityID) -> [ComponentPlugin] {
        storage(for: entityId)?.slots.compactMap { $0.instance as? ComponentPlugin } ?? []
    }

    public func component(named typeName: String, on entityId: EntityID) -> ComponentPlugin? {
        storage(for: entityId)?.slots.first(where: { $0.typeName == typeName })?.instance as? ComponentPlugin
    }

    /// The live plugin of that type name on `entityId`: one of its components, or the entity's
    /// own plugin. This is how the editor and USC address a plugin without caring which it is.
    public func plugin(named typeName: String, on entityId: EntityID) -> ScenePlugin? {
        guard let storage = storage(for: entityId) else { return nil }
        if let instance = storage.slots.first(where: { $0.typeName == typeName })?.instance {
            return instance
        }
        if let slot = storage.entitySlot, slot.typeName == typeName {
            return slot.instance
        }
        return nil
    }

    /// Every component slot on `entityId`, bound or not, with the values an inspector should show.
    public func slots(on entityId: EntityID) -> [ScenePluginSlotInfo] {
        guard let storage = storage(for: entityId) else { return [] }
        return storage.slots.map { slot in
            ScenePluginSlotInfo(
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

    /// Writes one attribute from the editor and, outside play, tells the plugin about it.
    /// `typeName` names one of the entity's components or the entity's own plugin.
    @discardableResult
    public func setAttribute(
        _ property: String,
        of typeName: String,
        on entityId: EntityID,
        to value: UntoldAttributeValue
    ) -> Bool {
        guard let instance = plugin(named: typeName, on: entityId),
              let entry = instance.untoldAttributes().first(where: { $0.name == property }),
              entry.attribute.setAttributeValue(value)
        else { return false }
        if isPlaying == false {
            instance.onEditorChanged(property: property)
        }
        return true
    }

    /// Runs one of the plugin's exposed actions, as an editor button does.
    @discardableResult
    public func performAction(_ actionName: String, of typeName: String, on entityId: EntityID) -> Bool {
        guard let instance = plugin(named: typeName, on: entityId),
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
        // Components leave before the entity's own plugin, the reverse of how they arrived.
        defer {
            if let slot = storage.entitySlot, let instance = slot.instance,
               typeNames?.contains(slot.typeName) ?? true
            {
                if keepPayloads {
                    storage.entitySlot?.payload = instance.attributePayload()
                }
                detach(instance)
                storage.entitySlot?.instance = nil
            }
        }
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

    private func detach(_ instance: ScenePlugin) {
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
    private func storage(for entityId: EntityID) -> ScenePluginsComponent? {
        guard hasComponent(entityId: entityId, componentType: ScenePluginsComponent.self) else { return nil }
        return scene.get(component: ScenePluginsComponent.self, for: entityId)
    }

    /// Sorted so dispatch order is stable from frame to frame.
    private func storageEntities() -> [EntityID] {
        queryEntities(with: [ScenePluginsComponent.self]).sorted()
    }

    private func liveInstances() -> [ScenePlugin] {
        storageEntities().flatMap { entityId -> [ScenePlugin] in
            guard let storage = storage(for: entityId) else { return [] }
            return [storage.entitySlot?.instance].compactMap { $0 } + storage.slots.compactMap(\.instance)
        }
    }
}
