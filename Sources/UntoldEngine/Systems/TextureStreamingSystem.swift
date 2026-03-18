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
    public var upgradeRadius: Float = 30.0

    /// Textures between `upgradeRadius` and `downgradeRadius` stream to `maxTextureDimension`.
    /// Textures beyond `downgradeRadius` stream to `minimumTextureDimension`.
    public var downgradeRadius: Float = 60.0

    /// Mid-distance max dimension.
    public var maxTextureDimension: Int = TextureStreamingSystem.platformDefaultMaxTextureDimension

    /// Far-distance max dimension.
    public var minimumTextureDimension: Int = TextureStreamingSystem.platformDefaultMinimumTextureDimension

    /// How often to evaluate texture streaming (seconds)
    public var updateInterval: Float = 0.2

    /// Print to console when texture resolution changes.
    public var verboseLogging: Bool = true

    /// Maximum concurrent texture streaming operations.
    public var maxConcurrentOps: Int = 3

    // MARK: - State

    private var timeSinceLastUpdate: Float = 0

    /// Entities that currently hold textures above `minimumTextureDimension`.
    private var upgradedEntities: Set<EntityID> = []
    private var activeOps: Set<EntityID> = []

    private let lock = NSLock()

    /// Reusable command queue for GPU resampling.
    private var commandQueue: MTLCommandQueue?

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

            let targetMaxDimension = desiredMaxDimension(distance: distance, isVisible: true)
            guard entityNeedsResolutionChange(entityId: entityId, targetMaxDimension: targetMaxDimension) else { continue }

            scheduleResolutionChange(entityId: entityId, distance: distance, targetMaxDimension: targetMaxDimension, isVisible: true)
            opsScheduled += 1
        }

        // Priority 2: entities no longer visible should settle to minimum mip tier.
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

            let targetMaxDimension = desiredMaxDimension(distance: .infinity, isVisible: false)
            guard entityNeedsResolutionChange(entityId: entityId, targetMaxDimension: targetMaxDimension) else {
                lock.lock()
                upgradedEntities.remove(entityId)
                lock.unlock()
                continue
            }

            scheduleResolutionChange(entityId: entityId, distance: -1, targetMaxDimension: targetMaxDimension, isVisible: false)
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
    private func desiredMaxDimension(distance: Float, isVisible: Bool) -> Int? {
        if isVisible, distance <= upgradeRadius {
            return nil
        }
        if isVisible, distance <= downgradeRadius {
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

    private func entityNeedsResolutionChange(entityId: EntityID, targetMaxDimension: Int?) -> Bool {
        !buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension).isEmpty
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

    private func scheduleResolutionChange(entityId: EntityID, distance: Float, targetMaxDimension: Int?, isVisible: Bool) {
        guard reserveOp(entityId) else { return }

        let workItems = buildWorkItems(entityId: entityId, targetMaxDimension: targetMaxDimension)
        guard !workItems.isEmpty else {
            releaseOp(entityId)
            return
        }

        guard let device = renderInfo.device else {
            releaseOp(entityId)
            return
        }

        Task {
            var loaded: [LoadedTexture] = []
            loaded.reserveCapacity(workItems.count)

            let loader = MTKTextureLoader(device: device)
            for item in workItems {
                let texture: MTLTexture?
                switch item.direction {
                case .upgrade:
                    guard let sourceTexture = self.loadSourceTexture(item.slot.source, isSRGB: item.slot.isSRGB, loader: loader) else {
                        continue
                    }
                    texture = self.resampleTextureIfNeeded(sourceTexture, targetMaxDimension: item.targetMaxDimension)
                case .downgrade:
                    texture = self.resampleTextureIfNeeded(item.slot.currentTexture, targetMaxDimension: item.targetMaxDimension)
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

                    _ = self.verboseLogging
                    _ = distance
                    _ = isVisible
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

    private func resampleTextureIfNeeded(_ texture: MTLTexture, targetMaxDimension: Int?) -> MTLTexture? {
        guard let targetMaxDimension else { return texture }
        return downsampleTexture(texture, maxDimension: targetMaxDimension)
    }

    /// Downsample a texture to fit within maxDimension, preserving aspect ratio.
    private func downsampleTexture(_ texture: MTLTexture, maxDimension: Int) -> MTLTexture? {
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

        if commandQueue == nil {
            commandQueue = renderInfo.device.makeCommandQueue()
        }

        guard let target = renderInfo.device.makeTexture(descriptor: desc),
              let commandBuffer = commandQueue?.makeCommandBuffer()
        else { return nil }

        let scale = MPSImageBilinearScale(device: renderInfo.device)
        scale.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: target)

        if let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: target)
            blit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

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

    public func getStats() -> TextureStreamingStats {
        lock.lock()
        let upgradedCount = upgradedEntities.count
        let activeCount = activeOps.count
        lock.unlock()
        return TextureStreamingStats(
            totalUpgrades: totalUpgrades,
            totalDowngrades: totalDowngrades,
            upgradedEntityCount: upgradedCount,
            activeOps: activeCount
        )
    }

    public func reset() {
        lock.lock()
        upgradedEntities.removeAll()
        activeOps.removeAll()
        lock.unlock()
        timeSinceLastUpdate = 0
        totalUpgrades = 0
        totalDowngrades = 0
    }
}

public struct TextureStreamingStats {
    public var totalUpgrades: Int
    public var totalDowngrades: Int
    public var upgradedEntityCount: Int
    public var activeOps: Int
}
