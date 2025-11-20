//
//  USCSystem.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - System Integration
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation

/// System that manages and executes USC scripts
public class USCSystem {
    public static let shared = USCSystem()

    private let interpreter = USCInterpreter()
    private var scriptContexts: [EntityID: USCContext] = [:]

    private init() {}

    /// Initialize the USC system
    public func initialize() {
        scriptContexts.removeAll()
        Logger.log(message: "✅ USC System initialized")
    }

    /// Start interpreting scripts (called when Play mode starts in editor)
    public func startPlayMode() {
        scriptContexts.removeAll()

        // Load all script components
        let scriptId = getComponentId(for: ScriptComponent.self)
        let scriptEntities = queryEntitiesWithComponentIds([scriptId], in: scene)

        for entityId in scriptEntities {
            guard let scriptComp = scene.get(component: ScriptComponent.self, for: entityId),
                  let script = scriptComp.script
            else {
                continue
            }

            let context = USCContext(entityId: entityId, script: script)
            scriptContexts[entityId] = context

            Logger.log(message: "🎬 USC: Loaded script '\(script.name)' for entity \(entityId)")
        }

        Logger.log(message: "▶️  USC System: Play mode started (\(scriptContexts.count) scripts active)")
    }

    /// Stop interpreting scripts (called when Play mode stops)
    public func stopPlayMode() {
        let count = scriptContexts.count
        scriptContexts.removeAll()
        Logger.log(message: "⏹️  USC System: Play mode stopped (\(count) scripts unloaded)")
    }

    /// Update all per-frame scripts (called every frame)
    public func update(_: Float) {
        guard gameMode else { return }

        for (entityId, context) in scriptContexts {
            guard let script = context.script else { continue }

            // Only execute per-frame scripts
            if script.metadata.triggerType == .perFrame {
                interpreter.execute(script: script, context: context)
            }
        }
    }

    /// Trigger event-based scripts
    public func triggerEvent(_ eventName: String, for entityId: EntityID) {
        guard gameMode else { return }
        guard let context = scriptContexts[entityId] else { return }
        guard let script = context.script else { return }

        // Check if script handles this event
        if script.metadata.triggerType == .event {
            if case let .event(scriptEvent) = script.instructions.first,
               scriptEvent == eventName
            {
                interpreter.execute(script: script, context: context)
                Logger.log(message: "⚡ USC: Triggered event '\(eventName)' for entity \(entityId)")
            }
        }
    }

    /// Hot-reload a script (update while running)
    public func reloadScript(_ script: USCScript, for entityId: EntityID) {
        guard var context = scriptContexts[entityId] else { return }
        context.script = script
        scriptContexts[entityId] = context
        Logger.log(message: "🔥 USC: Script '\(script.name)' hot-reloaded for entity \(entityId)")
    }

    /// Attach a script to an entity at runtime
    public func attachScript(_ script: USCScript, to entityId: EntityID) {
        let context = USCContext(entityId: entityId, script: script)
        scriptContexts[entityId] = context
        Logger.log(message: "📎 USC: Attached script '\(script.name)' to entity \(entityId)")
    }

    /// Detach script from an entity
    public func detachScript(from entityId: EntityID) {
        scriptContexts.removeValue(forKey: entityId)
        Logger.log(message: "✂️  USC: Detached script from entity \(entityId)")
    }

    /// Get current script for entity
    public func getScript(for entityId: EntityID) -> USCScript? {
        scriptContexts[entityId]?.script
    }

    /// Check if entity has an active script
    public func hasScript(entityId: EntityID) -> Bool {
        scriptContexts[entityId] != nil
    }

    /// Get number of active scripts
    public var activeScriptCount: Int {
        scriptContexts.count
    }
}
