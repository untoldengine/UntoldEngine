//
//  LODImportDetection.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct ImportedLODNameLevelCandidate: Equatable {
    let lodIndex: Int
    let sourceName: String
}

struct ImportedLODNameGroupCandidate: Equatable {
    let baseName: String
    let levels: [ImportedLODNameLevelCandidate]
}

struct ImportedLODNameDetectionResult {
    let groups: [ImportedLODNameGroupCandidate]
    let ambiguousBaseNames: Set<String>
}

func parseLODAssetName(_ assetName: String) -> (baseName: String, lodIndex: Int)? {
    guard let lodTokenRange = assetName.range(of: "_LOD", options: [.caseInsensitive, .backwards]) else {
        return nil
    }

    let suffix = String(assetName[lodTokenRange.upperBound...])
    guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber), let lodIndex = Int(suffix) else {
        return nil
    }

    let baseName = String(assetName[..<lodTokenRange.lowerBound])
    guard !baseName.isEmpty else {
        return nil
    }

    return (baseName: baseName, lodIndex: lodIndex)
}

func detectImportedLODGroups(fromSourceNames sourceNames: [String]) -> ImportedLODNameDetectionResult {
    var levelsByBaseName: [String: [Int: String]] = [:]
    var ambiguousBaseNames: Set<String> = []

    let uniqueSourceNames = Set(sourceNames.filter { !$0.isEmpty })
    for sourceName in uniqueSourceNames {
        guard let (baseName, lodIndex) = parseLODAssetName(sourceName) else {
            continue
        }

        if ambiguousBaseNames.contains(baseName) {
            continue
        }

        if let existingSourceName = levelsByBaseName[baseName]?[lodIndex], existingSourceName != sourceName {
            ambiguousBaseNames.insert(baseName)
            levelsByBaseName.removeValue(forKey: baseName)
            continue
        }

        levelsByBaseName[baseName, default: [:]][lodIndex] = sourceName
    }

    var groups: [ImportedLODNameGroupCandidate] = []
    groups.reserveCapacity(levelsByBaseName.count)

    for (baseName, levelsByIndex) in levelsByBaseName {
        let sortedLevels = levelsByIndex.map { lodIndex, sourceName in
            ImportedLODNameLevelCandidate(lodIndex: lodIndex, sourceName: sourceName)
        }.sorted { $0.lodIndex < $1.lodIndex }

        // One level is not useful as an LOD family.
        guard sortedLevels.count >= 2 else {
            continue
        }

        groups.append(
            ImportedLODNameGroupCandidate(
                baseName: baseName,
                levels: sortedLevels
            )
        )
    }

    groups.sort { $0.baseName < $1.baseName }
    return ImportedLODNameDetectionResult(groups: groups, ambiguousBaseNames: ambiguousBaseNames)
}

func missingLODIndices(for levels: [ImportedLODNameLevelCandidate]) -> [Int] {
    let indices = levels.map(\.lodIndex).sorted()
    guard let minIndex = indices.first, let maxIndex = indices.last else {
        return []
    }

    let indexSet = Set(indices)
    return (minIndex ... maxIndex).filter { indexSet.contains($0) == false }
}

func defaultLODMaxDistance(for lodIndex: Int, configuredDistances: [Float]) -> Float {
    if lodIndex < configuredDistances.count {
        return configuredDistances[lodIndex]
    }

    guard let lastDistance = configuredDistances.last else {
        return 50.0 * Float(lodIndex + 1)
    }

    let previousDistance = configuredDistances.count > 1 ? configuredDistances[configuredDistances.count - 2] : lastDistance / 2.0
    let step = max(1.0, lastDistance - previousDistance)
    let overflowIndex = lodIndex - configuredDistances.count + 1
    return lastDistance + step * Float(overflowIndex)
}
