//
//  PrimitiveNodes.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
import SwiftUI

/// Base class for procedurally generated primitive nodes (cube, sphere, plane...).
/// The mesh is generated synchronously, so material modifiers apply immediately.
@MainActor
open class PrimitiveNode: Node, NodeMaterial, NodeKinetics {
    public init(meshes: [Mesh], assetName: String, entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(entityID: entityID, name: name, content: content)

        if name == nil { setEntityName(entityId: self.entityID, name: assetName) }
        setEntityMeshDirect(entityId: self.entityID, meshes: meshes, assetName: assetName)
    }
}

@MainActor
public final class CubeNode: PrimitiveNode {
    public convenience init(size: Float = 1.0, segments: UInt32 = 1, entityID: EntityID? = nil, name: String? = nil) {
        self.init(size: size, segments: segments, entityID: entityID, name: name) {}
    }

    public init(size: Float = 1.0, segments: UInt32 = 1, entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(meshes: BasicPrimitives.createCube(extent: size, segments: segments), assetName: "Cube", entityID: entityID, name: name, content: content)
    }
}

@MainActor
public final class SphereNode: PrimitiveNode {
    public convenience init(radius: Float = 0.5, segments: [UInt32] = [32, 16], entityID: EntityID? = nil, name: String? = nil) {
        self.init(radius: radius, segments: segments, entityID: entityID, name: name) {}
    }

    public init(radius: Float = 0.5, segments: [UInt32] = [32, 16], entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(meshes: BasicPrimitives.createSphere(extent: radius * 2.0, segments: segments), assetName: "Sphere", entityID: entityID, name: name, content: content)
    }
}

@MainActor
public final class PlaneNode: PrimitiveNode {
    public convenience init(width: Float = 1.0, depth: Float = 1.0, segments: [UInt32] = [1, 1], entityID: EntityID? = nil, name: String? = nil) {
        self.init(width: width, depth: depth, segments: segments, entityID: entityID, name: name) {}
    }

    public init(width: Float = 1.0, depth: Float = 1.0, segments: [UInt32] = [1, 1], entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(meshes: BasicPrimitives.createPlane(width: width, depth: depth, segments: segments), assetName: "Plane", entityID: entityID, name: name, content: content)
    }
}

@MainActor
public final class CylinderNode: PrimitiveNode {
    public convenience init(height: Float = 1.0, radius: Float = 0.5, segments: [UInt32] = [32, 1], entityID: EntityID? = nil, name: String? = nil) {
        self.init(height: height, radius: radius, segments: segments, entityID: entityID, name: name) {}
    }

    public init(height: Float = 1.0, radius: Float = 0.5, segments: [UInt32] = [32, 1], entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(meshes: BasicPrimitives.createCylinder(height: height, radius: radius, segments: segments), assetName: "Cylinder", entityID: entityID, name: name, content: content)
    }
}

@MainActor
public final class ConeNode: PrimitiveNode {
    public convenience init(height: Float = 1.0, radius: Float = 0.5, segments: [UInt32] = [32, 1], entityID: EntityID? = nil, name: String? = nil) {
        self.init(height: height, radius: radius, segments: segments, entityID: entityID, name: name) {}
    }

    public init(height: Float = 1.0, radius: Float = 0.5, segments: [UInt32] = [32, 1], entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping @MainActor () -> [any NodeProtocol]) {
        super.init(meshes: BasicPrimitives.createCone(height: height, radius: radius, segments: segments), assetName: "Cone", entityID: entityID, name: name, content: content)
    }
}
