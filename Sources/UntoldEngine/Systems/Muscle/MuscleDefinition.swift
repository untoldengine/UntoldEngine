//
//  MuscleDefinition.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Where a muscle attaches to the skeleton: a point along a bone (from the
/// joint toward its tip) plus an offset in the character frame
/// (lateral-left, up, forward) in model units.
public struct MuscleAttachment: Sendable, Equatable {
    /// Joint name (last path component) or full joint path.
    public var jointName: String
    /// Joint defining the far end of the bone; defaults to the joint's first
    /// non-twist child.
    public var tipJointName: String?
    /// 0 = at the joint, 1 = at the bone tip.
    public var fraction: Float
    /// Offset from the bone axis in the character frame (lateral-left, up, forward).
    public var offset: simd_float3

    public init(jointName: String, fraction: Float = 0.5, offset: simd_float3 = .zero, tipJointName: String? = nil) {
        self.jointName = jointName
        self.fraction = fraction
        self.offset = offset
        self.tipJointName = tipJointName
    }
}

/// Maps a joint's rest-relative rotation angle onto muscle activation: 0 at
/// `startAngle`, 1 at `fullAngle`, clamped. `fullAngle < startAngle` inverts
/// the mapping (activation rises as the joint straightens).
public struct MuscleActivationDriver: Sendable, Equatable {
    public var jointName: String
    /// Radians.
    public var startAngle: Float
    /// Radians.
    public var fullAngle: Float

    public init(jointName: String, startAngle: Float, fullAngle: Float) {
        self.jointName = jointName
        self.startAngle = startAngle
        self.fullAngle = fullAngle
    }
}

/// One volumetric muscle: a fusiform tet cage built procedurally between two
/// attachments, simulated with XPBD (fiber and cross-fiber distance
/// constraints plus per-tet volume constraints) and wrapped onto the skinned
/// surface. Compliances are XPBD inverse stiffnesses (0 = rigid).
public struct MuscleDefinition: Sendable, Equatable {
    public var name: String
    public var origin: MuscleAttachment
    public var insertion: MuscleAttachment
    /// Radius of the belly (mid-muscle), model units.
    public var bellyRadius: Float
    /// Radius at the attachments, model units.
    public var tendonRadius: Float
    /// Fiber rest-length reduction at full activation (0.25 = fibers shorten 25%).
    public var maxContraction: Float
    public var fiberCompliance: Float
    public var crossCompliance: Float
    public var volumeCompliance: Float
    /// Velocity damping per second.
    public var damping: Float
    /// Capsule radius of the two bones the muscle collides against; 0 disables.
    public var boneRadius: Float
    /// Distance beyond the muscle surface within which skin vertices follow it.
    public var skinInfluence: Float
    /// Cross-section rings along the axis (>= 2).
    public var rings: Int
    /// Vertices per ring (>= 3).
    public var segments: Int
    public var driver: MuscleActivationDriver?

    public init(
        name: String,
        origin: MuscleAttachment,
        insertion: MuscleAttachment,
        bellyRadius: Float,
        tendonRadius: Float,
        maxContraction: Float = 0.25,
        fiberCompliance: Float = 1e-6,
        crossCompliance: Float = 1e-5,
        volumeCompliance: Float = 0,
        damping: Float = 6,
        boneRadius: Float = 0,
        skinInfluence: Float = 0.03,
        rings: Int = 7,
        segments: Int = 8,
        driver: MuscleActivationDriver? = nil
    ) {
        self.name = name
        self.origin = origin
        self.insertion = insertion
        self.bellyRadius = bellyRadius
        self.tendonRadius = tendonRadius
        self.maxContraction = maxContraction
        self.fiberCompliance = fiberCompliance
        self.crossCompliance = crossCompliance
        self.volumeCompliance = volumeCompliance
        self.damping = damping
        self.boneRadius = boneRadius
        self.skinInfluence = skinInfluence
        self.rings = rings
        self.segments = segments
        self.driver = driver
    }
}

/// Two joints whose bind-pose direction (projected onto the ground plane)
/// defines the character's forward axis, e.g. a foot and its toe.
public struct MuscleForwardReference: Sendable, Equatable {
    public var fromJointName: String
    public var toJointName: String

    public init(fromJointName: String, toJointName: String) {
        self.fromJointName = fromJointName
        self.toJointName = toJointName
    }
}

/// The muscle set of one skeleton. Loaded from the asset's muscle table or
/// assigned at runtime with `setEntityMuscleRig`.
public struct MuscleRig: Sendable, Equatable {
    /// Defines the character frame's forward axis; nil means model +Z.
    public var forwardReference: MuscleForwardReference?
    public var muscles: [MuscleDefinition]

    public init(forwardReference: MuscleForwardReference? = nil, muscles: [MuscleDefinition]) {
        self.forwardReference = forwardReference
        self.muscles = muscles
    }
}

/// Orthonormal character axes in bind-pose model space.
struct MuscleCharacterFrame {
    var lateral: simd_float3
    var up: simd_float3
    var forward: simd_float3

    func modelOffset(_ offset: simd_float3) -> simd_float3 {
        lateral * offset.x + up * offset.y + forward * offset.z
    }
}

extension Skeleton {
    /// Resolves a joint by full path, by `/name` suffix, or by last path
    /// component.
    func muscleJointIndex(named name: String) -> Int? {
        if let exact = jointPaths.firstIndex(of: name) {
            return exact
        }
        let suffix = "/" + name
        if let bySuffix = jointPaths.firstIndex(where: { $0.hasSuffix(suffix) }) {
            return bySuffix
        }
        return jointPaths.firstIndex { path in
            path.split(separator: "/").last.map(String.init) == name
        }
    }

    /// The far end of the bone starting at `jointIndex`: the explicit tip,
    /// otherwise the first child whose name carries no twist/roll marker,
    /// otherwise the first child. Nil for leaf joints.
    func muscleBoneTipIndex(of jointIndex: Int, explicitTip: String?) -> Int? {
        if let explicitTip, let tip = muscleJointIndex(named: explicitTip) {
            return tip
        }
        let children = parentIndices.indices.filter { parentIndices[$0] == jointIndex }
        guard !children.isEmpty else { return nil }
        let preferred = children.first { child in
            let name = jointPaths[child].lowercased()
            return !name.contains("twist") && !name.contains("roll")
        }
        return preferred ?? children.first
    }

    func muscleBindPosition(of jointIndex: Int) -> simd_float3 {
        let column = bindTransform[jointIndex].columns.3
        return simd_float3(column.x, column.y, column.z)
    }

    /// Bind-pose model-space point of an attachment.
    func muscleAttachmentPoint(_ attachment: MuscleAttachment, frame: MuscleCharacterFrame) -> (point: simd_float3, joint: Int)? {
        guard let joint = muscleJointIndex(named: attachment.jointName) else { return nil }
        let start = muscleBindPosition(of: joint)
        var point = start
        if let tip = muscleBoneTipIndex(of: joint, explicitTip: attachment.tipJointName) {
            point = simd_mix(start, muscleBindPosition(of: tip), simd_float3(repeating: attachment.fraction))
        }
        return (point + frame.modelOffset(attachment.offset), joint)
    }

    /// Bone capsule endpoints in bind space: the joint and its tip (or a short
    /// stub along the parent bone for leaves).
    func muscleBoneSegment(of jointIndex: Int) -> (start: simd_float3, end: simd_float3) {
        let start = muscleBindPosition(of: jointIndex)
        if let tip = muscleBoneTipIndex(of: jointIndex, explicitTip: nil) {
            return (start, muscleBindPosition(of: tip))
        }
        if let parent = parentIndices[jointIndex] {
            let direction = start - muscleBindPosition(of: parent)
            return (start, start + direction * 0.5)
        }
        return (start, start)
    }

    func muscleCharacterFrame(forwardReference: MuscleForwardReference?) -> MuscleCharacterFrame {
        let up = simd_float3(0, 1, 0)
        var forward = simd_float3(0, 0, 1)
        if let forwardReference,
           let from = muscleJointIndex(named: forwardReference.fromJointName),
           let to = muscleJointIndex(named: forwardReference.toJointName)
        {
            var direction = muscleBindPosition(of: to) - muscleBindPosition(of: from)
            direction.y = 0
            if simd_length_squared(direction) > 1e-10 {
                forward = simd_normalize(direction)
            }
        }
        let lateral = simd_normalize(simd_cross(up, forward))
        return MuscleCharacterFrame(lateral: lateral, up: up, forward: forward)
    }
}
