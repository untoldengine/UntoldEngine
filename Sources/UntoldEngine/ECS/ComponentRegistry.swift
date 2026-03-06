//
//  ComponentRegistry.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public struct ComponentCleanupHandler {
    public let handlerId: String
    public let componentType: Any.Type
    public let componentName: String
    public let priority: Int
    public let cleanup: (EntityID) -> Void
}

public enum ComponentRegistry {
    private static var handlersByComponentId: [Int: ComponentCleanupHandler] = [:]
    private static let registryLock = NSLock()

    public static func register(
        componentType: (some Component).Type,
        handlerId: String? = nil,
        priority: Int = 100,
        cleanup: @escaping (EntityID) -> Void
    ) {
        let componentId = getComponentId(for: componentType)
        let name = String(describing: componentType)
        let resolvedHandlerId = handlerId ?? name
        let handler = ComponentCleanupHandler(
            handlerId: resolvedHandlerId,
            componentType: componentType,
            componentName: name,
            priority: priority,
            cleanup: cleanup
        )

        registryLock.lock()
        handlersByComponentId[componentId] = handler
        registryLock.unlock()
    }

    public static func hasCleanupHandler(for componentType: (some Component).Type) -> Bool {
        let componentId = getComponentId(for: componentType)
        return hasCleanupHandler(forComponentId: componentId)
    }

    public static func hasCleanupHandler(forComponentId componentId: Int) -> Bool {
        registryLock.lock()
        let exists = handlersByComponentId[componentId] != nil
        registryLock.unlock()
        return exists
    }

    public static func assertCleanupRegistered(
        for componentType: (some Component).Type,
        file: StaticString = #fileID,
        line: UInt = #line
    ) {
        if hasCleanupHandler(for: componentType) {
            return
        }

        let componentName = String(describing: componentType)
        let message = "Missing cleanup handler for component \(componentName). Register it in registerComponentCleanupHandlers()."
        Logger.logWarning(message: message, category: "ECS")
        #if DEBUG
            assertionFailure(message, file: file, line: line)
        #endif
    }

    public static func cleanupAll(entityId: EntityID) {
        let entityIndex = Int(getEntityIndex(entityId))
        guard entityIndex >= 0, entityIndex < scene.entities.count else {
            return
        }

        let entity = scene.entities[entityIndex]
        guard entity.entityId == entityId, !entity.freed else {
            return
        }

        registryLock.lock()
        var uniqueHandlers: [String: ComponentCleanupHandler] = [:]
        var missingHandlerComponentIds: [Int] = []

        for componentId in 0 ..< MAX_COMPONENTS {
            guard entity.mask.test(componentId) else {
                continue
            }

            guard let handler = handlersByComponentId[componentId] else {
                missingHandlerComponentIds.append(componentId)
                continue
            }

            if let existing = uniqueHandlers[handler.handlerId] {
                if handler.priority < existing.priority {
                    uniqueHandlers[handler.handlerId] = handler
                }
            } else {
                uniqueHandlers[handler.handlerId] = handler
            }
        }

        registryLock.unlock()

        if missingHandlerComponentIds.isEmpty == false {
            let missingIds = missingHandlerComponentIds.map(String.init).sorted().joined(separator: ", ")
            Logger.logWarning(
                message: "Entity \(entityId) has components with no registered cleanup handlers. Component IDs: [\(missingIds)]",
                category: "ECS"
            )
        }

        let orderedHandlers = uniqueHandlers.values.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.handlerId < rhs.handlerId
        }

        for handler in orderedHandlers {
            handler.cleanup(entityId)
        }
    }

    public static func registeredComponentTypeNames() -> Set<String> {
        registryLock.lock()
        let names = Set(handlersByComponentId.values.map(\.componentName))
        registryLock.unlock()
        return names
    }

    static func resetForTests() {
        registryLock.lock()
        handlersByComponentId.removeAll()
        registryLock.unlock()
    }
}
