//
//  EntityPlugin.swift
//  UntoldComponentKit
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import UntoldEngine

/// Where the editor lists a kind of entity. The set is closed on purpose, like the menu
/// roots: loaded code picks a shelf and can never add one.
public enum UntoldEntityShelf: String, CaseIterable, Sendable {
    /// Next to Cube, Sphere and Plane: things with a shape of their own.
    case primitives
    /// Next to the built-in light types.
    case lights
    /// Everything else: markers, paths, volumes, logic. Shown only while it holds something.
    case entities

    public var title: String {
        switch self {
        case .primitives: "Primitives"
        case .lights: "Lights"
        case .entities: "Entities"
        }
    }
}

/// Base class for a kind of entity written in code: a torus, a spawn point, a spline.
///
/// The plugin *is* the entity, not a recipe for one. The editor lists the kind on one of its
/// creation shelves; an instance is bound to each entity of the kind for as long as the entity
/// lives, saved with the scene and bound again when the scene is loaded, in the editor and in
/// the game. So everything that is part of the entity lives here:
///
/// - **Its own properties.** `@UntoldAttribute` properties are shown in the Inspector as the
///   entity's own block, above whatever components it carries.
/// - **Its geometry**, if it has any: build it in `onAttach()` and `onEditorChanged(property:)`
///   and hand it over with `setGeneratedMesh`. The game shows it too.
/// - **Its editor representation**, if it has any: `editorRepresentation`, drawn only while
///   editing.
///
/// An entity can have either, both or neither: a torus is geometry, a spawn point is an
/// editor marker, a spline is a tube in the game plus control points in the editor, and a
/// rules object is nothing but properties and behaviour.
///
///     final class SpawnPointEntity: EntityPlugin {
///         @UntoldAttribute var team: Team = .neutral
///
///         override var editorRepresentation: EditorRepresentation {
///             .icon(systemImage: "flag.fill", tint: team.tint)
///         }
///     }
///
/// Components are still added to such an entity like to any other. What can only ever belong
/// to this kind of entity is not a component: make it a property here.
open class EntityPlugin: ScenePlugin {
    /// `true` once the plugin has given the entity a mesh with `setGeneratedMesh`. The mesh is
    /// then part of the entity, so the editor does not let it be removed on its own.
    public internal(set) final var ownsGeneratedMesh: Bool = false

    /// The name on the shelf and in the Inspector. Defaults to the type name spelled out,
    /// without a trailing "EntityPlugin", "Plugin" or "Entity".
    override open class var displayName: String {
        var name = typeName
        for suffix in ["EntityPlugin", "Plugin", "Entity"] where name.hasSuffix(suffix) && name.count > suffix.count {
            name = String(name.dropLast(suffix.count))
            break
        }
        return humanizedIdentifier(name)
    }

    open class var shelf: UntoldEntityShelf {
        .entities
    }

    /// An SF Symbol name for the shelf row and the Inspector block.
    open class var systemImage: String {
        "cube.transparent"
    }

    /// Runs once, when the entity is first created from this kind, after `onAttach()`. The
    /// place to give a new entity the components it starts with. It does not run when a scene
    /// is loaded or a library reloaded: those bring back what was saved.
    open func onCreate() {}

    /// What the editor draws for this entity besides its geometry. Read every frame while
    /// editing, so it can follow the properties: a team's color, a curve's control points.
    open var editorRepresentation: EditorRepresentation {
        .none
    }

    /// Adds a component to this entity and returns it, ready to be given its starting values.
    @discardableResult
    public final func add<T: ComponentPlugin>(_ type: T.Type) -> T? {
        ScenePluginSystem.shared.add(type, to: entity)
    }

    /// Gives the entity a mesh built in code, replacing any it had and keeping the material of
    /// the mesh it replaces.
    ///
    /// Call it from `onAttach()`, and again whenever the properties that shape it change. The
    /// scene does not store generated geometry: it stores this plugin's properties, and the
    /// plugin rebuilds the mesh when the scene is loaded. Make the meshes with
    /// `BasicPrimitives`, or `BasicPrimitives.createMesh(from:)` for a shape of your own.
    public final func setGeneratedMesh(_ meshes: [Mesh], name: String) {
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
        ownsGeneratedMesh = true
    }
}
