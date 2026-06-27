//
//  RenderGraphResourcePlan.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal

struct CompiledRenderGraphResource: Equatable {
    let kind: RenderExtensionArtifactKind
    let resourceID: String
    let ownerID: String?
    let lifetime: RenderExtensionResourceLifetime
    let firstUsePassIndex: Int
    let lastUsePassIndex: Int
    let passIDs: [String]
    let aliasSlotID: Int?
}

struct CompiledRenderGraphAliasSlot: Equatable {
    let id: Int
    let kind: RenderExtensionArtifactKind
    let ownerID: String?
    let resourceIDs: [String]
}

struct CompiledRenderGraphResourcePlan: Equatable {
    let resources: [CompiledRenderGraphResource]
    let transientAliasSlots: [CompiledRenderGraphAliasSlot]

    func resource(
        kind: RenderExtensionArtifactKind,
        id: String
    ) -> CompiledRenderGraphResource? {
        resources.first { $0.kind == kind && $0.resourceID == id }
    }
}

private struct PlannedResourceKey: Hashable, Comparable {
    let kind: RenderExtensionArtifactKind
    let id: String

    static func < (lhs: PlannedResourceKey, rhs: PlannedResourceKey) -> Bool {
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.id < rhs.id
    }
}

enum RenderGraphTransientResourceCompatibility: Equatable {
    case texture(
        ownerID: String?,
        size: RenderExtensionResourceSize,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode,
        mipMapLevels: Int,
        sampleCount: Int
    )
    case buffer(
        ownerID: String?,
        length: Int,
        options: MTLResourceOptions
    )
}

struct RenderGraphPlannedResourceDeclaration {
    let ownerID: String?
    let lifetime: RenderExtensionResourceLifetime
    let compatibility: RenderGraphTransientResourceCompatibility
}

private struct MutableResourceInterval {
    let key: PlannedResourceKey
    let ownerID: String?
    let lifetime: RenderExtensionResourceLifetime
    let compatibility: RenderGraphTransientResourceCompatibility?
    var firstUsePassIndex: Int
    var lastUsePassIndex: Int
    var passIDs: [String]
}

private struct MutableAliasSlot {
    let id: Int
    let kind: RenderExtensionArtifactKind
    let ownerID: String?
    let compatibility: RenderGraphTransientResourceCompatibility
    var lastUsePassIndex: Int
    var resourceIDs: [String]
}

func compileRenderGraphResourcePlan(
    _ orderedPasses: [CompiledRenderGraphPass]
) -> CompiledRenderGraphResourcePlan {
    var intervals: [PlannedResourceKey: MutableResourceInterval] = [:]

    for (passIndex, pass) in orderedPasses.enumerated() {
        var passResources: Set<PlannedResourceKey> = []
        for usage in pass.resourceUsages {
            let key: PlannedResourceKey
            switch usage {
            case let .texture(id, _):
                key = PlannedResourceKey(kind: .texture, id: id.rawValue)
            case let .buffer(id, _):
                key = PlannedResourceKey(kind: .buffer, id: id.rawValue)
            }
            passResources.insert(key)
        }

        for key in passResources.sorted() {
            if var interval = intervals[key] {
                interval.lastUsePassIndex = passIndex
                interval.passIDs.append(pass.id)
                intervals[key] = interval
            } else if let declaration = plannedResourceDeclaration(for: key) {
                intervals[key] = MutableResourceInterval(
                    key: key,
                    ownerID: declaration.ownerID,
                    lifetime: declaration.lifetime,
                    compatibility: declaration.compatibility,
                    firstUsePassIndex: passIndex,
                    lastUsePassIndex: passIndex,
                    passIDs: [pass.id]
                )
            }
        }
    }

    let orderedIntervals = intervals.values.sorted { lhs, rhs in
        if lhs.firstUsePassIndex != rhs.firstUsePassIndex {
            return lhs.firstUsePassIndex < rhs.firstUsePassIndex
        }
        return lhs.key < rhs.key
    }
    var aliasSlots: [MutableAliasSlot] = []
    var aliasSlotByResource: [PlannedResourceKey: Int] = [:]

    // Stable first-fit assignment keeps slot IDs reproducible across compilations.
    for interval in orderedIntervals where interval.lifetime == .transient {
        guard let compatibility = interval.compatibility else { continue }
        if let slotIndex = aliasSlots.firstIndex(where: { slot in
            slot.compatibility == compatibility
                && slot.lastUsePassIndex < interval.firstUsePassIndex
        }) {
            aliasSlots[slotIndex].lastUsePassIndex = interval.lastUsePassIndex
            aliasSlots[slotIndex].resourceIDs.append(interval.key.id)
            aliasSlotByResource[interval.key] = aliasSlots[slotIndex].id
        } else {
            let slotID = aliasSlots.count
            aliasSlots.append(
                MutableAliasSlot(
                    id: slotID,
                    kind: interval.key.kind,
                    ownerID: interval.ownerID,
                    compatibility: compatibility,
                    lastUsePassIndex: interval.lastUsePassIndex,
                    resourceIDs: [interval.key.id]
                )
            )
            aliasSlotByResource[interval.key] = slotID
        }
    }

    let resources = intervals.values.sorted { $0.key < $1.key }.map { interval in
        CompiledRenderGraphResource(
            kind: interval.key.kind,
            resourceID: interval.key.id,
            ownerID: interval.ownerID,
            lifetime: interval.lifetime,
            firstUsePassIndex: interval.firstUsePassIndex,
            lastUsePassIndex: interval.lastUsePassIndex,
            passIDs: interval.passIDs,
            aliasSlotID: aliasSlotByResource[interval.key]
        )
    }
    let compiledSlots = aliasSlots.map { slot in
        CompiledRenderGraphAliasSlot(
            id: slot.id,
            kind: slot.kind,
            ownerID: slot.ownerID,
            resourceIDs: slot.resourceIDs
        )
    }
    return CompiledRenderGraphResourcePlan(
        resources: resources,
        transientAliasSlots: compiledSlots
    )
}

private func plannedResourceDeclaration(
    for key: PlannedResourceKey
) -> RenderGraphPlannedResourceDeclaration? {
    renderGraphPlannedResourceDeclaration(kind: key.kind, resourceID: key.id)
}

func renderGraphPlannedResourceDeclaration(
    kind: RenderExtensionArtifactKind,
    resourceID: String
) -> RenderGraphPlannedResourceDeclaration? {
    switch kind {
    case .texture:
        guard let declaration = RenderResourceRegistry.shared.textureDeclaration(
            RenderTextureResourceID(resourceID)
        ) else {
            return nil
        }
        let descriptor = declaration.descriptor
        return RenderGraphPlannedResourceDeclaration(
            ownerID: declaration.ownerID,
            lifetime: descriptor.lifetime,
            compatibility: .texture(
                ownerID: declaration.ownerID,
                size: descriptor.size,
                pixelFormat: descriptor.pixelFormat,
                usage: descriptor.usage,
                storageMode: descriptor.storageMode,
                mipMapLevels: descriptor.mipMapLevels,
                sampleCount: descriptor.sampleCount
            )
        )
    case .buffer:
        guard let declaration = RenderResourceRegistry.shared.bufferDeclaration(
            RenderBufferResourceID(resourceID)
        ) else {
            return nil
        }
        let descriptor = declaration.descriptor
        return RenderGraphPlannedResourceDeclaration(
            ownerID: declaration.ownerID,
            lifetime: descriptor.lifetime,
            compatibility: .buffer(
                ownerID: declaration.ownerID,
                length: descriptor.length,
                options: descriptor.options
            )
        )
    default:
        return nil
    }
}
