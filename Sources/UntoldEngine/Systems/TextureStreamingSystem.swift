//
//  TextureStreamingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import MetalKit
import MetalPerformanceShaders
@preconcurrency import ModelIO
import simd

/// Streams texture quality levels based on camera distance.
///
/// Behavior is mip-first:
/// - Initial asset import uses capped textures.
/// - Near entities stream toward full resolution.
/// - Mid/far entities stream toward smaller max dimensions.
///
/// Heavy work (I/O + GPU resampling) runs asynchronously.
/// ECS mutations are applied inside `withWorldMutationGate`.
///
/// Threading: `update()` and all configuration mutations must be called
/// from the same thread (typically the game loop / main thread).
public class TextureStreamingSystem: @unchecked Sendable {
    public static let shared = TextureStreamingSystem()

    private static let platformDefaultMaxTextureDimension: Int = {
        #if os(visionOS)
            768
        #else
            1024
        #endif
    }()

    private static let platformDefaultMinimumTextureDimension: Int = {
        #if os(visionOS)
            192
        #else
            256
        #endif
    }()

    // MARK: - Configuration

    // MARK: - Profiles

    /// Built-in tuning presets for common scene types.
    ///
    /// Apply at setup time via `TextureStreamingSystem.shared.apply(.detailed)`.
    /// Individual properties can be overridden after applying a profile.
    public enum Profile {
        /// Detail-focused close inspection scenes and hero assets.
        ///
        /// Prioritises quality over memory: full res within arm's reach, high
        /// minimum (512 px) because "distant" nearby objects are still large on
        /// screen, wide hysteresis to avoid close-view transitions, and more
        /// concurrent ops since ops are GPU-bound.
        ///
        /// Use for vehicles, products, characters, props, interiors, and other
        /// assets where close-range texture fidelity matters.
        case detailed

        /// Maximum-fidelity close inspection scenes and hero assets.
        ///
        /// Keeps full-resolution textures resident through a wider inspection band
        /// than `.detailed`, while still downgrading beyond typical presentation
        /// distance so large source textures do not stay full-res indefinitely.
        ///
        /// Use for showroom-style vehicles, product configurators, portfolio assets,
        /// and other scenes where the subject remains visually important at a few
        /// metres away.
        case superdetailed

        /// Deprecated alias for `.detailed`.
        @available(*, deprecated, renamed: "detailed", message: "Use .detailed for close-inspection/high-fidelity texture streaming.")
        case archviz

        /// Large outdoor / open-world scenes (cities, landscapes, terrain).
        ///
        /// Spreads three tiers across a much wider distance range so that
        /// GPU memory stays bounded while the camera traverses hundreds of
        /// metres. Minimum stays at 256 px — distant objects are tiny.
        case openWorld

        /// Balanced default for mid-size interior or mixed scenes.
        ///
        /// Suitable as a starting point when the scene type is unknown.
        case balanced

        /// Tile-based streaming scene (setEntityStreamScene manifest).
        ///
        /// Aligns the three texture tiers with typical tile streaming distance bands:
        ///   • < 30 m  → full resolution  (tile is likely fully parsed and visible)
        ///   • 30–70 m → medium (1024 px) (tile may be loading or in prefetch radius)
        ///   • > 70 m  → minimum (256 px) (tile is unloaded or in far prefetch band)
        ///
        /// Higher concurrency (6) and a tighter update interval (0.1 s) drain the
        /// post-load texture backlog faster when many tile entities become visible
        /// simultaneously during scene hydration.
        case tiled
    }

    /// Apply a built-in tuning profile, overwriting all streaming parameters.
    ///
    /// ```swift
    /// // At scene init:
    /// TextureStreamingSystem.shared.apply(.detailed)
    ///
    /// // Fine-tune a single value afterwards if needed:
    /// TextureStreamingSystem.shared.upgradeRadius = 3.0
    /// ```
    public func apply(_ profile: Profile) {
        switch profile {
        case .detailed, .archviz:
            // Full res within inspection distance; for detailed assets and rooms,
            // even the fallback tiers remain relatively high resolution.
            upgradeRadius = 2.5
            downgradeRadius = 6.0
            maxTextureDimension = 1024
            minimumTextureDimension = 512 // 256 px looks muddy on a wall at 5 m
            hysteresisFraction = 0.20 // wider dead band — no transitions mid-walkthrough
            maxConcurrentOps = 6 // GPU-bound; no disk I/O on warm path
            updateInterval = 0.1 // more responsive at walking speed

        case .superdetailed:
            // Hero assets stay full-res through normal presentation distance,
            // then degrade to a high medium tier before reaching the minimum tier.
            upgradeRadius = 4.0
            downgradeRadius = 8.0
            maxTextureDimension = 2048
            minimumTextureDimension = 1024
            hysteresisFraction = 0.20
            maxConcurrentOps = 6
            updateInterval = 0.1

        case .openWorld:
            // Spread tiers across a city-block / landscape scale.
            upgradeRadius = 15.0
            downgradeRadius = 60.0
            maxTextureDimension = 1024
            minimumTextureDimension = 256 // distant objects are tiny on screen
            hysteresisFraction = 0.15
            maxConcurrentOps = 3
            updateInterval = 0.2

        case .balanced:
            upgradeRadius = 12.0
            downgradeRadius = 20.0
            maxTextureDimension = TextureStreamingSystem.platformDefaultMaxTextureDimension
            minimumTextureDimension = TextureStreamingSystem.platformDefaultMinimumTextureDimension
            hysteresisFraction = 0.15
            maxConcurrentOps = 3
            updateInterval = 0.2

        case .tiled:
            // Radii are placeholder defaults. setEntityStreamScene() overrides them via
            // alignToManifest(streamingRadius:unloadRadius:) once the manifest is decoded.
            upgradeRadius = 30.0
            downgradeRadius = 70.0
            maxTextureDimension = 1024
            minimumTextureDimension = 256
            hysteresisFraction = 0.15
            maxConcurrentOps = 6 // drain post-load backlog faster
            updateInterval = 0.1 // tighter tick at tile-streaming cadence
        }
    }

    /// Derives texture streaming distance tiers from the manifest's streaming radii so
    /// that texture quality bands align with tile load/unload boundaries regardless of
    /// scene scale.
    ///
    /// Called automatically by `setEntityStreamScene()` after the manifest is decoded.
    /// Applies the `.tiled` concurrency and interval settings then overrides the radii:
    ///
    ///   upgradeRadius   = max(streamingRadius × 0.70, 2.5 m)
    ///   downgradeRadius = max(unloadRadius, upgradeRadius + 1.0, upgradeRadius × 2.0)
    ///
    /// The 2.5 m floor on upgradeRadius prevents impractically small upgrade zones for
    /// small scenes (props, helmets) where tile streaming_radius can be < 1 m. Without
    /// the floor the camera would have to be within centimetres of the object to see
    /// full-resolution textures. For large scenes the computed value dominates.
    ///
    /// The `upgradeRadius × 2.0` floor on downgradeRadius ensures the medium-quality
    /// band spans at least the upgrade radius, preventing a single-step full→minimum
    /// drop for small scenes. For large scenes `unloadRadius` dominates as before.
    ///
    /// Example — large scene (streaming=38.5 m, unload=57.8 m):
    ///   < 27 m  → full resolution
    ///   27–58 m → medium (tile loaded but at distance)
    ///   > 58 m  → minimum (tile likely unloaded)
    ///
    /// Example — small prop (streaming=0.35 m, unload=0.52 m):
    ///   <  2.1 m → full resolution
    ///   2.1–4.3 m → medium
    ///   >  5.8 m  → minimum
    public func alignToManifest(streamingRadius: Float, unloadRadius: Float) {
        apply(.tiled)
        // Floor upgrade radius so practical viewing distances always land in a useful tier.
        upgradeRadius = max(streamingRadius * 0.70, 2.5)
        // Floor downgrade radius so the medium-quality band is at least as wide as the
        // upgrade radius. For large scenes unloadRadius dominates and behaviour is unchanged.
        downgradeRadius = max(unloadRadius, upgradeRadius + 1.0, upgradeRadius * 2.0)
    }

    // MARK: - Configuration

    /// Enable/disable texture streaming
    public var enabled: Bool = true

    /// Textures closer than this distance stream to full resolution.
    public var upgradeRadius: Float = 12.0

    /// Textures between `upgradeRadius` and `downgradeRadius` stream to `maxTextureDimension`.
    /// Textures beyond `downgradeRadius` stream to `minimumTextureDimension`.
    public var downgradeRadius: Float = 20.0

    /// Mid-distance max dimension.
    public var maxTextureDimension: Int = TextureStreamingSystem.platformDefaultMaxTextureDimension

    /// Far-distance max dimension.
    public var minimumTextureDimension: Int = TextureStreamingSystem.platformDefaultMinimumTextureDimension

    /// How often to evaluate texture streaming (seconds)
    public var updateInterval: Float = 0.2

    /// Print resolution-change events to the console.
    public var verboseLogging: Bool = false

    /// Maximum concurrent texture streaming operations.
    public var maxConcurrentOps: Int = 3

    /// Hysteresis fraction applied to each tier boundary to prevent oscillation.
    ///
    /// An entity must move `hysteresisFraction × radius` *past* a tier boundary before a
    /// direction change is issued. This creates an asymmetric dead band:
    /// - Upgrade: requires distance < boundary × (1 - hysteresisFraction)
    /// - Downgrade: requires distance > boundary × (1 + hysteresisFraction)
    ///
    /// At the default of 0.15, an entity at the `downgradeRadius = 20 m` boundary must
    /// reach 17 m before upgrading and 23 m before downgrading. This eliminates per-tick
    /// oscillation for entities hovering near a tier boundary.
    public var hysteresisFraction: Float = 0.15

    // MARK: - State

    private var timeSinceLastUpdate: Float = 0
    private var memoryPressureHoldSeconds: Float = 0

    /// Entities that currently hold textures above `minimumTextureDimension`.
    private var upgradedEntities: Set<EntityID> = []
    private var activeOps: Set<EntityID> = []

    /// Priority-0 burst queue: entities inserted here by `notifyEntitiesReady`
    /// are processed before the regular visible-entity pass so freshly loaded
    /// tile geometry gets its first texture upgrade without waiting behind the
    /// entire visible-entity list.
    private var priorityEntities: Set<EntityID> = []

    private let lock = NSLock()

    /// Reusable command queue for GPU resampling. Initialized once in `configure(device:)`.
    private var commandQueue: MTLCommandQueue?

    /// Reusable texture loader. Initialized once in `configure(device:)`.
    private var textureLoader: MTKTextureLoader?

    /// Reusable native loader for ASTC .utex textures. Initialized once in `configure(device:)`.
    private var nativeTextureLoader: NativeTextureLoader?

    // MARK: - Stats

    private var totalUpgrades: Int = 0
    private var totalDowngrades: Int = 0

    private init() {
        // When an entity's LOD switches, its render.mesh is swapped to a different
        // LOD level's mesh array. Any previously streamed textures live in the old
        // mesh and are now unreachable. Remove the entity from upgradedEntities so
        // the next update() tick re-evaluates and re-streams the new LOD's meshes.
        SystemEventBus.shared.subscribeToLODChanges { [weak self] event in
            self?.handleLODChange(event)
        }
    }

    /// Initialize Metal resources. Must be called once from the engine's `initResources()`
    /// before the first `update()` tick. Eagerly allocating here eliminates the lazy-init
    /// race that existed when multiple concurrent schedule calls could each observe nil and
    /// race to assign the shared instance variables.
    func configure(device: MTLDevice) {
        guard commandQueue == nil else { return }
        commandQueue = device.makeCommandQueue()
        textureLoader = MTKTextureLoader(device: device)
        nativeTextureLoader = NativeTextureLoader(device: device)
        if commandQueue == nil {
            handleError(.textureStreamingCommandQueueFailed)
        }
    }

    private func handleLODChange(_ event: EntityLODChangedEvent) {
        lock.lock()
        upgradedEntities.remove(event.entityId)
        lock.unlock()
    }

    // MARK: - Resolution Model

    private enum TextureSource: @unchecked Sendable {
        case mdl(MDLTexture)
        case url(URL)
        /// Engine-native ASTC container.  Streamed by selecting the appropriate starting
        /// mip level rather than MPS resampling (which cannot operate on compressed blocks).
        case utex(URL)
    }

    private enum StreamDirection {
        case upgrade
        case downgrade
    }

    private struct StreamSlot: @unchecked Sendable {
        let meshIndex: Int
        let submeshIndex: Int
        let textureType: TextureType
        let currentTexture: MTLTexture
        let isSRGB: Bool
        let source: TextureSource
        let sourceMaxDimension: Int
    }

    private struct StreamWorkItem: @unchecked Sendable {
        let slot: StreamSlot
        let direction: StreamDirection
        /// `nil` means full source resolution.
        let targetMaxDimension: Int?
    }

    private struct LoadedTexture: @unchecked Sendable {
        let meshIndex: Int
        let submeshIndex: Int
        let textureType: TextureType
        let texture: MTLTexture
        let direction: StreamDirection
        let targetMaxDimension: Int?
    }

    // MARK: - Active Operation Tracking

    private func reserveOp(_ entityId: EntityID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeOps.contains(entityId) { return false }
        activeOps.insert(entityId)
        return true
    }

    private func releaseOp(_ entityId: EntityID) {
        lock.lock()
        activeOps.remove(entityId)
        lock.unlock()
    }

    private func setTrackedAboveMinimum(_ entityId: EntityID, isAboveMinimum: Bool) {
        lock.lock()
        if isAboveMinimum {
            upgradedEntities.insert(entityId)
        } else {
            upgradedEntities.remove(entityId)
        }
        lock.unlock()
    }

    private func activeOpCount() -> Int {
        lock.lock()
        let count = activeOps.count
        lock.unlock()
        return count
    }

    private func isActiveOp(_ entityId: EntityID) -> Bool {
        lock.lock()
        let active = activeOps.contains(entityId)
        lock.unlock()
        return active
    }

    // MARK: - Update

    public func update(cameraPosition: simd_float3, deltaTime: Float) {
        guard enabled else { return }

        memoryPressureHoldSeconds = max(0, memoryPressureHoldSeconds - deltaTime)
        timeSinceLastUpdate += deltaTime
        guard timeSinceLastUpdate >= updateInterval else { return }
        timeSinceLastUpdate = 0

        let availableSlots = maxConcurrentOps - activeOpCount()
        guard availableSlots > 0 else { return }

        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraPosition)
        let visible = visibleEntityIds
        let visibleSet = Set(visible)
        var opsScheduled = 0

        // Priority 0: burst queue — entities notified via notifyEntitiesReady().
        // Freshly loaded tile geometry is inserted here at load-completion time so
        // it gets its first texture upgrade before the regular visible-entity pass,
        // preventing newly loaded tiles from sitting at minimum texture while distant
        // entities from older tiles consume all concurrent op slots.
        lock.lock()
        let burstSnapshot = priorityEntities
        priorityEntities.removeAll(keepingCapacity: true)
        lock.unlock()

        for entityId in burstSnapshot {
            guard opsScheduled < availableSlots else { break }
            guard scene.exists(entityId) else { continue }
            guard !isActiveOp(entityId) else { continue }
            guard scene.get(component: TileLODTagComponent.self, for: entityId) == nil else { continue }
            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            guard distance.isFinite else { continue }
            setTrackedAboveMinimum(entityId, isAboveMinimum: entityHasTexturesAboveMinimumTier(entityId: entityId))
            let targetMaxDimension = lodAwareMaxDimension(entityId: entityId, distanceBased: desiredMaxDimension(distance: distance, allowFullResolution: memoryPressureHoldSeconds <= 0))
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension, distance: distance)
            guard !workItems.isEmpty else { continue }
            let capturedLOD = scene.get(component: LODComponent.self, for: entityId)?.currentLOD
            scheduleResolutionChange(entityId: entityId, distance: distance, workItems: workItems, targetMaxDimension: targetMaxDimension, isVisible: visibleSet.contains(entityId), capturedLOD: capturedLOD)
            opsScheduled += 1
        }
        // Entities from burstSnapshot that didn't fit this tick are dropped back to
        // normal P1 priority — they'll be processed on the next update() tick via
        // the regular visibleEntityIds pass.

        // Priority 1: visible entities first. Apply tier target by distance.
        for entityId in visible {
            guard opsScheduled < availableSlots else { break }
            guard scene.exists(entityId) else { continue }
            guard !isActiveOp(entityId) else { continue }
            // HLOD and per-tile LOD entities are coarse proxy meshes (TileLODTagComponent).
            // Streaming full-res textures onto transient proxy geometry wastes GPU budget
            // and texture budget headroom — skip them entirely.
            guard scene.get(component: TileLODTagComponent.self, for: entityId) == nil else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            guard distance.isFinite else { continue }

            // Keep non-visible downgrade tracking current for entities we visit.
            setTrackedAboveMinimum(entityId, isAboveMinimum: entityHasTexturesAboveMinimumTier(entityId: entityId))

            let targetMaxDimension = lodAwareMaxDimension(entityId: entityId, distanceBased: desiredMaxDimension(distance: distance, allowFullResolution: memoryPressureHoldSeconds <= 0))
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension, distance: distance)
            guard !workItems.isEmpty else { continue }

            let capturedLOD = scene.get(component: LODComponent.self, for: entityId)?.currentLOD
            scheduleResolutionChange(entityId: entityId, distance: distance, workItems: workItems, targetMaxDimension: targetMaxDimension, isVisible: true, capturedLOD: capturedLOD)
            opsScheduled += 1
        }

        // Priority 2: entities no longer visible should settle to the appropriate tier
        // based on their actual distance. Do NOT assume minimum — a nearby entity that
        // left the frustum (e.g. camera rotation) should keep its high-res texture so
        // there is no quality drop when the camera rotates back.
        lock.lock()
        let upgradedSnapshot = Array(upgradedEntities)
        lock.unlock()

        for entityId in upgradedSnapshot {
            guard opsScheduled < availableSlots else { break }
            guard !visibleSet.contains(entityId) else { continue }
            guard !isActiveOp(entityId) else { continue }

            guard scene.exists(entityId) else {
                lock.lock()
                upgradedEntities.remove(entityId)
                lock.unlock()
                continue
            }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            let targetMaxDimension = lodAwareMaxDimension(entityId: entityId, distanceBased: desiredMaxDimension(distance: distance, allowFullResolution: memoryPressureHoldSeconds <= 0))
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension, distance: distance)
            guard !workItems.isEmpty else {
                lock.lock()
                upgradedEntities.remove(entityId)
                lock.unlock()
                continue
            }

            let capturedLOD = scene.get(component: LODComponent.self, for: entityId)?.currentLOD
            scheduleResolutionChange(entityId: entityId, distance: distance, workItems: workItems, targetMaxDimension: targetMaxDimension, isVisible: false, capturedLOD: capturedLOD)
            opsScheduled += 1
        }
    }

    // MARK: - Resolution Decisions

    private func normalizedMediumDimension() -> Int {
        max(1, maxTextureDimension)
    }

    private func normalizedMinimumDimension() -> Int {
        min(max(1, minimumTextureDimension), normalizedMediumDimension())
    }

    /// Returns desired max dimension for the entity at this distance.
    /// `nil` means full source resolution.
    ///
    /// Tier is determined by distance alone. Visibility is not a factor here —
    /// an entity behind the camera may still be very close, and downgrading it
    /// to minimum just because it left the frustum causes a visible quality drop
    /// when the camera rotates back.
    private func desiredMaxDimension(distance: Float, allowFullResolution: Bool = true) -> Int? {
        if distance <= upgradeRadius {
            return allowFullResolution ? nil : normalizedMediumDimension()
        }
        if distance <= downgradeRadius {
            return normalizedMediumDimension()
        }
        return normalizedMinimumDimension()
    }

    /// Returns the LOD-aware desired max dimension for an entity.
    ///
    /// For LOD-enabled entities, caps texture quality based on the active LOD index
    /// so the system never streams full-res textures onto low-poly geometry:
    /// - LOD 0 (highest detail): quality driven by distance
    /// - LOD 1 … n-2 (intermediate): cap at `maxTextureDimension`
    /// - LOD n-1 (lowest detail): cap at `minimumTextureDimension`
    private func lodAwareMaxDimension(entityId: EntityID, distanceBased: Int?) -> Int? {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId),
              lodComponent.lodLevels.count > 1
        else { return distanceBased }

        let activeLOD = lodComponent.currentLOD
        guard activeLOD > 0 else { return distanceBased }

        let isLowestDetail = activeLOD == lodComponent.lodLevels.count - 1
        let lodCap = isLowestDetail ? normalizedMinimumDimension() : normalizedMediumDimension()

        if let distDim = distanceBased {
            return min(distDim, lodCap)
        }
        return lodCap
    }

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let transform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return .infinity }

        return TextureStreamingSystem.distanceToWorldAABB(
            cameraPosition: cameraPosition,
            worldTransform: transform.space,
            localMin: local.boundingBox.min,
            localMax: local.boundingBox.max
        )
    }

    /// Distance from the camera to the nearest point on an entity's local-space AABB,
    /// measured in scene/world units.
    ///
    /// Texture quality is screen-distance driven: a viewer standing next to the surface
    /// of a large mesh should get the near tier even if the mesh center is many metres
    /// away. This mirrors geometry streaming's closest-AABB behavior while preserving
    /// world-space distance so scaled props still use intuitive metre-based radii.
    static func distanceToWorldAABB(
        cameraPosition: simd_float3,
        worldTransform: simd_float4x4,
        localMin: simd_float3,
        localMax: simd_float3
    ) -> Float {
        let inv = worldTransform.inverse
        let localCamera4 = inv * simd_float4(cameraPosition, 1.0)
        let localCamera = simd_float3(localCamera4.x, localCamera4.y, localCamera4.z)
        guard localCamera.x.isFinite, localCamera.y.isFinite, localCamera.z.isFinite else {
            return .infinity
        }

        let minBounds = simd_min(localMin, localMax)
        let maxBounds = simd_max(localMin, localMax)
        let closestLocal = simd_clamp(localCamera, minBounds, maxBounds)
        let closestWorld4 = worldTransform * simd_float4(closestLocal, 1.0)
        let closestWorld = simd_float3(closestWorld4.x, closestWorld4.y, closestWorld4.z)
        return simd_distance(cameraPosition, closestWorld)
    }

    private func streamableSlots(entityId: EntityID) -> [StreamSlot] {
        guard let render = scene.get(component: RenderComponent.self, for: entityId) else { return [] }

        var slots: [StreamSlot] = []
        for meshIndex in render.mesh.indices {
            for submeshIndex in render.mesh[meshIndex].submeshes.indices {
                guard let material = render.mesh[meshIndex].submeshes[submeshIndex].material else { continue }

                func urlSource(_ url: URL?) -> TextureSource? {
                    guard let url else { return nil }
                    return url.pathExtension.lowercased() == "utex" ? .utex(url) : .url(url)
                }

                let descriptors: [(TextureType, MTLTexture?, TextureSource?, simd_int2?, Bool)] = [
                    (
                        .baseColor,
                        material.baseColor.texture,
                        material.baseColorMDLTexture.map { TextureSource.mdl($0) } ?? urlSource(material.baseColorURL),
                        material.baseColorSourceDimensions,
                        true
                    ),
                    (
                        .roughness,
                        material.roughness.texture,
                        material.roughnessMDLTexture.map { TextureSource.mdl($0) } ?? urlSource(material.roughnessURL),
                        material.roughnessSourceDimensions,
                        false
                    ),
                    (
                        .metallic,
                        material.metallic.texture,
                        material.metallicMDLTexture.map { TextureSource.mdl($0) } ?? urlSource(material.metallicURL),
                        material.metallicSourceDimensions,
                        false
                    ),
                    (
                        .normal,
                        material.normal.texture,
                        material.normalMDLTexture.map { TextureSource.mdl($0) } ?? urlSource(material.normalURL),
                        material.normalSourceDimensions,
                        false
                    ),
                    (
                        .height,
                        material.height.texture,
                        material.heightMDLTexture.map { TextureSource.mdl($0) } ?? urlSource(material.heightURL),
                        material.heightSourceDimensions,
                        false
                    ),
                ]

                for descriptor in descriptors {
                    guard let currentTexture = descriptor.1,
                          let source = descriptor.2
                    else { continue }

                    let sourceMaxDimension: Int
                    if let dims = descriptor.3 {
                        sourceMaxDimension = max(Int(dims.x), Int(dims.y))
                    } else {
                        sourceMaxDimension = max(currentTexture.width, currentTexture.height)
                    }

                    guard sourceMaxDimension > 0 else { continue }
                    slots.append(StreamSlot(
                        meshIndex: meshIndex,
                        submeshIndex: submeshIndex,
                        textureType: descriptor.0,
                        currentTexture: currentTexture,
                        isSRGB: descriptor.4,
                        source: source,
                        sourceMaxDimension: sourceMaxDimension
                    ))
                }
            }
        }

        return slots
    }

    private func buildWorkItems(entityId: EntityID, targetMaxDimension: Int?, distance: Float) -> [StreamWorkItem] {
        let slots = streamableSlots(entityId: entityId)
        guard !slots.isEmpty else { return [] }

        var workItems: [StreamWorkItem] = []
        workItems.reserveCapacity(slots.count)

        let h = hysteresisFraction
        let medium = normalizedMediumDimension()

        for slot in slots {
            let currentMax = max(slot.currentTexture.width, slot.currentTexture.height)
            let desiredMax = min(targetMaxDimension ?? slot.sourceMaxDimension, slot.sourceMaxDimension)

            if currentMax == desiredMax {
                continue
            }

            let direction: StreamDirection = desiredMax > currentMax ? .upgrade : .downgrade
            if direction == .upgrade, slot.sourceMaxDimension <= currentMax {
                continue
            }

            // Hysteresis dead band: suppress tier crossings when the entity is within
            // `h × radius` of a tier boundary. This prevents per-tick oscillation for
            // entities hovering near upgradeRadius or downgradeRadius.
            //
            // Upgrade is suppressed if the entity hasn't moved sufficiently inside the
            // higher-resolution zone yet (distance still too large relative to boundary).
            // Downgrade is suppressed if the entity hasn't moved sufficiently outside the
            // higher-resolution zone yet (distance still too small relative to boundary).
            //
            // Memory-pressure callers pass Float.greatestFiniteMagnitude so that the
            // downgrade suppress conditions (`distance < threshold`) are never true,
            // effectively bypassing hysteresis for forced evictions.
            let suppress: Bool
            switch direction {
            case .upgrade:
                if desiredMax >= slot.sourceMaxDimension {
                    // Upgrading toward full resolution: boundary is at upgradeRadius.
                    suppress = distance > upgradeRadius * (1.0 - h)
                } else {
                    // Upgrading toward medium resolution: boundary is at downgradeRadius.
                    suppress = distance > downgradeRadius * (1.0 - h)
                }
            case .downgrade:
                if currentMax > medium {
                    // Downgrading from full resolution: boundary is at upgradeRadius.
                    suppress = distance < upgradeRadius * (1.0 + h)
                } else {
                    // Downgrading from medium resolution: boundary is at downgradeRadius.
                    suppress = distance < downgradeRadius * (1.0 + h)
                }
            }
            if suppress { continue }

            let target: Int? = desiredMax >= slot.sourceMaxDimension ? nil : desiredMax
            workItems.append(StreamWorkItem(slot: slot, direction: direction, targetMaxDimension: target))
        }

        return workItems
    }

    private func entityHasTexturesAboveMinimumTier(entityId: EntityID) -> Bool {
        let minDim = normalizedMinimumDimension()
        let slots = streamableSlots(entityId: entityId)
        for slot in slots {
            let currentMax = max(slot.currentTexture.width, slot.currentTexture.height)
            if currentMax > minDim {
                return true
            }
        }
        return false
    }

    // MARK: - Budget Helpers

    /// Estimate the net GPU byte increase for a set of upgrade work items.
    ///
    /// Uses `dim × dim × 4 bytes/pixel × 4/3` (RGBA8 + mip overhead) as a
    /// conservative upper bound. The estimate intentionally over-counts slightly
    /// so the budget check errs on the side of caution.
    ///
    /// Only upgrade items contribute to the estimate — downgrades free memory
    /// and are always allowed regardless of budget state.
    private func estimatedUpgradeBytes(_ workItems: [StreamWorkItem]) -> Int {
        workItems.reduce(0) { total, item in
            guard item.direction == .upgrade else { return total }
            let newDim = item.targetMaxDimension ?? item.slot.sourceMaxDimension
            let oldDim = max(item.slot.currentTexture.width, item.slot.currentTexture.height)

            // Use format-aware bytes-per-pixel to avoid over-counting ASTC textures.
            // ASTC 4x4 encodes a 4×4 pixel block in 16 bytes ≈ 1 byte/pixel.
            // Larger block sizes (6x6, 8x8) are even smaller, so 1 byte/pixel is a
            // conservative upper bound for all ASTC variants.
            // RGBA8 textures use 4 bytes/pixel.
            // Both figures are multiplied by 4/3 to account for the full mip chain.
            let bytesPerPixel: Int
            if case .utex = item.slot.source {
                bytesPerPixel = 1 // ASTC: ≤ 1 byte/pixel for all block sizes
            } else {
                bytesPerPixel = 4 // RGBA8
            }
            let newBytes = newDim * newDim * bytesPerPixel * 4 / 3
            let oldBytes = oldDim * oldDim * bytesPerPixel * 4 / 3
            return total + max(0, newBytes - oldBytes)
        }
    }

    /// Sum the actual allocated GPU bytes for every texture on an entity's render component.
    ///
    /// Uses `MTLTexture.allocatedSize` — the exact bytes the driver reserved — so
    /// the value passed to `updateTextureSizeBytes` is accurate rather than estimated.
    private func currentTextureBytes(entityId: EntityID) -> Int {
        guard let render = scene.get(component: RenderComponent.self, for: entityId) else { return 0 }
        var total = 0
        for mesh in render.mesh {
            for submesh in mesh.submeshes {
                guard let mat = submesh.material else { continue }
                total += mat.baseColor.texture?.allocatedSize ?? 0
                total += mat.roughness.texture?.allocatedSize ?? 0
                total += mat.metallic.texture?.allocatedSize ?? 0
                total += mat.normal.texture?.allocatedSize ?? 0
                total += mat.height.texture?.allocatedSize ?? 0
            }
        }
        return total
    }

    // MARK: - Scheduling

    private func scheduleResolutionChange(
        entityId: EntityID,
        distance: Float,
        workItems: [StreamWorkItem],
        targetMaxDimension: Int?,
        isVisible: Bool,
        capturedLOD: Int? = nil
    ) {
        guard reserveOp(entityId) else { return }

        // Budget gate: upgrades consume GPU memory; downgrades free it.
        //
        // For upgrades, `reserveTexture` atomically checks the budget AND reserves the
        // estimated bytes in one lock acquisition. This eliminates the TOCTOU race where
        // multiple concurrent callers each see "budget available" and all proceed,
        // collectively overshooting the budget before any accounting catches up.
        //
        // If the reservation succeeds:  budgetedWorkItems = full workItems (upgrades + downgrades)
        // If the reservation fails:     budgetedWorkItems = downgrades only (upgrades stripped)
        // If upgradeBytes == 0:         no reservation needed; all items are downgrades
        //
        // The reservation MUST be released after the async Task completes (success, failure,
        // or cancellation). It is released via defer inside the Task's MainActor.run block
        // so all exit paths (entity destroyed, no changes, normal completion) are covered.
        let upgradeBytes = estimatedUpgradeBytes(workItems)
        let reservedUpgradeBytes: Int
        let budgetedWorkItems: [StreamWorkItem]
        if upgradeBytes > 0 {
            if MemoryBudgetManager.shared.reserveTexture(sizeBytes: upgradeBytes) {
                reservedUpgradeBytes = upgradeBytes
                budgetedWorkItems = workItems
            } else {
                reservedUpgradeBytes = 0
                budgetedWorkItems = workItems.filter { $0.direction == .downgrade }
                Logger.log(
                    message: "[TextureStreaming] entity=\(entityId) skipped \(workItems.filter { $0.direction == .upgrade }.count) upgrade(s) — budget full (need \(upgradeBytes.formattedAsMemory))",
                    category: LogCategory.textureStreaming.rawValue
                )
            }
        } else {
            reservedUpgradeBytes = 0
            budgetedWorkItems = workItems
        }

        guard !budgetedWorkItems.isEmpty else {
            releaseOp(entityId)
            // reservedUpgradeBytes == 0 here: if reservation was made, budgetedWorkItems
            // contains the full workItems and cannot be empty at this point.
            return
        }

        // Capture Metal resources as local constants so the Task closure never touches
        // the instance variables. These are guaranteed non-nil after configure(device:).
        guard let queue = commandQueue, let loader = textureLoader else {
            handleError(.textureStreamingNotConfigured)
            releaseOp(entityId)
            if reservedUpgradeBytes > 0 {
                MemoryBudgetManager.shared.releaseTextureReservation(sizeBytes: reservedUpgradeBytes)
            }
            return
        }
        let capturedNativeLoader = nativeTextureLoader

        // Capture minimum dimension before spawning the Task so the apply-side
        // level assignment uses the same threshold that was in effect at schedule time.
        let capturedMinimumDim = normalizedMinimumDimension()

        Task {
            var loaded: [LoadedTexture] = []
            loaded.reserveCapacity(budgetedWorkItems.count)

            for item in budgetedWorkItems {
                let texture: MTLTexture?

                // ASTC .utex textures: select the starting mip by dimension instead of
                // MPS resampling (compressed ASTC blocks cannot be resampled in-place).
                // Both upgrade and downgrade reload from the file at the target tier.
                if case let .utex(url) = item.slot.source {
                    texture = capturedNativeLoader?.loadTexture(
                        from: url,
                        targetMaxDimension: item.targetMaxDimension,
                        label: item.slot.currentTexture.label
                    )
                } else {
                    switch item.direction {
                    case .upgrade:
                        guard let sourceTexture = self.loadSourceTexture(item.slot.source, isSRGB: item.slot.isSRGB, loader: loader) else {
                            continue
                        }
                        texture = await self.resampleTextureIfNeeded(sourceTexture, targetMaxDimension: item.targetMaxDimension, commandQueue: queue)
                    case .downgrade:
                        texture = await self.resampleTextureIfNeeded(item.slot.currentTexture, targetMaxDimension: item.targetMaxDimension, commandQueue: queue)
                    }
                }

                guard let texture else { continue }
                // ASTC textures: skip the sRGB view step — the color space is baked
                // into the pixel format at encode time (ASTC_4X4_SRGB vs ASTC_4X4_LDR),
                // and ASTC formats cannot be reinterpreted via makeTextureView.
                //
                // Resampled textures (targetMaxDimension != nil) come back from
                // downsampleTexture already holding genuinely linear bytes in a linear
                // pixel format — do NOT force them through textureViewMatchingSRGB, or
                // the sRGB view re-tags already-linear data as sRGB and the material
                // shader's hardware sRGB decode double-applies on sample (visible color/
                // tint shift on every downgrade or partial upgrade of a base color texture).
                // Only a texture returned at full source resolution (no resample; loaded
                // directly by loadSourceTexture with the correct .SRGB option) needs this
                // reconciliation, and it's a no-op there since the format already matches.
                let texView: MTLTexture
                if case .utex = item.slot.source {
                    texView = texture
                } else if item.targetMaxDimension == nil {
                    texView = self.textureViewMatchingSRGB(texture, wantSRGB: item.slot.isSRGB)
                } else {
                    texView = texture
                }
                loaded.append(LoadedTexture(
                    meshIndex: item.slot.meshIndex,
                    submeshIndex: item.slot.submeshIndex,
                    textureType: item.slot.textureType,
                    texture: texView,
                    direction: item.direction,
                    targetMaxDimension: item.targetMaxDimension
                ))
            }

            await MainActor.run {
                withWorldMutationGate {
                    defer {
                        self.releaseOp(entityId)
                        if reservedUpgradeBytes > 0 {
                            MemoryBudgetManager.shared.releaseTextureReservation(sizeBytes: reservedUpgradeBytes)
                        }
                    }
                    guard scene.exists(entityId) else { return }

                    // If the entity switched LOD levels while this op was in-flight,
                    // the mesh indices in `loaded` now refer to a different LOD's mesh
                    // layout. Discard the apply — the next update() tick will reschedule
                    // against the new LOD's meshes with the correct indices.
                    if let scheduledLOD = capturedLOD,
                       let lodComp = scene.get(component: LODComponent.self, for: entityId),
                       lodComp.currentLOD != scheduledLOD
                    {
                        return
                    }

                    var didAnyChange = false
                    var didUpgrade = false
                    var didDowngrade = false

                    for item in loaded {
                        // Resolve the three-tier streaming level from the item's target
                        // dimension. Both .capped (medium) and .minimum use the same
                        // `.capped` value in the old two-case enum, which made
                        // reconcileStreamingTexturesAfterArtifact blind to medium→minimum
                        // downgrades that happened while a batch artifact was building.
                        let streamLevel: TextureStreamingLevel = {
                            guard let dim = item.targetMaxDimension else { return .full }
                            return dim <= capturedMinimumDim ? .minimum : .capped
                        }()

                        let applied = updateMaterial(entityId: entityId, meshIndex: item.meshIndex, submeshIndex: item.submeshIndex) { material in
                            switch item.textureType {
                            case .baseColor:
                                material.baseColor.texture = item.texture
                                material.baseColorStreamingLevel = streamLevel
                            case .roughness:
                                material.roughness.texture = item.texture
                                material.roughnessStreamingLevel = streamLevel
                            case .metallic:
                                material.metallic.texture = item.texture
                                material.metallicStreamingLevel = streamLevel
                            case .normal:
                                material.normal.texture = item.texture
                                material.normalStreamingLevel = streamLevel
                            case .height:
                                material.height.texture = item.texture
                                material.heightStreamingLevel = streamLevel
                            }
                        }

                        if applied {
                            didAnyChange = true
                            switch item.direction {
                            case .upgrade: didUpgrade = true
                            case .downgrade: didDowngrade = true
                            }
                        }
                    }

                    guard didAnyChange else { return }

                    // Update the batch group's representative material in-place so the
                    // new texture is visible on the next frame with zero batch churn.
                    BatchingSystem.shared.updateBatchMaterialInPlace(for: entityId) { batchMaterial in
                        for item in loaded {
                            let streamLevel: TextureStreamingLevel = {
                                guard let dim = item.targetMaxDimension else { return .full }
                                return dim <= capturedMinimumDim ? .minimum : .capped
                            }()
                            switch item.textureType {
                            case .baseColor:
                                batchMaterial.baseColor.texture = item.texture
                                batchMaterial.baseColorStreamingLevel = streamLevel
                            case .roughness:
                                batchMaterial.roughness.texture = item.texture
                                batchMaterial.roughnessStreamingLevel = streamLevel
                            case .metallic:
                                batchMaterial.metallic.texture = item.texture
                                batchMaterial.metallicStreamingLevel = streamLevel
                            case .normal:
                                batchMaterial.normal.texture = item.texture
                                batchMaterial.normalStreamingLevel = streamLevel
                            case .height:
                                batchMaterial.height.texture = item.texture
                                batchMaterial.heightStreamingLevel = streamLevel
                            }
                        }
                    }

                    // Update texture memory tracking so MemoryBudgetManager reflects
                    // the actual GPU allocation after this upgrade or downgrade.
                    // Only update if the entity has a budget entry (i.e. it was
                    // uploaded via GeometryStreamingSystem or the immediate path).
                    if MemoryBudgetManager.shared.isTracked(entityId: entityId) {
                        let newTextureBytes = self.currentTextureBytes(entityId: entityId)
                        MemoryBudgetManager.shared.updateTextureSizeBytes(
                            entityId: entityId,
                            newSizeBytes: newTextureBytes
                        )
                    }

                    let hasAboveMinimum = self.entityHasTexturesAboveMinimumTier(entityId: entityId)
                    self.lock.lock()
                    if hasAboveMinimum {
                        self.upgradedEntities.insert(entityId)
                    } else {
                        self.upgradedEntities.remove(entityId)
                    }
                    if didUpgrade { self.totalUpgrades += 1 }
                    if didDowngrade { self.totalDowngrades += 1 }
                    self.lock.unlock()

                    if self.verboseLogging {
                        let dir = didUpgrade ? "↑" : "↓"
                        let dim = targetMaxDimension.map { "\($0)px" } ?? "full"
                        let distStr = distance >= 0 ? String(format: "%.1f", distance) : "offscreen"
                        Logger.log(
                            message: "[TextureStreaming] entity=\(entityId) \(dir) → \(dim) dist=\(distStr) visible=\(isVisible)",
                            category: LogCategory.textureStreaming.rawValue
                        )
                    }
                }
            }
        }
    }

    // MARK: - Texture Load + Resample

    private func loadSourceTexture(_ source: TextureSource, isSRGB: Bool, loader: MTKTextureLoader) -> MTLTexture? {
        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: isSRGB,
            .generateMipmaps: true,
            .origin: MTKTextureLoader.Origin.topLeft,
        ]

        switch source {
        case let .mdl(mdlTexture):
            return try? loader.newTexture(texture: mdlTexture, options: options)
        case let .url(url):
            // Grayscale PNGs produce an r8Unorm Metal texture.  The shader samples
            // it as RGBA where G=B=0, making the mesh appear solid red.
            // Detect and expand to RGBA before handing to MTKTextureLoader.
            if let expanded = expandGrayscaleToRGBA(url: url, isSRGB: isSRGB, loader: loader, options: options) {
                return expanded
            }
            return try? loader.newTexture(URL: url, options: options)
        case .utex:
            // .utex slots are handled before reaching loadSourceTexture; this path
            // is unreachable in practice but required for exhaustiveness.
            return nil
        }
    }

    /// If `url` points to a grayscale image, redraws it into an RGBA CGContext and
    /// loads the result so Metal gets an rgba8Unorm texture instead of r8Unorm.
    /// Returns nil for non-grayscale images so the caller falls back to the normal path.
    private func expandGrayscaleToRGBA(
        url: URL,
        isSRGB: Bool,
        loader: MTKTextureLoader,
        options: [MTKTextureLoader.Option: Any]
    ) -> MTLTexture? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
              cgImage.colorSpace?.model == .monochrome
        else { return nil }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = isSRGB
            ? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            : CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let rgbaImage = ctx.makeImage() else { return nil }
        return try? loader.newTexture(cgImage: rgbaImage, options: options)
    }

    private func resampleTextureIfNeeded(_ texture: MTLTexture, targetMaxDimension: Int?, commandQueue: MTLCommandQueue) async -> MTLTexture? {
        guard let targetMaxDimension else { return texture }
        return await downsampleTexture(texture, maxDimension: targetMaxDimension, commandQueue: commandQueue)
    }

    /// Downsample a texture to fit within maxDimension, preserving aspect ratio.
    private func downsampleTexture(_ texture: MTLTexture, maxDimension: Int, commandQueue: MTLCommandQueue) async -> MTLTexture? {
        guard maxDimension > 0 else { return texture }
        guard texture.width > maxDimension || texture.height > maxDimension else { return texture }

        let aspect = Float(texture.width) / Float(texture.height)
        let targetWidth: Int
        let targetHeight: Int
        if texture.width >= texture.height {
            targetWidth = maxDimension
            targetHeight = max(1, Int(Float(maxDimension) / aspect))
        } else {
            targetHeight = maxDimension
            targetWidth = max(1, Int(Float(maxDimension) * aspect))
        }

        let mipCount = Int(log2(Float(max(targetWidth, targetHeight)))) + 1
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat.mpsWritableFormat,
            width: targetWidth,
            height: targetHeight,
            mipmapped: true
        )
        desc.mipmapLevelCount = mipCount
        desc.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        desc.storageMode = .private

        guard let target = renderInfo.device.makeTexture(descriptor: desc) else {
            if verboseLogging {
                Logger.log(
                    message: "[TextureStreaming] GPU resample failed: makeTexture returned nil (size: \(targetWidth)x\(targetHeight))",
                    category: LogCategory.textureStreaming.rawValue
                )
            }
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            if verboseLogging {
                Logger.log(
                    message: "[TextureStreaming] GPU resample failed: makeCommandBuffer returned nil",
                    category: LogCategory.textureStreaming.rawValue
                )
            }
            return nil
        }

        // MPS reads sRGB source textures through the texture unit, which auto-decodes
        // sRGB → linear before filtering, and writes raw (already-linear) bytes to the
        // destination. Metal also disallows a writable sRGB destination, so target was
        // allocated in the linear sibling format (mpsWritableFormat).
        //
        // target's bytes are therefore genuinely linear, not sRGB-encoded — do NOT view
        // it back as the source's sRGB format. Doing so previously caused the material
        // shader's hardware sRGB decode to run a second time on already-linear data,
        // visibly darkening/shifting base color textures every time they were resampled
        // (medium/minimum streaming tiers). Returning target in its natural linear
        // format is correct as-is.
        let scale = MPSImageBilinearScale(device: renderInfo.device)
        scale.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: target)

        if let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: target)
            blit.endEncoding()
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            commandBuffer.addCompletedHandler { _ in cont.resume() }
            commandBuffer.commit()
        }

        return target
    }

    // MARK: - sRGB Helper

    private func textureViewMatchingSRGB(_ tex: MTLTexture, wantSRGB: Bool) -> MTLTexture {
        let pairs: [MTLPixelFormat: (linear: MTLPixelFormat, srgb: MTLPixelFormat)] = [
            .rgba8Unorm: (.rgba8Unorm, .rgba8Unorm_srgb),
            .rgba8Unorm_srgb: (.rgba8Unorm, .rgba8Unorm_srgb),
            .bgra8Unorm: (.bgra8Unorm, .bgra8Unorm_srgb),
            .bgra8Unorm_srgb: (.bgra8Unorm, .bgra8Unorm_srgb),
        ]
        guard let pair = pairs[tex.pixelFormat] else { return tex }
        let target = wantSRGB ? pair.srgb : pair.linear
        if tex.pixelFormat == target { return tex }
        return tex.makeTextureView(pixelFormat: target) ?? tex
    }

    // MARK: - Memory Relief

    /// Force-downgrade textures on the farthest loaded entities to relieve combined GPU memory pressure.
    ///
    /// Called by `GeometryStreamingSystem` when combined mesh+texture memory is high but
    /// geometry-only memory is not. Texture downgrades are far less visually disruptive than
    /// geometry eviction — a distant wall losing resolution is much less noticeable than a
    /// missing mesh.
    ///
    /// - Parameters:
    ///   - cameraPosition: Current camera world position for distance sorting.
    ///   - maxEntities: Maximum number of entities to downgrade in this call. Defaults to 4.
    /// - Returns: Number of entities scheduled for downgrade.
    @discardableResult
    public func shedTextureMemory(cameraPosition: simd_float3, maxEntities: Int = 4) -> Int {
        memoryPressureHoldSeconds = 3.0
        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraPosition)

        lock.lock()
        let snapshot = Array(upgradedEntities)
        lock.unlock()

        guard !snapshot.isEmpty else { return 0 }

        // Sort farthest-first: distant entities are least valuable at their current resolution.
        let sorted = snapshot
            .compactMap { id -> (EntityID, Float)? in
                let d = calculateDistance(entityId: id, cameraPosition: effectiveCameraPosition)
                return d.isFinite ? (id, d) : nil
            }
            .sorted { $0.1 > $1.1 }

        var scheduled = 0

        for (entityId, distance) in sorted.prefix(maxEntities) {
            guard !isActiveOp(entityId) else { continue }
            let targetDimension = distance <= upgradeRadius
                ? normalizedMediumDimension()
                : normalizedMinimumDimension()
            // Pass Float.greatestFiniteMagnitude as distance so hysteresis dead-band checks
            // (`distance < threshold`) are never true — memory-pressure downgrades are unconditional.
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetDimension, distance: Float.greatestFiniteMagnitude)
            guard !workItems.isEmpty else { continue }
            scheduleResolutionChange(
                entityId: entityId,
                distance: distance,
                workItems: workItems,
                targetMaxDimension: targetDimension,
                isVisible: false
            )
            scheduled += 1
        }

        return scheduled
    }

    // MARK: - Stats / Debug

    /// Returns `true` while a streaming operation is in-flight for this entity.
    public func isStreaming(entityId: EntityID) -> Bool {
        isActiveOp(entityId)
    }

    public func getStats() -> TextureStreamingStats {
        lock.lock()
        let upgradedCount = upgradedEntities.count
        let activeCount = activeOps.count
        let upgrades = totalUpgrades
        let downgrades = totalDowngrades
        lock.unlock()
        return TextureStreamingStats(
            totalUpgrades: upgrades,
            totalDowngrades: downgrades,
            upgradedEntityCount: upgradedCount,
            activeOps: activeCount
        )
    }

    /// Enqueues `entityIds` into the Priority-0 burst queue so they are processed
    /// before the regular visible-entity pass on the next `update()` tick.
    ///
    /// Call this from tile/HLOD/LOD load completions alongside
    /// `BatchingSystem.shared.notifyTileEntitiesResident` so that freshly loaded
    /// tile geometry gets its first texture upgrade without waiting behind the
    /// entire visible-entity list.
    public func notifyEntitiesReady(_ entityIds: Set<EntityID>) {
        guard !entityIds.isEmpty else { return }
        lock.lock()
        priorityEntities.formUnion(entityIds)
        lock.unlock()
    }

    /// Bulk-cancels texture streaming for a set of entities that are about to be
    /// destroyed (tile unload, HLOD swap, per-tile LOD transition).
    ///
    /// - Removes all ids from `upgradedEntities` so the Priority 2 downgrade pass
    ///   stops iterating stale entries immediately (fixes lazy cleanup).
    /// - Removes all ids from `activeOps` so no new upgrade ops are scheduled for
    ///   entities that are mid-destroy.
    ///
    /// Any in-flight `Task` for a cancelled entity will complete its GPU work, then
    /// hit `guard scene.exists(entityId)` in the MainActor apply block, bail out,
    /// and release its MemoryBudgetManager reservation via `defer` — no permanent
    /// budget leak, just the expected short GPU-work latency.
    public func cancelEntities(_ entityIds: Set<EntityID>) {
        guard !entityIds.isEmpty else { return }
        lock.lock()
        upgradedEntities.subtract(entityIds)
        activeOps.subtract(entityIds)
        priorityEntities.subtract(entityIds)
        lock.unlock()
    }

    public func reset() {
        lock.lock()
        upgradedEntities.removeAll()
        activeOps.removeAll()
        priorityEntities.removeAll()
        totalUpgrades = 0
        totalDowngrades = 0
        lock.unlock()
        timeSinceLastUpdate = 0
        memoryPressureHoldSeconds = 0
    }
}

public struct TextureStreamingStats {
    public var totalUpgrades: Int
    public var totalDowngrades: Int
    public var upgradedEntityCount: Int
    public var activeOps: Int
}
