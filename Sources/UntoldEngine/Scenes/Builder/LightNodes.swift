//
//  LightNodes.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

@MainActor
public protocol NodeLight: NodeProtocol {}

@MainActor
public extension NodeLight {
    func color(_ red: Float, _ green: Float, _ blue: Float) -> Self {
        setLight(entityId: entityID, .color(simd_float3(red, green, blue)))
        return self
    }

    func intensity(_ value: Float) -> Self {
        setLight(entityId: entityID, .intensity(value))
        return self
    }
}

/// Declares a directional (sun) light. Declaring one makes it the scene's
/// active directional light, replacing the renderer's default.
@MainActor
public final class DirectionalLightNode: Node, NodeLight {
    public init(entityID: EntityID? = nil, name: String? = nil) {
        super.init(entityID: entityID, name: name) {}

        if name == nil { setEntityName(entityId: self.entityID, name: "Directional Light") }
        if !hasComponent(entityId: self.entityID, componentType: DirectionalLightComponent.self) {
            createDirLight(entityId: self.entityID)
        }
        setLight(entityId: self.entityID, .directional(.active))
    }
}

@MainActor
public final class PointLightNode: Node, NodeLight {
    public init(entityID: EntityID? = nil, name: String? = nil) {
        super.init(entityID: entityID, name: name) {}

        if name == nil { setEntityName(entityId: self.entityID, name: "Point Light") }
        if !hasComponent(entityId: self.entityID, componentType: PointLightComponent.self) {
            createPointLight(entityId: self.entityID)
        }
    }

    public func radius(_ value: Float) -> Self {
        setLight(entityId: entityID, .point(.radius(value)))
        return self
    }

    public func falloff(_ value: Float) -> Self {
        setLight(entityId: entityID, .point(.falloff(value)))
        return self
    }

    /// Distance attenuation: 1 / (constant + linear·d + quadratic·d²)
    public func attenuation(constant: Float = 1, linear: Float = 0, quadratic: Float = 0) -> Self {
        setLight(entityId: entityID, .point(.attenuation(simd_float3(constant, linear, quadratic))))
        return self
    }
}

@MainActor
public final class SpotLightNode: Node, NodeLight {
    public init(entityID: EntityID? = nil, name: String? = nil) {
        super.init(entityID: entityID, name: name) {}

        if name == nil { setEntityName(entityId: self.entityID, name: "Spot Light") }
        if !hasComponent(entityId: self.entityID, componentType: SpotLightComponent.self) {
            createSpotLight(entityId: self.entityID)
        }
    }

    public func coneAngle(_ value: Float) -> Self {
        setLight(entityId: entityID, .spot(.coneAngle(value)))
        return self
    }

    public func radius(_ value: Float) -> Self {
        setLight(entityId: entityID, .spot(.radius(value)))
        return self
    }
}
