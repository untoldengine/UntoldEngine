//
//  GaussianChunkTreeCullTests.swift
//  UntoldEngine
//
//  GaussianChunkTreeCull.visibleChunkRanges: the CPU pre-filter over a .untoldgs asset's baked
//  cluster tree. No Metal involved — pure geometry against hand-built trees, mirroring
//  GaussianChunkCullMathTests' style for the per-chunk math this stage sits in front of.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class GaussianChunkTreeCullTests: XCTestCase {
    // MARK: - Fixture

    /// Two well-separated leaf clusters under one root: a "left" cluster at x ∈ [-100, -90]
    /// owning chunks [0, 4), and a "right" cluster at x ∈ [90, 100] owning chunks [4, 8) — chosen
    /// far enough apart that a camera looking at one cluster cannot also see the other, even
    /// with the per-chunk padding this stage applies.
    private func makeTwoClusterTree() -> (nodes: [UntoldGSTreeNode], chunks: [UntoldGSChunkEntry]) {
        let leftLeaf = UntoldGSTreeNode(
            aabbMin: simd_float3(-100, -1, -1), aabbMax: simd_float3(-90, 1, 1),
            firstChunk: 0, chunkCount: 4
        )
        let rightLeaf = UntoldGSTreeNode(
            aabbMin: simd_float3(90, -1, -1), aabbMax: simd_float3(100, 1, 1),
            firstChunk: 4, chunkCount: 4
        )
        let root = UntoldGSTreeNode(
            aabbMin: simd_float3(-100, -1, -1), aabbMax: simd_float3(100, 1, 1),
            child0: 1, child1: 2,
            firstChunk: 0, chunkCount: 8
        )
        // Preorder: root at index 0, matching UntoldGSWriter.buildTree's layout.
        let nodes = [root, leftLeaf, rightLeaf]

        let chunks = (0 ..< 8).map { _ in
            UntoldGSChunkEntry(
                payloadOffset: 0, payloadBytes: 0, coreBytes: 0, splatCount: 128,
                aabbMin: .zero, aabbMax: .zero, logScaleMin: 0, logScaleMax: 0.01,
                crc32: 0
            )
        }
        return (nodes, chunks)
    }

    /// A right-handed view-projection looking from `eyeX` toward `lookX` along +Z, narrow enough
    /// (60° vertical FOV) that a cluster ~190 units off to the side at this distance falls well
    /// outside it, while a cluster directly ahead stays well inside it.
    private func makeViewProjection(eyeX: Float, lookX: Float, distance: Float = 20, fovyDegrees: Float = 60) -> simd_float4x4 {
        let view = matrix_look_at_right_hand(
            simd_float3(eyeX, 0, -distance), simd_float3(lookX, 0, 0), simd_float3(0, 1, 0)
        )
        let projection = matrixPerspectiveRightHand(
            fovyRadians: fovyDegrees * .pi / 180, aspectRatio: 1, nearZ: 0.1, farZ: 1000
        )
        return simd_mul(projection, view)
    }

    // MARK: - Basic pruning

    func testPrunesTheClusterOutsideView() {
        let (nodes, chunks) = makeTwoClusterTree()
        let seesRightOnly = makeViewProjection(eyeX: 95, lookX: 95)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: nodes, chunks: chunks, viewProjection0: seesRightOnly)

        XCTAssertEqual(ranges, [GaussianChunkRange(firstChunk: 4, chunkCount: 4)], "only the right cluster's chunks should survive")
    }

    func testMergesAdjacentSurvivingLeavesIntoOneSpan() {
        let (nodes, chunks) = makeTwoClusterTree()
        // Far enough back, wide enough FOV, that both clusters (x = ±90...100) are in view at once.
        let seesBoth = makeViewProjection(eyeX: 0, lookX: 0, distance: 500, fovyDegrees: 90)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: nodes, chunks: chunks, viewProjection0: seesBoth)

        XCTAssertEqual(
            ranges, [GaussianChunkRange(firstChunk: 0, chunkCount: 8)],
            "both leaves survive and their ranges abut (0+4==4), so they should collapse into one span"
        )
    }

    func testWholeTreeOutOfViewReturnsNoRanges() {
        let (nodes, chunks) = makeTwoClusterTree()
        // Shifted far past both clusters, same narrow FOV as the single-cluster test.
        let seesNeither = makeViewProjection(eyeX: 500, lookX: 500)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: nodes, chunks: chunks, viewProjection0: seesNeither)

        XCTAssertEqual(ranges, [], "the root itself should be pruned before either leaf is ever visited")
    }

    // MARK: - Stereo

    func testStereoKeepsASubtreeEitherEyeSees() {
        let (nodes, chunks) = makeTwoClusterTree()
        let eye0SeesRight = makeViewProjection(eyeX: 95, lookX: 95)
        let eye1SeesLeft = makeViewProjection(eyeX: -95, lookX: -95)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(
            nodes: nodes, chunks: chunks, viewProjection0: eye0SeesRight, viewProjection1: eye1SeesLeft
        )

        XCTAssertEqual(
            ranges, [GaussianChunkRange(firstChunk: 0, chunkCount: 8)],
            "left survives via eye1, right via eye0 — both present, and since they abut they merge into one span"
        )
    }

    func testMonoIgnoresTheSecondEyeWhenNil() {
        let (nodes, chunks) = makeTwoClusterTree()
        let seesRightOnly = makeViewProjection(eyeX: 95, lookX: 95)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(
            nodes: nodes, chunks: chunks, viewProjection0: seesRightOnly, viewProjection1: nil
        )

        XCTAssertEqual(ranges, [GaussianChunkRange(firstChunk: 4, chunkCount: 4)])
    }

    // MARK: - Files without a tree

    func testEmptyNodesReturnsOneSpanCoveringEveryChunk() {
        let (_, chunks) = makeTwoClusterTree()
        let anyViewProjection = makeViewProjection(eyeX: 95, lookX: 95)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: [], chunks: chunks, viewProjection0: anyViewProjection)

        XCTAssertEqual(
            ranges, [GaussianChunkRange(firstChunk: 0, chunkCount: 8)],
            "a tree-less file (older, or too small to ever get one) must not silently lose chunks"
        )
    }

    func testEmptyNodesAndEmptyChunksReturnsNoRanges() {
        let anyViewProjection = makeViewProjection(eyeX: 95, lookX: 95)
        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: [], chunks: [], viewProjection0: anyViewProjection)
        XCTAssertEqual(ranges, [])
    }

    // MARK: - Padding

    /// A leaf whose *unpadded* box sits just past the frustum's edge, but whose own
    /// `maxLogScaleMax` (its subtree's largest splat scale, baked per node by
    /// `UntoldGSWriter.buildTree`) is big enough that the padded box the per-chunk test would
    /// actually use pokes back inside — visibleChunkRanges must keep it, the same way the
    /// per-chunk kernel would once it opened that chunk. Uses a wide-open frustum (looking
    /// straight down +Z the box already mostly faces) so only the padding, not incidental
    /// framing, decides it.
    func testPadsNodeBoxByTheAssetsLargestSplatScale() {
        // A tight 20° FOV pointed straight down +Z keeps the clip volume's x extent at roughly
        // ±tan(10°)·z — about ±1.4 at z = 8 — so the box (x = 10.5...11.5) is well outside it
        // unpadded, and only a substantial pad brings it back in.
        let straightAhead = simd_mul(
            matrixPerspectiveRightHand(fovyRadians: 20 * .pi / 180, aspectRatio: 1, nearZ: 0.1, farZ: 1000),
            matrix_look_at_right_hand(.zero, simd_float3(0, 0, 1), simd_float3(0, 1, 0))
        )

        // Unused by this call (only the tree-less fallback reads it), but still required.
        let placeholderChunks = [UntoldGSChunkEntry(
            payloadOffset: 0, payloadBytes: 0, coreBytes: 0, splatCount: 1,
            aabbMin: .zero, aabbMax: .zero, logScaleMin: 0, logScaleMax: 0, crc32: 0
        )]

        let smallScaleNode = UntoldGSTreeNode(
            aabbMin: simd_float3(10.5, -1, 8), aabbMax: simd_float3(11.5, 1, 10),
            firstChunk: 0, chunkCount: 1, maxLogScaleMax: 0.01
        )
        // Confirm the premise: the *unpadded* box genuinely fails this frustum on its own.
        XCTAssertFalse(
            GaussianChunkCullMath.boxPassesClipPlanes(boxMin: smallScaleNode.aabbMin, boxMax: smallScaleNode.aabbMax, viewProjection: straightAhead),
            "test setup error: the box should be outside the frustum before padding"
        )
        XCTAssertEqual(
            GaussianChunkTreeCull.visibleChunkRanges(nodes: [smallScaleNode], chunks: placeholderChunks, viewProjection0: straightAhead),
            [],
            "a small maxLogScaleMax should not pad the box back into view"
        )

        let largeScaleNode = UntoldGSTreeNode(
            aabbMin: simd_float3(10.5, -1, 8), aabbMax: simd_float3(11.5, 1, 10),
            firstChunk: 0, chunkCount: 1, maxLogScaleMax: log(6.0)
        )
        XCTAssertEqual(
            GaussianChunkTreeCull.visibleChunkRanges(nodes: [largeScaleNode], chunks: placeholderChunks, viewProjection0: straightAhead),
            [GaussianChunkRange(firstChunk: 0, chunkCount: 1)],
            "the node's own subtree maxLogScaleMax should pad its box back into view, keeping the chunk this stage must not drop"
        )
    }

    func testInvalidChildIndexIsSkippedNotCrashed() {
        // A single node that claims to be internal (children set) but points nowhere valid: the
        // walk must skip it, not trap — defensive against a malformed or truncated tree.
        var malformed = UntoldGSTreeNode(
            aabbMin: simd_float3(-1, -1, -1), aabbMax: simd_float3(1, 1, 1),
            firstChunk: 0, chunkCount: 1
        )
        malformed.child0 = 99
        malformed.child1 = UntoldGSFormat.invalidNode
        let chunks = [UntoldGSChunkEntry(
            payloadOffset: 0, payloadBytes: 0, coreBytes: 0, splatCount: 1,
            aabbMin: .zero, aabbMax: .zero, logScaleMin: 0, logScaleMax: 0.01, crc32: 0
        )]
        let seesOrigin = makeViewProjection(eyeX: 0, lookX: 0, distance: 5)

        let ranges = GaussianChunkTreeCull.visibleChunkRanges(nodes: [malformed], chunks: chunks, viewProjection0: seesOrigin)

        XCTAssertEqual(ranges, [], "an internal node with no valid children contributes nothing, rather than crashing")
    }
}
