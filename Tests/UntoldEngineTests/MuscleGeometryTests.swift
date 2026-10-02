//
//  MuscleGeometryTests.swift
//  UntoldEngineTests
//
//  CPU tests for the procedural muscle cage builder and skin binding.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

final class MuscleGeometryTests: XCTestCase {
    /// Two-bone arm: shoulder at the origin, elbow 0.3 m down +X, wrist a
    /// further 0.25 m; a toe pair for the forward reference.
    static func makeArmSkeleton() -> Skeleton {
        func translation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
            var matrix = matrix_identity_float4x4
            matrix.columns.3 = simd_float4(x, y, z, 1)
            return matrix
        }
        let runtime = RuntimeSkeleton(
            jointPaths: ["/root", "/root/upperArm", "/root/upperArm/forearm", "/root/upperArm/forearm/hand", "/root/foot", "/root/foot/toe"],
            parentIndices: [nil, 0, 1, 2, 0, 4],
            bindTransforms: [
                translation(0, 1, 0), translation(0, 1, 0), translation(0.3, 1, 0), translation(0.55, 1, 0),
                translation(0.1, 0, 0), translation(0.1, 0, 0.2),
            ],
            restTransforms: [
                translation(0, 1, 0), matrix_identity_float4x4, translation(0.3, 0, 0), translation(0.25, 0, 0),
                translation(0.1, -1, 0), translation(0, 0, 0.2),
            ]
        )
        return Skeleton(runtimeSkeleton: runtime)!
    }

    /// Anatomical-ish biceps for a 2 m rig: the belly sits in front of the
    /// humerus with its inner surface just touching the bone capsule.
    static func makeBicepsRig() -> MuscleRig {
        MuscleRig(
            forwardReference: MuscleForwardReference(fromJointName: "foot", toJointName: "toe"),
            muscles: [
                MuscleDefinition(
                    name: "biceps",
                    origin: MuscleAttachment(jointName: "upperArm", fraction: 0.15, offset: simd_float3(0, 0, 0.045)),
                    insertion: MuscleAttachment(jointName: "forearm", fraction: 0.2, offset: simd_float3(0, 0, 0.035)),
                    bellyRadius: 0.028,
                    tendonRadius: 0.01,
                    boneRadius: 0.012,
                    skinInfluence: 0.03,
                    rings: 6,
                    segments: 8,
                    driver: MuscleActivationDriver(jointName: "forearm", startAngle: 0.2, fullAngle: 1.9)
                ),
            ]
        )
    }

    func testJointResolutionByNameSuffixAndPath() {
        let skeleton = Self.makeArmSkeleton()
        XCTAssertEqual(skeleton.muscleJointIndex(named: "forearm"), 2)
        XCTAssertEqual(skeleton.muscleJointIndex(named: "upperArm/forearm"), 2)
        XCTAssertEqual(skeleton.muscleJointIndex(named: "/root/upperArm"), 1)
        XCTAssertNil(skeleton.muscleJointIndex(named: "missing"))
        XCTAssertEqual(skeleton.muscleBoneTipIndex(of: 1, explicitTip: nil), 2)
        XCTAssertNil(skeleton.muscleBoneTipIndex(of: 5, explicitTip: nil))
    }

    func testCharacterFrameFollowsForwardReference() {
        let skeleton = Self.makeArmSkeleton()
        let frame = skeleton.muscleCharacterFrame(
            forwardReference: MuscleForwardReference(fromJointName: "foot", toJointName: "toe")
        )
        XCTAssertEqual(frame.forward.z, 1, accuracy: 1e-5)
        XCTAssertEqual(frame.lateral.x, 1, accuracy: 1e-5)
        XCTAssertEqual(frame.up.y, 1, accuracy: 1e-5)
    }

    func testFusiformCageIsWellFormed() throws {
        let skeleton = Self.makeArmSkeleton()
        let geometry = try XCTUnwrap(MuscleGeometryBuilder.bake(rig: Self.makeBicepsRig(), skeleton: skeleton))
        XCTAssertEqual(geometry.muscles.count, 1)
        let muscle = geometry.muscles[0]
        XCTAssertEqual(geometry.particleCount, 6 * 9)
        XCTAssertEqual(geometry.tets.count, 5 * 8 * 3)

        // Every tet has positive rest volume and indexes its muscle's particles.
        for tet in geometry.tets {
            XCTAssertGreaterThan(tet.restVolume, 0)
            for id in [tet.vertices.x, tet.vertices.y, tet.vertices.z, tet.vertices.w] {
                XCTAssertTrue(muscle.particleRange.contains(Int(id)))
            }
        }
        // End rings are pinned, ring centres are derived (both massless);
        // the four interior rings are free.
        let massless = geometry.initialPositions.filter { $0.w == 0 }.count
        XCTAssertEqual(massless, 2 * 8 + 6)
        XCTAssertEqual(geometry.particleInfos.filter { $0.attachment == UInt32(MUSCLE_ATTACHMENT_ORIGIN) }.count, 8)
        XCTAssertEqual(geometry.particleInfos.filter { $0.attachment == UInt32(MUSCLE_ATTACHMENT_INSERTION) }.count, 8)
        XCTAssertEqual(geometry.particleInfos.filter { $0.attachment == UInt32(MUSCLE_ATTACHMENT_CENTER) }.count, 6)

        // Contractile fibers fill the three interior slabs; the two tendon
        // slabs plus every hoop carry no contraction.
        XCTAssertEqual(geometry.edges.filter { $0.fiber == 1 }.count, 3 * 8)
        XCTAssertEqual(geometry.edges.filter { $0.fiber == 0.5 }.count, 3 * 8)
        XCTAssertEqual(geometry.edges.filter { $0.fiber == 0 }.count, 6 * 8 + 2 * 8 + 2 * 8)
        XCTAssertTrue(geometry.edges.allSatisfy { $0.restLength > 0 })

        // The closed surface (tube + caps) has positive volume.
        XCTAssertEqual(geometry.triangles.count, 5 * 8 * 2 + 2 * 8)
        XCTAssertGreaterThan(muscle.restVolume, 0)
        XCTAssertEqual(
            muscle.restVolume,
            MuscleGeometryBuilder.surfaceVolume(geometry.triangles[...], positions: geometry.initialPositions),
            accuracy: 1e-9
        )

        // CSR adjacency lists every incidence exactly once.
        XCTAssertEqual(geometry.edgeOffsets.count, geometry.particleCount + 1)
        XCTAssertEqual(Int(geometry.edgeOffsets.last ?? 0), geometry.edges.count * 2)
        XCTAssertEqual(Int(geometry.triOffsets.last ?? 0), geometry.triangles.count * 3)
        for particle in 0 ..< geometry.particleCount {
            for k in Int(geometry.edgeOffsets[particle]) ..< Int(geometry.edgeOffsets[particle + 1]) {
                let edge = geometry.edges[Int(geometry.edgeList[k])]
                XCTAssertTrue(edge.a == UInt32(particle) || edge.b == UInt32(particle))
            }
            for k in Int(geometry.triOffsets[particle]) ..< Int(geometry.triOffsets[particle + 1]) {
                let tri = geometry.triangles[Int(geometry.triList[k])]
                XCTAssertTrue([tri.a, tri.b, tri.c].contains(UInt32(particle)))
            }
        }

        // The belly ring sits at the belly radius, offset forward of the bone.
        XCTAssertEqual(muscle.restLength, simd_length(muscle.insertionRest - muscle.originRest), accuracy: 1e-6)
        XCTAssertEqual(muscle.originRest.z, 0.045, accuracy: 1e-6)
        XCTAssertEqual(muscle.driverJoint, 2)
    }

    func testSkinBindingWeightsFadeAtTendonsAndOutsideInfluence() throws {
        let skeleton = Self.makeArmSkeleton()
        let geometry = try XCTUnwrap(MuscleGeometryBuilder.bake(rig: Self.makeBicepsRig(), skeleton: skeleton))
        let muscle = geometry.muscles[0]
        let belly = muscle.originRest + muscle.restAxis * (muscle.restLength * 0.5)
        let tendon = muscle.originRest + muscle.restAxis * (muscle.restLength * 0.02)
        let side = simd_float3(0, 0, 1)
        let positions = [
            simd_float4(belly + side * (muscle.definition.bellyRadius * 0.5), 1), // inside the belly
            simd_float4(belly + side * (muscle.definition.bellyRadius + 0.015), 1), // in the influence shell
            simd_float4(belly + side * (muscle.definition.bellyRadius + 0.2), 1), // far away
            simd_float4(tendon, 1), // at the tendon
        ]
        let bindings = MuscleGeometryBuilder.bindSkin(positions: positions, geometry: geometry)

        XCTAssertEqual(bindings[0].weight, 1, accuracy: 1e-5)
        XCTAssertNotEqual(bindings[0].tetIndex, MUSCLE_SKIN_UNBOUND)
        XCTAssertGreaterThan(bindings[1].weight, 0)
        XCTAssertLessThan(bindings[1].weight, 1)
        XCTAssertEqual(bindings[2].tetIndex, MUSCLE_SKIN_UNBOUND)
        XCTAssertEqual(bindings[3].tetIndex, MUSCLE_SKIN_UNBOUND, "tendon ends must not bind")

        // Inside a tet the barycentrics reproduce the point.
        let binding = bindings[0]
        let tet = geometry.tets[Int(binding.tetIndex)]
        func position(_ id: UInt32) -> simd_float3 {
            let p = geometry.initialPositions[Int(id)]
            return simd_float3(p.x, p.y, p.z)
        }
        let reconstructed = binding.barycentric.x * position(tet.vertices.x)
            + binding.barycentric.y * position(tet.vertices.y)
            + binding.barycentric.z * position(tet.vertices.z)
            + binding.barycentric.w * position(tet.vertices.w)
        let expected = simd_float3(positions[0].x, positions[0].y, positions[0].z)
        XCTAssertLessThan(simd_length(reconstructed - expected), 2e-3)
    }
}
