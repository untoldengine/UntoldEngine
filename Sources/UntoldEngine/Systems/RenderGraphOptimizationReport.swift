//
//  RenderGraphOptimizationReport.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

struct RenderGraphResourceDeclarationSnapshot: Equatable {
    let kind: RenderExtensionArtifactKind
    let resourceID: String
    let ownerID: String?
    let lifetime: RenderExtensionResourceLifetime
}

struct CompiledRenderGraphRedundantDependency: Equatable {
    let passID: String
    let dependencyID: String
    let inferred: Bool
}

enum CompiledRenderGraphOptimizationIssue: Equatable {
    case missingResourceInterval(
        passID: String,
        kind: RenderExtensionArtifactKind,
        resourceID: String
    )
    case staleResourceInterval(kind: RenderExtensionArtifactKind, resourceID: String)
    case resourceIntervalMismatch(kind: RenderExtensionArtifactKind, resourceID: String)
    case missingAliasSlot(kind: RenderExtensionArtifactKind, resourceID: String, slotID: Int)
    case invalidAliasSlotResource(kind: RenderExtensionArtifactKind, resourceID: String)
    case incompatibleAliasSlot(slotID: Int, resourceID: String)
    case overlappingAliasSlot(
        slotID: Int,
        firstResourceID: String,
        secondResourceID: String
    )
}

struct CompiledRenderGraphStatistics: Equatable {
    let passCount: Int
    let dependencyCount: Int
    let explicitDependencyCount: Int
    let inferredDependencyCount: Int
    let usedResourceCount: Int
    let persistentResourceCount: Int
    let transientResourceCount: Int
    let transientAliasSlotCount: Int
    let aliasedResourceCount: Int
    let backingStoreReductionOpportunityCount: Int
    let unusedDeclaredResourceCount: Int
    let redundantDependencyCount: Int
}

struct CompiledRenderGraphOptimizationReport: Equatable {
    let statistics: CompiledRenderGraphStatistics
    let redundantDependencies: [CompiledRenderGraphRedundantDependency]
    let unusedResources: [RenderGraphResourceDeclarationSnapshot]
    let resourcePlanIssues: [CompiledRenderGraphOptimizationIssue]

    var isResourcePlanValid: Bool {
        resourcePlanIssues.isEmpty
    }
}

private struct OptimizationResourceKey: Hashable, Comparable {
    let kind: RenderExtensionArtifactKind
    let id: String

    static func < (lhs: OptimizationResourceKey, rhs: OptimizationResourceKey) -> Bool {
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.id < rhs.id
    }
}

private struct ExpectedResourceInterval {
    var firstUsePassIndex: Int
    var lastUsePassIndex: Int
    var passIDs: [String]
}

func compileRenderGraphOptimizationReport(
    _ orderedPasses: [CompiledRenderGraphPass],
    resourcePlan: CompiledRenderGraphResourcePlan
) -> CompiledRenderGraphOptimizationReport {
    let redundantDependencies = findRedundantRenderGraphDependencies(orderedPasses)
    let usedKeys = Set(resourcePlan.resources.map {
        OptimizationResourceKey(kind: $0.kind, id: $0.resourceID)
    })
    let unusedResources = RenderResourceRegistry.shared.declarationSnapshot().filter {
        !usedKeys.contains(OptimizationResourceKey(kind: $0.kind, id: $0.resourceID))
    }
    let resourcePlanIssues = validateCompiledRenderGraphResourcePlan(
        orderedPasses,
        resourcePlan: resourcePlan
    )
    let dependencyCount = orderedPasses.reduce(0) { $0 + $1.dependencies.count }
    let inferredDependencyCount = orderedPasses.reduce(0) {
        $0 + $1.inferredDependencies.count
    }
    let aliasedResourceCount = resourcePlan.transientAliasSlots.reduce(0) { count, slot in
        count + (slot.resourceIDs.count > 1 ? slot.resourceIDs.count : 0)
    }
    let backingStoreReduction = resourcePlan.transientAliasSlots.reduce(0) { count, slot in
        count + max(0, slot.resourceIDs.count - 1)
    }

    return CompiledRenderGraphOptimizationReport(
        statistics: CompiledRenderGraphStatistics(
            passCount: orderedPasses.count,
            dependencyCount: dependencyCount,
            explicitDependencyCount: dependencyCount - inferredDependencyCount,
            inferredDependencyCount: inferredDependencyCount,
            usedResourceCount: resourcePlan.resources.count,
            persistentResourceCount: resourcePlan.resources.filter {
                $0.lifetime == .persistent
            }.count,
            transientResourceCount: resourcePlan.resources.filter {
                $0.lifetime == .transient
            }.count,
            transientAliasSlotCount: resourcePlan.transientAliasSlots.count,
            aliasedResourceCount: aliasedResourceCount,
            backingStoreReductionOpportunityCount: backingStoreReduction,
            unusedDeclaredResourceCount: unusedResources.count,
            redundantDependencyCount: redundantDependencies.count
        ),
        redundantDependencies: redundantDependencies,
        unusedResources: unusedResources,
        resourcePlanIssues: resourcePlanIssues
    )
}

func validateCompiledRenderGraphResourcePlan(
    _ orderedPasses: [CompiledRenderGraphPass],
    resourcePlan: CompiledRenderGraphResourcePlan
) -> [CompiledRenderGraphOptimizationIssue] {
    let expectedIntervals = expectedResourceIntervals(orderedPasses)
    var resourcesByKey: [OptimizationResourceKey: CompiledRenderGraphResource] = [:]
    for resource in resourcePlan.resources {
        resourcesByKey[
            OptimizationResourceKey(kind: resource.kind, id: resource.resourceID)
        ] = resource
    }
    var issues: [CompiledRenderGraphOptimizationIssue] = []

    for key in expectedIntervals.keys.sorted() {
        guard let expected = expectedIntervals[key] else { continue }
        guard let resource = resourcesByKey[key] else {
            let passID = expected.passIDs.first ?? ""
            issues.append(
                .missingResourceInterval(
                    passID: passID,
                    kind: key.kind,
                    resourceID: key.id
                )
            )
            continue
        }
        if resource.firstUsePassIndex != expected.firstUsePassIndex
            || resource.lastUsePassIndex != expected.lastUsePassIndex
            || resource.passIDs != expected.passIDs
        {
            issues.append(.resourceIntervalMismatch(kind: key.kind, resourceID: key.id))
        }
    }
    for key in resourcesByKey.keys.sorted() where expectedIntervals[key] == nil {
        issues.append(.staleResourceInterval(kind: key.kind, resourceID: key.id))
    }

    var slotsByID: [Int: CompiledRenderGraphAliasSlot] = [:]
    for slot in resourcePlan.transientAliasSlots {
        slotsByID[slot.id] = slot
    }
    for resource in resourcePlan.resources {
        guard let slotID = resource.aliasSlotID else {
            if resource.lifetime == .transient {
                issues.append(
                    .invalidAliasSlotResource(
                        kind: resource.kind,
                        resourceID: resource.resourceID
                    )
                )
            }
            continue
        }
        guard let slot = slotsByID[slotID] else {
            issues.append(
                .missingAliasSlot(
                    kind: resource.kind,
                    resourceID: resource.resourceID,
                    slotID: slotID
                )
            )
            continue
        }
        if resource.lifetime != .transient
            || slot.kind != resource.kind
            || slot.ownerID != resource.ownerID
            || !slot.resourceIDs.contains(resource.resourceID)
        {
            issues.append(
                .invalidAliasSlotResource(
                    kind: resource.kind,
                    resourceID: resource.resourceID
                )
            )
        }
    }

    for slot in resourcePlan.transientAliasSlots {
        let slotResources = slot.resourceIDs.compactMap { resourceID in
            resourcesByKey[OptimizationResourceKey(kind: slot.kind, id: resourceID)]
        }.sorted { lhs, rhs in
            if lhs.firstUsePassIndex != rhs.firstUsePassIndex {
                return lhs.firstUsePassIndex < rhs.firstUsePassIndex
            }
            return lhs.resourceID < rhs.resourceID
        }
        var compatibility: RenderGraphTransientResourceCompatibility?
        for resourceID in slot.resourceIDs {
            let key = OptimizationResourceKey(kind: slot.kind, id: resourceID)
            guard let resource = resourcesByKey[key], resource.aliasSlotID == slot.id else {
                issues.append(
                    .invalidAliasSlotResource(kind: slot.kind, resourceID: resourceID)
                )
                continue
            }
            guard let resourceCompatibility = optimizationCompatibility(for: key) else {
                issues.append(
                    .incompatibleAliasSlot(slotID: slot.id, resourceID: resourceID)
                )
                continue
            }
            if let compatibility, compatibility != resourceCompatibility {
                issues.append(
                    .incompatibleAliasSlot(slotID: slot.id, resourceID: resourceID)
                )
            } else {
                compatibility = resourceCompatibility
            }
        }
        if slotResources.count > 1 {
            for index in 1 ..< slotResources.count {
                let previous = slotResources[index - 1]
                let current = slotResources[index]
                if previous.lastUsePassIndex >= current.firstUsePassIndex {
                    issues.append(
                        .overlappingAliasSlot(
                            slotID: slot.id,
                            firstResourceID: previous.resourceID,
                            secondResourceID: current.resourceID
                        )
                    )
                }
            }
        }
    }
    return issues
}

private func expectedResourceIntervals(
    _ orderedPasses: [CompiledRenderGraphPass]
) -> [OptimizationResourceKey: ExpectedResourceInterval] {
    var intervals: [OptimizationResourceKey: ExpectedResourceInterval] = [:]
    for (passIndex, pass) in orderedPasses.enumerated() {
        var keys: Set<OptimizationResourceKey> = []
        for usage in pass.resourceUsages {
            switch usage {
            case let .texture(id, _):
                keys.insert(OptimizationResourceKey(kind: .texture, id: id.rawValue))
            case let .buffer(id, _):
                keys.insert(OptimizationResourceKey(kind: .buffer, id: id.rawValue))
            }
        }
        for key in keys {
            if var interval = intervals[key] {
                interval.lastUsePassIndex = passIndex
                interval.passIDs.append(pass.id)
                intervals[key] = interval
            } else {
                intervals[key] = ExpectedResourceInterval(
                    firstUsePassIndex: passIndex,
                    lastUsePassIndex: passIndex,
                    passIDs: [pass.id]
                )
            }
        }
    }
    return intervals
}

private func findRedundantRenderGraphDependencies(
    _ orderedPasses: [CompiledRenderGraphPass]
) -> [CompiledRenderGraphRedundantDependency] {
    let passesByID = Dictionary(uniqueKeysWithValues: orderedPasses.map { ($0.id, $0) })
    var redundant: [CompiledRenderGraphRedundantDependency] = []
    for pass in orderedPasses {
        for dependencyID in Set(pass.dependencies).sorted() {
            let alternateRoots = pass.dependencies.filter { $0 != dependencyID }
            let duplicateCount = pass.dependencies.filter { $0 == dependencyID }.count
            let hasAlternatePath = duplicateCount > 1 || alternateRoots.contains { rootID in
                compiledPass(rootID, dependsOn: dependencyID, passesByID: passesByID)
            }
            if hasAlternatePath {
                redundant.append(
                    CompiledRenderGraphRedundantDependency(
                        passID: pass.id,
                        dependencyID: dependencyID,
                        inferred: pass.inferredDependencies.contains(dependencyID)
                    )
                )
            }
        }
    }
    return redundant
}

private func compiledPass(
    _ passID: String,
    dependsOn dependencyID: String,
    passesByID: [String: CompiledRenderGraphPass]
) -> Bool {
    var pending = passesByID[passID]?.dependencies ?? []
    var visited: Set<String> = []
    while let current = pending.popLast() {
        if current == dependencyID { return true }
        guard visited.insert(current).inserted else { continue }
        pending.append(contentsOf: passesByID[current]?.dependencies ?? [])
    }
    return false
}

private func optimizationCompatibility(
    for key: OptimizationResourceKey
) -> RenderGraphTransientResourceCompatibility? {
    renderGraphPlannedResourceDeclaration(
        kind: key.kind,
        resourceID: key.id
    )?.compatibility
}
