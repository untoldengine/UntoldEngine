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

    // MARK: - State

    private var timeSinceLastUpdate: Float = 0

    /// Entities that currently hold textures above `minimumTextureDimension`.
    private var upgradedEntities: Set<EntityID> = []
    private var activeOps: Set<EntityID> = []

    private let lock = NSLock()

    /// Reusable command queue for GPU resampling.
    /// Initialized once in `scheduleResolutionChange` before any Task is spawned.
    private var commandQueue: MTLCommandQueue?

    /// Reusable texture loader.
    /// Initialized once in `scheduleResolutionChange` before any Task is spawned.
    private var textureLoader: MTKTextureLoader?

    // MARK: - Stats

    private var totalUpgrades: Int = 0
    private var totalDowngrades: Int = 0

    private init() {}

    // MARK: - Resolution Model

    private enum TextureSource: @unchecked Sendable {
        case mdl(MDLTexture)
        case url(URL)
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

        timeSinceLastUpdate += deltaTime
        guard timeSinceLastUpdate >= updateInterval else { return }
        timeSinceLastUpdate = 0

        let availableSlots = maxConcurrentOps - activeOpCount()
        guard availableSlots > 0 else { return }

        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraPosition)
        let visible = visibleEntityIds
        let visibleSet = Set(visible)
        var opsScheduled = 0

        // Priority 1: visible entities first. Apply tier target by distance.
        for entityId in visible {
            guard opsScheduled < availableSlots else { break }
            guard !isActiveOp(entityId) else { continue }

            let distance = calculateDistance(entityId: entityId, cameraPosition: effectiveCameraPosition)
            guard distance.isFinite else { continue }

            // Keep non-visible downgrade tracking current for entities we visit.
            setTrackedAboveMinimum(entityId, isAboveMinimum: entityHasTexturesAboveMinimumTier(entityId: entityId))

            let targetMaxDimension = desiredMaxDimension(distance: distance)
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension)
            guard !workItems.isEmpty else { continue }

            scheduleResolutionChange(entityId: entityId, distance: distance, workItems: workItems, targetMaxDimension: targetMaxDimension, isVisible: true)
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
            let targetMaxDimension = desiredMaxDimension(distance: distance)
            let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension)
            guard !workItems.isEmpty else {
                lock.lock()
                upgradedEntities.remove(entityId)
                lock.unlock()
                continue
            }

            scheduleResolutionChange(entityId: entityId, distance: distance, workItems: workItems, targetMaxDimension: targetMaxDimension, isVisible: false)
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
    private func desiredMaxDimension(distance: Float) -> Int? {
        if distance <= upgradeRadius {
            return nil
        }
        if distance <= downgradeRadius {
            return normalizedMediumDimension()
        }
        return normalizedMinimumDimension()
    }

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let transform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let local = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return .infinity }

        let center = (local.boundingBox.min + local.boundingBox.max) * 0.5
        let worldCenter = transform.space * simd_float4(center, 1.0)
        return simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
    }

    private func streamableSlots(entityId: EntityID) -> [StreamSlot] {
        guard let render = scene.get(component: RenderComponent.self, for: entityId) else { return [] }

        var slots: [StreamSlot] = []
        for meshIndex in render.mesh.indices {
            for submeshIndex in render.mesh[meshIndex].submeshes.indices {
                guard let material = render.mesh[meshIndex].submeshes[submeshIndex].material else { continue }

                let descriptors: [(TextureType, MTLTexture?, TextureSource?, simd_int2?, Bool)] = [
                    (
                        .baseColor,
                        material.baseColor.texture,
                        material.baseColorMDLTexture.map { TextureSource.mdl($0) } ?? material.baseColorURL.map { TextureSource.url($0) },
                        material.baseColorSourceDimensions,
                        true
                    ),
                    (
                        .roughness,
                        material.roughness.texture,
                        material.roughnessMDLTexture.map { TextureSource.mdl($0) } ?? material.roughnessURL.map { TextureSource.url($0) },
                        material.roughnessSourceDimensions,
                        false
                    ),
                    (
                        .metallic,
                        material.metallic.texture,
                        material.metallicMDLTexture.map { TextureSource.mdl($0) } ?? material.metallicURL.map { TextureSource.url($0) },
                        material.metallicSourceDimensions,
                        false
                    ),
                    (
                        .normal,
                        material.normal.texture,
                        material.normalMDLTexture.map { TextureSource.mdl($0) } ?? material.normalURL.map { TextureSource.url($0) },
                        material.normalSourceDimensions,
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

    private func buildWorkItems(entityId: EntityID, targetMaxDimension: Int?) -> [StreamWorkItem] {
        let slots = streamableSlots(entityId: entityId)
        guard !slots.isEmpty else { return [] }

        var workItems: [StreamWorkItem] = []
        workItems.reserveCapacity(slots.count)

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

    // MARK: - Scheduling

    private func scheduleResolutionChange(
        entityId: EntityID,
        distance: Float,
        workItems: [StreamWorkItem],
        targetMaxDimension: Int?,
        isVisible: Bool
    ) {
        guard reserveOp(entityId) else { return }

        guard let device = renderInfo.device else {
            releaseOp(entityId)
            return
        }

        // Initialize reusable resources once on the calling thread before spawning the Task,
        // then capture them as local constants so the Task never touches instance state.
        if commandQueue == nil { commandQueue = device.makeCommandQueue() }
        if textureLoader == nil { textureLoader = MTKTextureLoader(device: device) }

        guard let queue = commandQueue, let loader = textureLoader else {
            releaseOp(entityId)
            return
        }

        Task {
            var loaded: [LoadedTexture] = []
            loaded.reserveCapacity(workItems.count)

            for item in workItems {
                let texture: MTLTexture?
                switch item.direction {
                case .upgrade:
                    guard let sourceTexture = self.loadSourceTexture(item.slot.source, isSRGB: item.slot.isSRGB, loader: loader) else {
                        continue
                    }
                    texture = await self.resampleTextureIfNeeded(sourceTexture, targetMaxDimension: item.targetMaxDimension, commandQueue: queue)
                case .downgrade:
                    texture = await self.resampleTextureIfNeeded(item.slot.currentTexture, targetMaxDimension: item.targetMaxDimension, commandQueue: queue)
                }

                guard let texture else { continue }
                let texView = self.textureViewMatchingSRGB(texture, wantSRGB: item.slot.isSRGB)
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
                    defer { self.releaseOp(entityId) }
                    guard scene.exists(entityId) else { return }

                    var didAnyChange = false
                    var didUpgrade = false
                    var didDowngrade = false

                    for item in loaded {
                        let applied = updateMaterial(entityId: entityId, meshIndex: item.meshIndex, submeshIndex: item.submeshIndex) { material in
                            let isFull = item.targetMaxDimension == nil
                            switch item.textureType {
                            case .baseColor:
                                material.baseColor.texture = item.texture
                                material.baseColorStreamingLevel = isFull ? .full : .capped
                            case .roughness:
                                material.roughness.texture = item.texture
                                material.roughnessStreamingLevel = isFull ? .full : .capped
                            case .metallic:
                                material.metallic.texture = item.texture
                                material.metallicStreamingLevel = isFull ? .full : .capped
                            case .normal:
                                material.normal.texture = item.texture
                                material.normalStreamingLevel = isFull ? .full : .capped
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
                            let isFull = item.targetMaxDimension == nil
                            switch item.textureType {
                            case .baseColor:
                                batchMaterial.baseColor.texture = item.texture
                                batchMaterial.baseColorStreamingLevel = isFull ? .full : .capped
                            case .roughness:
                                batchMaterial.roughness.texture = item.texture
                                batchMaterial.roughnessStreamingLevel = isFull ? .full : .capped
                            case .metallic:
                                batchMaterial.metallic.texture = item.texture
                                batchMaterial.metallicStreamingLevel = isFull ? .full : .capped
                            case .normal:
                                batchMaterial.normal.texture = item.texture
                                batchMaterial.normalStreamingLevel = isFull ? .full : .capped
                            }
                        }
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
                        print("[TextureStreaming] entity=\(entityId) \(dir) → \(dim) dist=\(distStr) visible=\(isVisible)")
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
            return try? loader.newTexture(URL: url, options: options)
        }
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
            pixelFormat: texture.pixelFormat,
            width: targetWidth,
            height: targetHeight,
            mipmapped: true
        )
        desc.mipmapLevelCount = mipCount
        desc.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        desc.storageMode = .private

        guard let target = renderInfo.device.makeTexture(descriptor: desc) else {
            if verboseLogging {
                print("[TextureStreaming] GPU resample failed: makeTexture returned nil (size: \(targetWidth)x\(targetHeight))")
            }
            return nil
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            if verboseLogging {
                print("[TextureStreaming] GPU resample failed: makeCommandBuffer returned nil")
            }
            return nil
        }

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

    public func reset() {
        lock.lock()
        upgradedEntities.removeAll()
        activeOps.removeAll()
        totalUpgrades = 0
        totalDowngrades = 0
        lock.unlock()
        timeSinceLastUpdate = 0
    }
}

public struct TextureStreamingStats {
    public var totalUpgrades: Int
    public var totalDowngrades: Int
    public var upgradedEntityCount: Int
    public var activeOps: Int
}
