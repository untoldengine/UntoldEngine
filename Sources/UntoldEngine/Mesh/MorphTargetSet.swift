//
//  MorphTargetSet.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal

/// GPU-resident morph targets of one mesh: all targets' sparse delta entries
/// concatenated in a single buffer, with per-target ranges. Consumed by the
/// deformation pass's morph accumulation kernel.
final class MorphTargetSet {
    struct Target {
        let name: String
        let entryOffset: Int
        let entryCount: Int
        let positionScale: Float
        let hasNormalDeltas: Bool
        let driver: RuntimeMorphDriver?
    }

    let targets: [Target]
    let entryBuffer: MTLBuffer

    var targetNames: [String] {
        targets.map(\.name)
    }

    init?(primitive: RuntimeMeshPrimitive, device: MTLDevice) {
        guard !primitive.morphTargets.isEmpty else { return nil }

        var targets: [Target] = []
        var combined = Data()
        var entryCursor = 0
        for runtimeTarget in primitive.morphTargets {
            targets.append(Target(
                name: runtimeTarget.name,
                entryOffset: entryCursor,
                entryCount: runtimeTarget.entryCount,
                positionScale: runtimeTarget.positionScale,
                hasNormalDeltas: runtimeTarget.hasNormalDeltas,
                driver: runtimeTarget.driver
            ))
            combined.append(runtimeTarget.entryData)
            entryCursor += runtimeTarget.entryCount
        }

        guard !combined.isEmpty else { return nil }
        let buffer = combined.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let baseAddress = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: baseAddress, length: bytes.count, options: .storageModeShared)
        }
        guard let buffer else { return nil }
        buffer.label = "\(primitive.name) morph entries"

        self.targets = targets
        entryBuffer = buffer
    }
}
