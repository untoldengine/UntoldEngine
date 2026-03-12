//
//  USCSystem.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - System Integration
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// System that manages and executes USC scripts
@MainActor
public class USCSystem {
    public static let shared = USCSystem()

    private let interpreter = USCInterpreter()

    // Multi-script: one entity may have multiple USCContext (one per script)
    private var scriptContexts: [EntityID: [USCContext]] = [:]

    private init() {}

    /// Initialize the USC system
    public func initialize() {
        scriptContexts.removeAll()
        Logger.log(message: "✅ USC System initialized")
    }

    /// Start interpreting scripts (called when Play mode starts in editor)
    public func startPlayMode() {
        scriptContexts.removeAll()

        // Load all entities that have ScriptComponent
        let scriptId = getComponentId(for: ScriptComponent.self)
        let scriptEntities = queryEntitiesWithComponentIds([scriptId], in: scene)

        for entityId in scriptEntities {
            guard let scriptComp = scene.get(component: ScriptComponent.self, for: entityId) else {
                continue
            }

            let scripts = scriptComp.scripts
            guard !scripts.isEmpty else { continue }

            // Build contexts for each script
            var contexts: [USCContext] = []
            contexts.reserveCapacity(scripts.count)

            for script in scripts {
                let context = USCContext(entityId: entityId, script: script)
                contexts.append(context)

                Logger.log(message: "🎬 USC: Loaded script '\(script.name)' for entity \(entityId)")

                // Execute OnStart event if present in script
                if scriptHasEvent(script, eventName: "OnStart") {
                    interpreter.execute(script: script, context: context, forEvent: "OnStart")
                    Logger.log(message: "🚀 USC: Executed OnStart for '\(script.name)'")
                }
            }

            scriptContexts[entityId] = contexts
        }

        let total = activeScriptCount
        Logger.log(message: "▶️  USC System: Play mode started (\(total) scripts active)")
    }

    /// Stop interpreting scripts (called when Play mode stops)
    public func stopPlayMode() {
        let count = activeScriptCount
        scriptContexts.removeAll()
        Logger.log(message: "⏹️  USC System: Play mode stopped (\(count) scripts unloaded)")
    }

    /// Update all per-frame scripts (called every frame)
    public func update(_: Float) {
        guard gameMode else { return }

        for (_, contexts) in scriptContexts {
            for context in contexts {
                guard let script = context.script else { continue }
                if scriptHasEvent(script, eventName: "OnUpdate") {
                    interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
                }
            }
        }
    }

    /// Trigger event-based scripts for a specific entity
    public func triggerEvent(_ eventName: String, for entityId: EntityID) {
        guard gameMode else { return }
        guard let contexts = scriptContexts[entityId] else { return }

        for context in contexts {
            guard let script = context.script else { continue }
            if scriptHasEvent(script, eventName: eventName) {
                interpreter.execute(script: script, context: context, forEvent: eventName)
                Logger.log(message: "⚡ USC: Triggered event '\(eventName)' for entity \(entityId) [script: \(script.name)]")
            }
        }
    }

    /// Hot-reload a script (update while running) by name
    public func reloadScript(named scriptName: String, for entityId: EntityID) {
        guard let contexts = scriptContexts[entityId] else { return }

        // Find context index by script name
        if let idx = contexts.firstIndex(where: { $0.script?.name == scriptName }) {
            // Try to fetch the latest script from registry if available; otherwise keep the same script object
            let newScript = scriptRegistry[scriptName] ?? contexts[idx].script
            contexts[idx].script = newScript
            scriptContexts[entityId] = contexts
            Logger.log(message: "🔥 USC: Script '\(scriptName)' hot-reloaded for entity \(entityId)")
        }
    }

    /// Attach a new script to an entity at runtime
    public func attachScript(_ script: USCScript, to entityId: EntityID) {
        var contexts = scriptContexts[entityId] ?? []
        let context = USCContext(entityId: entityId, script: script)
        contexts.append(context)
        scriptContexts[entityId] = contexts

        // Also append to the entity's ScriptComponent.scripts if present
        if let scriptComp = scene.get(component: ScriptComponent.self, for: entityId) {
            scriptComp.scripts.append(script)
        }

        Logger.log(message: "📎 USC: Attached script '\(script.name)' to entity \(entityId)")
    }

    /// Detach a script by name from an entity
    public func detachScript(named scriptName: String, from entityId: EntityID) {
        guard var contexts = scriptContexts[entityId] else { return }

        // Remove matching contexts
        let originalCount = contexts.count
        contexts.removeAll { $0.script?.name == scriptName }
        scriptContexts[entityId] = contexts

        // Also remove from the ScriptComponent if present
        if let scriptComp = scene.get(component: ScriptComponent.self, for: entityId) {
            scriptComp.scripts.removeAll { $0.name == scriptName }
        }

        let removed = originalCount - contexts.count
        if removed > 0 {
            Logger.log(message: "✂️  USC: Detached script '\(scriptName)' from entity \(entityId) (\(removed) removed)")
        }
    }

    /// Detach all scripts from an entity
    public func detachAllScripts(from entityId: EntityID) {
        let removed = scriptContexts[entityId]?.count ?? 0
        scriptContexts.removeValue(forKey: entityId)

        // Also clear ScriptComponent if present
        if let scriptComp = scene.get(component: ScriptComponent.self, for: entityId) {
            scriptComp.scripts.removeAll()
        }

        Logger.log(message: "🧹 USC: Detached all scripts from entity \(entityId) (\(removed) removed)")
    }

    /// Get current scripts for an entity
    public func getScripts(for entityId: EntityID) -> [USCScript] {
        if let contexts = scriptContexts[entityId] {
            return contexts.compactMap(\.script)
        }
        return []
    }

    /// Check if entity has any active scripts
    public func hasScripts(entityId: EntityID) -> Bool {
        guard let contexts = scriptContexts[entityId] else { return false }
        return !contexts.isEmpty
    }

    /// Get number of active scripts (sum across all entities)
    public var activeScriptCount: Int {
        scriptContexts.values.reduce(0) { $0 + $1.count }
    }

    /// Get all active scripts (for build system)
    public func getAllScripts() -> [USCScript] {
        scriptContexts.values.flatMap { $0.compactMap(\.script) }
    }

    // MARK: - Helper Methods

    /// Check if a script contains a specific event
    private func scriptHasEvent(_ script: USCScript, eventName: String) -> Bool {
        for instruction in script.instructions {
            if case let .event(name) = instruction, name == eventName {
                return true
            }
        }
        return false
    }
}
