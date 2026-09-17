//
//  EditorRepresentation.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// What stands for an entity in the editor's viewport when it has nothing of its own to show:
/// a spawn point, a trigger, a rules object. The editor draws it while editing, the way it
/// draws its own light markers. It is never saved and never exists in a game.
public enum EditorRepresentation: Equatable, Sendable {
    /// Nothing is drawn. Right for an entity with its own mesh, and for one that needs no marker.
    case none
    /// A camera-facing icon. `systemImage` is an SF Symbol name; `tint` is RGB, 0 to 1.
    case icon(systemImage: String, tint: SIMD3<Float> = SIMD3<Float>(1, 1, 1))
}

public extension CodeComponent {
    /// Gives the entity a mesh that this component builds in code, replacing any it had and
    /// keeping the material of the mesh it replaces.
    ///
    /// Call it from `onAttach()`, and again whenever the attributes that shape it change. The
    /// scene does not store generated geometry: it stores this component's attributes, and the
    /// component rebuilds the mesh when the scene is loaded, in the editor and in the game.
    /// Make the meshes with `BasicPrimitives`, or `BasicPrimitives.createMesh(from:)` for a
    /// shape of your own.
    final func setGeneratedMesh(_ meshes: [Mesh], name: String) {
        guard meshes.isEmpty == false, scene.mask(for: entity) != nil else { return }
        var meshes = meshes
        if hasComponent(entityId: entity, componentType: RenderComponent.self),
           let material = scene.get(component: RenderComponent.self, for: entity)?.mesh.first?.submeshes.first?.material
        {
            for meshIndex in meshes.indices {
                for submeshIndex in meshes[meshIndex].submeshes.indices {
                    meshes[meshIndex].submeshes[submeshIndex].material = material
                }
            }
        }
        setEntityMeshDirect(entityId: entity, meshes: meshes, assetName: name)
    }
}
