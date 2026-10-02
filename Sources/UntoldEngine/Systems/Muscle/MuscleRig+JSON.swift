//
//  MuscleRig+JSON.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// JSON form of a muscle rig, the same document `untoldexplorer.py
/// --muscles` consumes (driver angles in degrees, offsets in the character
/// frame lateral-left / up / forward). Used by the ML deformer baker and by
/// tools that want to hand a rig to the engine without re-exporting.
public extension MuscleRig {
    init(jsonData: Data) throws {
        let document = try JSONDecoder().decode(MuscleRigDocument.self, from: jsonData)
        forwardReference = document.forwardReference.map {
            MuscleForwardReference(fromJointName: $0.from, toJointName: $0.to)
        }
        muscles = try document.muscles.map { try $0.definition() }
    }

    init(contentsOf url: URL) throws {
        try self.init(jsonData: Data(contentsOf: url))
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(MuscleRigDocument(rig: self))
    }
}

struct MuscleRigDocument: Codable {
    struct ForwardReference: Codable {
        var from: String
        var to: String
    }

    struct Attachment: Codable {
        var joint: String
        var fraction: Float?
        var offset: [Float]?
        var tip: String?

        func attachment() throws -> MuscleAttachment {
            var vector = simd_float3(0, 0, 0)
            if let offset {
                guard offset.count == 3 else { throw MuscleRigJSONError.invalidOffset(joint) }
                vector = simd_float3(offset[0], offset[1], offset[2])
            }
            return MuscleAttachment(jointName: joint, fraction: fraction ?? 0.5, offset: vector, tipJointName: tip)
        }
    }

    struct Driver: Codable {
        var joint: String
        var startAngle: Float?
        var fullAngle: Float?
    }

    struct Muscle: Codable {
        var name: String
        var origin: Attachment
        var insertion: Attachment
        var bellyRadius: Float
        var tendonRadius: Float
        var maxContraction: Float?
        var fiberCompliance: Float?
        var crossCompliance: Float?
        var volumeCompliance: Float?
        var damping: Float?
        var boneRadius: Float?
        var skinInfluence: Float?
        var rings: Int?
        var segments: Int?
        var driver: Driver?

        func definition() throws -> MuscleDefinition {
            guard bellyRadius > 0, tendonRadius > 0 else { throw MuscleRigJSONError.invalidRadius(name) }
            let defaults = try MuscleDefinition(
                name: name, origin: origin.attachment(), insertion: insertion.attachment(),
                bellyRadius: bellyRadius, tendonRadius: tendonRadius
            )
            return MuscleDefinition(
                name: name,
                origin: defaults.origin,
                insertion: defaults.insertion,
                bellyRadius: bellyRadius,
                tendonRadius: tendonRadius,
                maxContraction: maxContraction ?? defaults.maxContraction,
                fiberCompliance: fiberCompliance ?? defaults.fiberCompliance,
                crossCompliance: crossCompliance ?? defaults.crossCompliance,
                volumeCompliance: volumeCompliance ?? defaults.volumeCompliance,
                damping: damping ?? defaults.damping,
                boneRadius: boneRadius ?? defaults.boneRadius,
                skinInfluence: skinInfluence ?? defaults.skinInfluence,
                rings: rings ?? defaults.rings,
                segments: segments ?? defaults.segments,
                driver: driver.map {
                    MuscleActivationDriver(
                        jointName: $0.joint,
                        startAngle: ($0.startAngle ?? 0) * .pi / 180,
                        fullAngle: ($0.fullAngle ?? 90) * .pi / 180
                    )
                }
            )
        }
    }

    var skeleton: String?
    var forwardReference: ForwardReference?
    var muscles: [Muscle]

    init(rig: MuscleRig) {
        skeleton = nil
        forwardReference = rig.forwardReference.map { ForwardReference(from: $0.fromJointName, to: $0.toJointName) }
        muscles = rig.muscles.map { definition in
            Muscle(
                name: definition.name,
                origin: Attachment(
                    joint: definition.origin.jointName, fraction: definition.origin.fraction,
                    offset: [definition.origin.offset.x, definition.origin.offset.y, definition.origin.offset.z],
                    tip: definition.origin.tipJointName
                ),
                insertion: Attachment(
                    joint: definition.insertion.jointName, fraction: definition.insertion.fraction,
                    offset: [definition.insertion.offset.x, definition.insertion.offset.y, definition.insertion.offset.z],
                    tip: definition.insertion.tipJointName
                ),
                bellyRadius: definition.bellyRadius,
                tendonRadius: definition.tendonRadius,
                maxContraction: definition.maxContraction,
                fiberCompliance: definition.fiberCompliance,
                crossCompliance: definition.crossCompliance,
                volumeCompliance: definition.volumeCompliance,
                damping: definition.damping,
                boneRadius: definition.boneRadius,
                skinInfluence: definition.skinInfluence,
                rings: definition.rings,
                segments: definition.segments,
                driver: definition.driver.map {
                    Driver(joint: $0.jointName, startAngle: $0.startAngle * 180 / .pi, fullAngle: $0.fullAngle * 180 / .pi)
                }
            )
        }
    }
}

public enum MuscleRigJSONError: Error, Equatable {
    case invalidOffset(String)
    case invalidRadius(String)
}
