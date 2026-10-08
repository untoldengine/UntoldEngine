//
//  RenderSceneSnapshot.swift
//  UntoldEngine
//
//  The scene as one render pass reads it: one read of the scene, with the component
//  ids and the component storage the passes need looked up once.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Which of the components the render passes ask about an entity has.
///
/// Taken from the entity's component mask, so that a pass reads the mask once and
/// tests bits where it used to ask the scene about each component in turn.
struct RenderEntityTraits: OptionSet {
    let rawValue: UInt32

    // What a pass needs to draw the entity.
    static let render = RenderEntityTraits(rawValue: 1 << 0)
    static let worldTransform = RenderEntityTraits(rawValue: 1 << 1)
    static let localTransform = RenderEntityTraits(rawValue: 1 << 2)

    // Entities no geometry pass draws.
    static let gizmo = RenderEntityTraits(rawValue: 1 << 3)
    static let light = RenderEntityTraits(rawValue: 1 << 4)
    static let camera = RenderEntityTraits(rawValue: 1 << 5)
    static let sceneCamera = RenderEntityTraits(rawValue: 1 << 6)

    // How the entity is drawn.
    static let sceneChannels = RenderEntityTraits(rawValue: 1 << 7)
    static let staticBatch = RenderEntityTraits(rawValue: 1 << 8)
    static let meshOccluder = RenderEntityTraits(rawValue: 1 << 9)
    static let meshFade = RenderEntityTraits(rawValue: 1 << 10)
    static let tileRepresentationFade = RenderEntityTraits(rawValue: 1 << 11)
    static let lod = RenderEntityTraits(rawValue: 1 << 12)
    static let deformation = RenderEntityTraits(rawValue: 1 << 13)
    static let skeleton = RenderEntityTraits(rawValue: 1 << 14)
    static let tileLODTag = RenderEntityTraits(rawValue: 1 << 15)

    /// The components every draw of an entity reads.
    static let drawable: RenderEntityTraits = [.render, .worldTransform, .localTransform]
}

/// The scene as one render pass reads it.
///
/// A pass asks the same few things about thousands of entities: is it alive, which of
/// a dozen components does it have, where are its render and transform components.
/// Asked through `scene`, each of those questions takes the scene lock, copies the
/// scene and looks the component's id up. A snapshot reads the scene once, looks the
/// ids and the component storage up once, and answers from what it took.
///
/// Build one when a pass starts and let it go when the pass ends. An entity created or
/// destroyed, or a component added or removed, while it is held shows in the next one.
/// The components it hands out are the scene's own objects, so their values are
/// always the current ones.
struct RenderSceneSnapshot {
    /// An entity that was alive when the snapshot was taken. It belongs to the snapshot
    /// that handed it out: another snapshot may have a different entity at its index.
    struct Entity {
        let entityId: EntityID
        let traits: RenderEntityTraits
        fileprivate let index: Int
    }

    /// The components every draw of an entity reads.
    struct DrawComponents {
        let render: RenderComponent
        let world: WorldTransformComponent
        let local: LocalTransformComponent
    }

    private let entities: [EntityDesc]
    private let ids: ComponentIds
    private let pools: ComponentPools

    init() {
        let snapshot = scene
        entities = snapshot.entities
        ids = ComponentIds()
        pools = ComponentPools(ids: ids, scene: snapshot)
    }

    /// How many entity indices the scene has handed out; some are free.
    var entityCapacity: Int {
        entities.count
    }

    /// The entity, or nil if it is gone, is waiting to be destroyed, or the id is that of
    /// an entity that had its index before.
    @inline(__always)
    func entity(_ entityId: EntityID) -> Entity? {
        let index = Int(getEntityIndex(entityId))
        guard index < entities.count else { return nil }
        let description = entities[index]
        guard description.entityId == entityId, !description.freed, !description.pendingDestroy else { return nil }
        return Entity(entityId: entityId, traits: ids.traits(of: description.mask), index: index)
    }

    /// Calls `body` for every entity that has all of `traits`, in the order of their indices.
    func forEachEntity(with traits: RenderEntityTraits, _ body: (Entity) -> Void) {
        for index in entities.indices {
            let description = entities[index]
            if description.freed || description.pendingDestroy { continue }
            let entityTraits = ids.traits(of: description.mask)
            guard entityTraits.isSuperset(of: traits) else { continue }
            body(Entity(entityId: description.entityId, traits: entityTraits, index: index))
        }
    }

    /// The render and transform components of `entity`, or nil if it lacks one of them.
    @inline(__always)
    func drawComponents(of entity: Entity) -> DrawComponents? {
        guard entity.traits.isSuperset(of: .drawable),
              let render = object(pools.render, entity, as: RenderComponent.self),
              let world = object(pools.world, entity, as: WorldTransformComponent.self),
              let local = object(pools.local, entity, as: LocalTransformComponent.self)
        else { return nil }
        return DrawComponents(render: render, world: world, local: local)
    }

    @inline(__always)
    func render(of entity: Entity) -> RenderComponent? {
        component(.render, pools.render, of: entity)
    }

    @inline(__always)
    func worldTransform(of entity: Entity) -> WorldTransformComponent? {
        component(.worldTransform, pools.world, of: entity)
    }

    @inline(__always)
    func localTransform(of entity: Entity) -> LocalTransformComponent? {
        component(.localTransform, pools.local, of: entity)
    }

    @inline(__always)
    func lod(of entity: Entity) -> LODComponent? {
        component(.lod, pools.lod, of: entity)
    }

    @inline(__always)
    func meshOccluder(of entity: Entity) -> MeshOccluderComponent? {
        component(.meshOccluder, pools.meshOccluder, of: entity)
    }

    @inline(__always)
    func meshFade(of entity: Entity) -> MeshFadeComponent? {
        component(.meshFade, pools.meshFade, of: entity)
    }

    @inline(__always)
    func tileRepresentationFade(of entity: Entity) -> TileRepresentationFadeComponent? {
        component(.tileRepresentationFade, pools.tileRepresentationFade, of: entity)
    }

    @inline(__always)
    func deformation(of entity: Entity) -> DeformationComponent? {
        component(.deformation, pools.deformation, of: entity)
    }

    @inline(__always)
    func tileLODTag(of entity: Entity) -> TileLODTagComponent? {
        component(.tileLODTag, pools.tileLODTag, of: entity)
    }

    /// The scene channels of `entity`: those of its channel component, or the ones an
    /// entity without the component gets from its name.
    @inline(__always)
    func sceneChannels(of entity: Entity) -> SceneChannel {
        let channels: EntitySceneChannelsComponent? = component(.sceneChannels, pools.sceneChannels, of: entity)
        return channels?.channels ?? getEntitySceneChannels(entityId: entity.entityId)
    }

    // MARK: - Storage

    @inline(__always)
    private func component<T: Component>(_ trait: RenderEntityTraits, _ pool: ComponentPool?, of entity: Entity) -> T? {
        guard entity.traits.contains(trait) else { return nil }
        return object(pool, entity, as: T.self)
    }

    @inline(__always)
    private func object<T: Component>(_ pool: ComponentPool?, _ entity: Entity, as _: T.Type) -> T? {
        pool?.component(at: entity.index, as: T.self)
    }

    /// The ids of the components the passes ask about, looked up once.
    private struct ComponentIds {
        let render = getComponentId(for: RenderComponent.self)
        let world = getComponentId(for: WorldTransformComponent.self)
        let local = getComponentId(for: LocalTransformComponent.self)
        let gizmo = getComponentId(for: GizmoComponent.self)
        let light = getComponentId(for: LightComponent.self)
        let camera = getComponentId(for: CameraComponent.self)
        let sceneCamera = getComponentId(for: SceneCameraComponent.self)
        let sceneChannels = getComponentId(for: EntitySceneChannelsComponent.self)
        let staticBatch = getComponentId(for: StaticBatchComponent.self)
        let meshOccluder = getComponentId(for: MeshOccluderComponent.self)
        let meshFade = getComponentId(for: MeshFadeComponent.self)
        let tileRepresentationFade = getComponentId(for: TileRepresentationFadeComponent.self)
        let lod = getComponentId(for: LODComponent.self)
        let deformation = getComponentId(for: DeformationComponent.self)
        let skeleton = getComponentId(for: SkeletonComponent.self)
        let tileLODTag = getComponentId(for: TileLODTagComponent.self)

        @inline(__always)
        func traits(of mask: ComponentMask) -> RenderEntityTraits {
            var traits: RenderEntityTraits = []
            if mask.test(render) { traits.insert(.render) }
            if mask.test(world) { traits.insert(.worldTransform) }
            if mask.test(local) { traits.insert(.localTransform) }
            if mask.test(gizmo) { traits.insert(.gizmo) }
            if mask.test(light) { traits.insert(.light) }
            if mask.test(camera) { traits.insert(.camera) }
            if mask.test(sceneCamera) { traits.insert(.sceneCamera) }
            if mask.test(sceneChannels) { traits.insert(.sceneChannels) }
            if mask.test(staticBatch) { traits.insert(.staticBatch) }
            if mask.test(meshOccluder) { traits.insert(.meshOccluder) }
            if mask.test(meshFade) { traits.insert(.meshFade) }
            if mask.test(tileRepresentationFade) { traits.insert(.tileRepresentationFade) }
            if mask.test(lod) { traits.insert(.lod) }
            if mask.test(deformation) { traits.insert(.deformation) }
            if mask.test(skeleton) { traits.insert(.skeleton) }
            if mask.test(tileLODTag) { traits.insert(.tileLODTag) }
            return traits
        }
    }

    /// The storage of the components the passes read. A pool is nil until the first
    /// component of its type is assigned.
    private struct ComponentPools {
        let render: ComponentPool?
        let world: ComponentPool?
        let local: ComponentPool?
        let sceneChannels: ComponentPool?
        let lod: ComponentPool?
        let meshOccluder: ComponentPool?
        let meshFade: ComponentPool?
        let tileRepresentationFade: ComponentPool?
        let deformation: ComponentPool?
        let tileLODTag: ComponentPool?

        init(ids: ComponentIds, scene: Scene) {
            render = scene.componentPool[ids.render]
            world = scene.componentPool[ids.world]
            local = scene.componentPool[ids.local]
            sceneChannels = scene.componentPool[ids.sceneChannels]
            lod = scene.componentPool[ids.lod]
            meshOccluder = scene.componentPool[ids.meshOccluder]
            meshFade = scene.componentPool[ids.meshFade]
            tileRepresentationFade = scene.componentPool[ids.tileRepresentationFade]
            deformation = scene.componentPool[ids.deformation]
            tileLODTag = scene.componentPool[ids.tileLODTag]
        }
    }
}

/// The render mode of the scene channels of one entity after another.
///
/// The entities of a scene are on a handful of channel sets, and neighbours in a list
/// are usually on the same one, so the mode is asked for again only when the channels
/// differ from those of the entity before.
struct SceneChannelRenderModeMemo {
    private var channels: SceneChannel?
    private var mode = SceneChannelRenderMode.normal

    @inline(__always)
    mutating func mode(of entityChannels: SceneChannel) -> SceneChannelRenderMode {
        if entityChannels != channels {
            channels = entityChannels
            mode = getSceneChannelRenderMode(entityChannels)
        }
        return mode
    }
}
