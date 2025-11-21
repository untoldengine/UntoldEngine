//
//  USCPropertyAccess.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - Property Access System
//  Dynamic property reading/writing for components.
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// This file was jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import Foundation
import simd

/// Property access system for USC scripts
public class USCPropertyAccess {
    public static let shared = USCPropertyAccess()

    private init() {}

    /// Get property value from entity
    public func getValue(for entityId: EntityID, keyPath: String) -> Value? {
        let components = keyPath.split(separator: ".").map(String.init)
        guard !components.isEmpty else { return nil }

        let componentName = components[0]
        let subProperty = components.count > 1 ? components[1] : nil

        // LocalTransformComponent properties
        if componentName == "position" || componentName == "rotation" || componentName == "scale" {
            guard let transform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                return nil
            }

            switch componentName {
            case "position":
                return getVec3Property(transform.position, subProperty: subProperty)
            case "scale":
                return getVec3Property(transform.scale, subProperty: subProperty)
            default:
                return nil
            }
        }

        // PhysicsComponent properties
        if componentName == "velocity" || componentName == "acceleration" || componentName == "mass" {
            guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
                return nil
            }

            switch componentName {
            case "velocity":
                return getVec3Property(physics.velocity, subProperty: subProperty)
            case "acceleration":
                return getVec3Property(physics.acceleration, subProperty: subProperty)
            case "mass":
                return .float(physics.mass)
            default:
                return nil
            }
        }

        // LightComponent properties
        if componentName == "intensity" || componentName == "color" {
            guard let light = scene.get(component: LightComponent.self, for: entityId) else {
                return nil
            }

            switch componentName {
            case "intensity":
                return .float(light.intensity)
            case "color":
                return getVec3Property(light.color, subProperty: subProperty)
            default:
                return nil
            }
        }

        return nil
    }

    /// Set property value on entity
    public func setValue(for entityId: EntityID, keyPath: String, value: Value) {
        let components = keyPath.split(separator: ".").map(String.init)
        guard !components.isEmpty else { return }

        let componentName = components[0]
        let subProperty = components.count > 1 ? components[1] : nil

        // LocalTransformComponent properties
        if componentName == "position" || componentName == "scale" {
            guard let transform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                return
            }

            switch componentName {
            case "position":
                setVec3Property(&transform.position, subProperty: subProperty, value: value)
            case "scale":
                setVec3Property(&transform.scale, subProperty: subProperty, value: value)
            default:
                break
            }
        }

        // PhysicsComponent properties
        if componentName == "velocity" || componentName == "acceleration" || componentName == "mass" {
            guard let physics = scene.get(component: PhysicsComponents.self, for: entityId) else {
                return
            }

            switch componentName {
            case "velocity":
                setVec3Property(&physics.velocity, subProperty: subProperty, value: value)
            case "acceleration":
                setVec3Property(&physics.acceleration, subProperty: subProperty, value: value)
            case "mass":
                if case let .float(mass) = value {
                    physics.mass = mass
                }
            default:
                break
            }
        }

        // LightComponent properties
        if componentName == "intensity" || componentName == "color" {
            guard let light = scene.get(component: LightComponent.self, for: entityId) else {
                return
            }

            switch componentName {
            case "intensity":
                if case let .float(intensity) = value {
                    light.intensity = intensity
                }
            case "color":
                setVec3Property(&light.color, subProperty: subProperty, value: value)
            default:
                break
            }
        }
    }

    // MARK: - Helper Methods

    /// Get vec3 component (x, y, z) or entire vector
    private func getVec3Property(_ vec: simd_float3, subProperty: String?) -> Value {
        guard let sub = subProperty else {
            return .vec3(x: vec.x, y: vec.y, z: vec.z)
        }

        switch sub.lowercased() {
        case "x": return .float(vec.x)
        case "y": return .float(vec.y)
        case "z": return .float(vec.z)
        default: return .vec3(x: vec.x, y: vec.y, z: vec.z)
        }
    }

    /// Set vec3 component or entire vector
    private func setVec3Property(_ vec: inout simd_float3, subProperty: String?, value: Value) {
        if let sub = subProperty {
            // Set individual component
            guard case let .float(f) = value else { return }

            switch sub.lowercased() {
            case "x": vec.x = f
            case "y": vec.y = f
            case "z": vec.z = f
            default: break
            }
        } else {
            // Set entire vector
            if case let .vec3(x, y, z) = value {
                vec = simd_float3(x, y, z)
            }
        }
    }
}

// MARK: - Convenience Extensions

extension USCInterpreter {
    /// Enhanced property access using the property system
    func getPropertyValue(entityId: EntityID, key: String) -> Value? {
        USCPropertyAccess.shared.getValue(for: entityId, keyPath: key)
    }

    /// Enhanced property modification using the property system
    func setPropertyValue(entityId: EntityID, key: String, value: Value) {
        USCPropertyAccess.shared.setValue(for: entityId, keyPath: key, value: value)
    }
}
