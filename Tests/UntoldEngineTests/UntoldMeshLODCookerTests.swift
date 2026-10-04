//
//  UntoldMeshLODCookerTests.swift
//  UntoldEngine
//
//  The automatic LOD cook: the levels it writes for a model, what it leaves alone, the
//  borders and the aggregates it has to respect, and the pack manifest.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Compression
import Foundation
import simd
@testable import UntoldEngine
@testable import UntoldEngineMeshCook
import XCTest

final class UntoldMeshLODCookerTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldMeshLODCookerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    // MARK: - A chain

    func testAChainHasThreeLevelsNearTheRatiosAskedFor() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertNil(chain.skipped)
        XCTAssertEqual(chain.triangleCount, 8192)
        XCTAssertEqual(chain.levels.count, 3)
        for (level, ratio) in zip(chain.levels, [0.5, 0.15, 0.03] as [Float]) {
            let share = Float(level.triangleCount) / Float(chain.triangleCount)
            XCTAssertEqual(share, ratio, accuracy: ratio * 0.25, "\(level.url.lastPathComponent) holds \(level.triangleCount) triangles")
        }
        XCTAssertEqual(chain.levels.map(\.url.lastPathComponent), ["hill_LOD1.untold", "hill_LOD2.untold", "hill_LOD3.untold"])
    }

    func testEachLevelSwitchesAtASmallerScreenSizeThanTheOneBefore() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL, options: UntoldMeshLODOptions(pixelsPerTriangle: 4))

        let sizes = chain.levels.map(\.screenSize)
        XCTAssertEqual(sizes, sizes.sorted(by: >))
        // 4 pixels a triangle on a viewport 1080 pixels high.
        let first = try XCTUnwrap(chain.levels.first)
        XCTAssertEqual(first.screenSize, (4 * Float(first.triangleCount)).squareRoot() / 1080, accuracy: 1e-4)
    }

    func testALevelIsTheModelWithItsGeometryReplaced() throws {
        let model = LODTestModel(meshes: [.wavySurface(cells: 48), .wavySurface(cells: 32, offset: SIMD3<Float>(0, 5, 0), material: 1)])
        let modelURL = try model.write(to: directory, name: "two")
        let source = try UntoldReader().readAsset(from: modelURL)

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        for level in chain.levels {
            // readAsset checks the content hash and the ranges of every mesh record.
            let decoded = try UntoldReader().readAsset(from: level.url)
            XCTAssertEqual(decoded.header.fileType, .lod)
            XCTAssertEqual(decoded.header.flags & UntoldFileFlags.generatedLODLevel, UntoldFileFlags.generatedLODLevel)
            XCTAssertEqual(decoded.header.formatVersion, source.header.formatVersion)
            XCTAssertEqual(decoded.header.worldBounds, source.header.worldBounds)
            XCTAssertEqual(decoded.entities, source.entities)
            XCTAssertEqual(decoded.materials, source.materials)
            XCTAssertEqual(decoded.textures, source.textures)
            XCTAssertEqual(decoded.stringTableData, source.stringTableData)
            XCTAssertEqual(decoded.meshes.count, source.meshes.count)
            XCTAssertEqual(decoded.meshes.reduce(0) { $0 + Int($1.indexCount) / 3 }, level.triangleCount)
            for (mesh, original) in zip(decoded.meshes, source.meshes) {
                XCTAssertEqual(mesh.entityId, original.entityId)
                XCTAssertEqual(mesh.materialIndex, original.materialIndex)
                XCTAssertEqual(mesh.meshNameOffset, original.meshNameOffset)
                XCTAssertLessThan(mesh.indexCount, original.indexCount)
                XCTAssertLessThan(mesh.vertexCount, original.vertexCount)
                XCTAssertEqual(mesh.edgeIndexCount, 0)
                XCTAssertTrue(contains(original.localBounds, mesh.localBounds), "a level stays inside the bounds of its mesh")
            }

            let asset = try NativeFormatLoader().loadAssetSync(from: level.url)
            XCTAssertEqual(asset.nodes.map(\.id), source.entities.map(\.entityId))
            XCTAssertEqual(asset.nodes.map(\.primitives.count), [1, 1])
        }
    }

    func testAShortIndexLevelOfALongIndexMeshReadsBack() throws {
        // 261 x 261 vertices need 32-bit indices; 3 % of the triangles do not.
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 260)]).write(to: directory, name: "wide")
        let source = try UntoldReader().readAsset(from: modelURL)
        XCTAssertEqual(source.meshes[0].indexType, .uint32)

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        let coarsest = try UntoldReader().readAsset(from: XCTUnwrap(chain.levels.last).url)
        XCTAssertEqual(coarsest.meshes[0].indexType, .uint16)
        XCTAssertNoThrow(try NativeFormatLoader().loadAssetSync(from: XCTUnwrap(chain.levels.last).url))
    }

    func testCompressedGeometryStaysCompressed() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)], compressGeometry: true).write(to: directory, name: "packed")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.levels.count, 3)
        for level in chain.levels {
            let decoded = try UntoldReader().readAsset(from: level.url)
            XCTAssertEqual(decoded.chunks.first { $0.chunkType == .vertexData }?.compressionType, .lz4)
            XCTAssertEqual(decoded.chunks.first { $0.chunkType == .indexData }?.compressionType, .lz4)
            XCTAssertNoThrow(try NativeFormatLoader().loadAssetSync(from: level.url))
        }
    }

    // MARK: - No chain

    func testAModelUnderTheMinimumGetsNoChain() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 16)]).write(to: directory, name: "small")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.triangleCount, 512)
        XCTAssertEqual(chain.skipped, .belowMinimumTriangles)
        XCTAssertTrue(chain.levels.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 1).path))
    }

    func testAModelThatCannotBeReducedGetsNoChain() throws {
        let triangle = LODTestMesh(
            positions: [SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 0, 0), SIMD3<Float>(0, 0, 1)],
            normals: [SIMD3<Float>](repeating: SIMD3<Float>(0, 1, 0), count: 3),
            indices: [0, 2, 1]
        )
        let modelURL = try LODTestModel(meshes: [triangle]).write(to: directory, name: "triangle")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL, options: UntoldMeshLODOptions(minimumTriangles: 0))

        XCTAssertEqual(chain.skipped, .irreducible)
        XCTAssertTrue(chain.levels.isEmpty)
    }

    func testALevelIsNotGivenLevelsOfItsOwn() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")
        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)
        let levelURL = try XCTUnwrap(chain.levels.first).url

        let nested = try UntoldMeshLODCooker.cookChain(forModelAt: levelURL, options: UntoldMeshLODOptions(minimumTriangles: 0))

        XCTAssertEqual(nested.skipped, .isLevel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: levelURL, level: 1).path))
    }

    func testSkinnedAndAnimationFilesKeepTheirMeshes() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UntoldEngineRenderTests/Resources")
        for name in ["Models/redplayer/redplayer", "Animations/running/running"] {
            let sourceURL = resources.appendingPathComponent(name).appendingPathExtension("untold")
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw XCTSkip("cooked fixture not found at \(sourceURL.path)")
            }
            let modelURL = directory.appendingPathComponent(sourceURL.lastPathComponent)
            try FileManager.default.copyItem(at: sourceURL, to: modelURL)

            let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL, options: UntoldMeshLODOptions(minimumTriangles: 0))

            XCTAssertEqual(chain.skipped, .deforms, name)
        }
    }

    func testAnUnreadableModelThrows() throws {
        let modelURL = directory.appendingPathComponent("broken.untold")
        try Data("not a model".utf8).write(to: modelURL)

        XCTAssertThrowsError(try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)) { error in
            guard case UntoldMeshLODError.unreadableModel = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testOptionsAreChecked() {
        for options in [
            UntoldMeshLODOptions(ratios: []),
            UntoldMeshLODOptions(ratios: [0.5, 0.5]),
            UntoldMeshLODOptions(ratios: [0.2, 0.5]),
            UntoldMeshLODOptions(ratios: [1.0]),
            UntoldMeshLODOptions(ratios: [0]),
            UntoldMeshLODOptions(minimumTriangles: -1),
            UntoldMeshLODOptions(pixelsPerTriangle: 0),
        ] {
            XCTAssertThrowsError(try options.validate(), "\(options)")
        }
        XCTAssertNoThrow(try UntoldMeshLODOptions().validate())
    }

    // MARK: - Cooking again

    func testCookingAgainReplacesTheLevelsOfTheCookBefore() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")
        try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)
        let third = UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: third.path))

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL, options: UntoldMeshLODOptions(ratios: [0.25]))

        XCTAssertEqual(chain.levels.count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 1).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 2).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: third.path))
    }

    func testAModelThatNoLongerQualifiesLosesItsLevels() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")
        try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL, options: UntoldMeshLODOptions(minimumTriangles: 100_000))

        XCTAssertEqual(chain.skipped, .belowMinimumTriangles)
        XCTAssertFalse(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 1).path))
    }

    func testAFileThatOnlyHasALevelsNameIsLeftAlone() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 64)]).write(to: directory, name: "hill")
        // Somebody's own model, named the way a level would be.
        let ownURL = try LODTestModel(meshes: [.wavySurface(cells: 8)]).write(to: directory, name: "hill_LOD2")
        let own = try Data(contentsOf: ownURL)

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.skipped, .levelNameTaken)
        XCTAssertEqual(try Data(contentsOf: ownURL), own)
        XCTAssertFalse(FileManager.default.fileExists(atPath: UntoldMeshLODCooker.levelURL(forModelAt: modelURL, level: 1).path))
    }

    // MARK: - Borders between the meshes of a model

    func testTheBorderTwoMeshesShareStaysClosed() throws {
        // Two halves of one wavy surface, each its own mesh and material, meeting on x = 0.
        let left = LODTestMesh.wavySurface(cells: 48, origin: SIMD2<Float>(-10, -5), size: SIMD2<Float>(10, 10))
        let right = LODTestMesh.wavySurface(cells: 48, origin: SIMD2<Float>(0, -5), size: SIMD2<Float>(10, 10), material: 1)
        let modelURL = try LODTestModel(meshes: [left, right]).write(to: directory, name: "halves")
        let seam = Set(left.positions.filter { $0.x == 0 }.map(PositionKey.init))
        XCTAssertEqual(seam.count, 49)
        XCTAssertEqual(seam, Set(right.positions.filter { $0.x == 0 }.map(PositionKey.init)))

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.levels.count, 3)
        for level in chain.levels {
            let meshes = try levelPositions(level.url)
            for (name, positions) in zip(["left", "right"], meshes) {
                let kept = Set(positions.filter { $0.x == 0 }.map(PositionKey.init))
                XCTAssertEqual(kept, seam, "\(name) half of \(level.url.lastPathComponent) keeps every vertex of the shared border")
            }
        }
    }

    func testABorderThatNoOtherMeshSharesIsSimplified() throws {
        let modelURL = try LODTestModel(meshes: [.wavySurface(cells: 48)]).write(to: directory, name: "alone")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        let coarsest = try levelPositions(XCTUnwrap(chain.levels.last).url)[0]
        let border = coarsest.filter { abs($0.x) == 5 || abs($0.z) == 5 }
        XCTAssertLessThan(border.count, 4 * 48, "the open border loses vertices like the rest")
    }

    // MARK: - Texture seams

    func testOnlyATexturedMeshKeepsItsTextureSeams() {
        let surface = LODTestMesh.unwrappedSurface(cells: 32, islands: 2)
        func flags(textured: Bool) -> [UInt8] {
            var meshes = [UntoldLODMesh(vertexData: surface.vertexData, indices: surface.indices)]
            UntoldMeshLODCooker.applyVertexFlags(to: &meshes, transforms: [matrix_identity_float4x4], textured: [textured])
            return meshes[0].flags
        }

        // Two lines of 33 vertices cross the surface; each vertex on them has a second
        // copy in the next island, and the one at the crossing has three.
        XCTAssertEqual(flags(textured: true).filter { $0 != 0 }.count, 33 + 33 + 1)
        XCTAssertTrue(flags(textured: false).isEmpty, "texture coordinates nothing reads do not hold the simplifier back")
    }

    func testATexturedLevelKeepsItsTrianglesInsideTheirIslands() throws {
        let surface = LODTestMesh.unwrappedSurface(cells: 64, islands: 2)
        let modelURL = try LODTestModel(meshes: [surface], texturedMaterials: [0]).write(to: directory, name: "atlas")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.levels.count, 3)
        for level in chain.levels {
            let (uvs, indices) = try levelTextureCoordinates(level.url)
            for start in stride(from: 0, to: indices.count, by: 3) {
                let islands = Set((0 ..< 3).map { LODTestMesh.island(of: uvs[Int(indices[start + $0])], islands: 2) })
                XCTAssertEqual(islands.count, 1, "a triangle of \(level.url.lastPathComponent) reads two islands of the texture")
                if islands.count != 1 {
                    return
                }
            }
        }
    }

    func testSeamsThatWouldHoldALevelBackAreReleased() throws {
        // Every quad is its own island: with the seams kept, nothing can collapse.
        let surface = LODTestMesh.unwrappedSurface(cells: 48, islands: 48)
        let modelURL = try LODTestModel(meshes: [surface], texturedMaterials: [0]).write(to: directory, name: "patchwork")

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.triangleCount, 4608)
        XCTAssertEqual(chain.levels.count, 3)
        XCTAssertLessThanOrEqual(try XCTUnwrap(chain.levels.first).triangleCount, 2304 * 5 / 4)
    }

    // MARK: - Aggregates

    func testAnAggregateIsThinnedEvenlyAndKeepsItsArea() throws {
        // A canopy: 1,500 leaf cards of 32 triangles each around a trunk, like a tree
        // out of a modelling package.
        let leaves = LODTestMesh.cards(count: 1500, cellsPerCard: 4, cardSize: 0.3, radius: 6, seed: 7)
        let trunk = LODTestMesh.wavySurface(cells: 24, origin: SIMD2<Float>(-0.5, -0.5), size: SIMD2<Float>(1, 1), material: 1)
        let modelURL = try LODTestModel(meshes: [leaves, trunk]).write(to: directory, name: "tree")
        let leafArea = area(positions: leaves.positions, indices: leaves.indices)
        XCTAssertEqual(leaves.indices.count / 3, 48000)

        let chain = try UntoldMeshLODCooker.cookChain(forModelAt: modelURL)

        XCTAssertEqual(chain.levels.count, 3)
        let source = try UntoldReader().readAsset(from: modelURL)
        var cardCounts: [Int] = []
        for level in chain.levels {
            let decoded = try UntoldReader().readAsset(from: level.url)
            let (positions, indices) = try levelGeometry(level.url, mesh: 0)
            XCTAssertEqual(
                area(positions: positions, indices: indices), leafArea, accuracy: leafArea * 0.05,
                "\(level.url.lastPathComponent) covers what the leaves covered"
            )
            XCTAssertTrue(contains(source.meshes[0].localBounds, decoded.meshes[0].localBounds))
            cardCounts.append(componentCount(positions: positions, indices: indices))
        }
        // 1,440 triangles are fewer than the cards: the coarsest level cannot keep them all.
        XCTAssertEqual(cardCounts.first, 1500, "the first level only collapses inside the cards")
        XCTAssertLessThan(try XCTUnwrap(cardCounts.last), 1440)
        XCTAssertGreaterThan(try XCTUnwrap(cardCounts.last), 500)
        try XCTAssertEqual(Float(XCTUnwrap(chain.levels.last).triangleCount) / Float(chain.triangleCount), 0.03, accuracy: 0.02)

        // Evenly: each octant of the canopy keeps its share of the cards.
        let (coarsePositions, coarseIndices) = try levelGeometry(XCTUnwrap(chain.levels.last).url, mesh: 0)
        let before = octantShares(positions: leaves.positions, indices: leaves.indices)
        let after = octantShares(positions: coarsePositions, indices: coarseIndices)
        for (octant, (was, now)) in zip(before, after).enumerated() {
            XCTAssertEqual(now, was, accuracy: 0.05, "octant \(octant)")
        }
    }

    func testAFewLoosePiecesAreNotAnAggregate() throws {
        // Ten small cards beside a large surface: details, not a canopy. Their area is
        // not handed to the survivors when they go.
        let surface = LODTestMesh.wavySurface(cells: 64)
        let details = LODTestMesh.cards(count: 10, cellsPerCard: 2, cardSize: 0.05, radius: 4, seed: 3)
        let merged = LODTestMesh.merged([surface, details])

        let parts = UntoldLODMeshParts(mesh: UntoldLODMesh(vertexData: merged.vertexData, indices: merged.indices))
        XCTAssertTrue(parts.clutterIndices.isEmpty)
        XCTAssertEqual(parts.bodyIndices.count, merged.indices.count)

        let canopy = LODTestMesh.cards(count: 100, cellsPerCard: 2, cardSize: 0.05, radius: 4, seed: 3)
        let canopyParts = UntoldLODMeshParts(mesh: UntoldLODMesh(vertexData: canopy.vertexData, indices: canopy.indices))
        XCTAssertEqual(canopyParts.clutterIndices.count, canopy.indices.count)
        XCTAssertTrue(canopyParts.bodyIndices.isEmpty)
        // The bounding box of a card at an angle: between its diagonal and that of its cube.
        XCTAssertGreaterThanOrEqual(canopyParts.clutterPieceSize, 0.05 * Float(2).squareRoot() - 1e-4)
        XCTAssertLessThanOrEqual(canopyParts.clutterPieceSize, 0.05 * Float(3).squareRoot() + 1e-4)

        // The model still gets its chain; the details go with the surface around them.
        let modelURL = try LODTestModel(meshes: [merged]).write(to: directory, name: "plate")
        XCTAssertEqual(try UntoldMeshLODCooker.cookChain(forModelAt: modelURL).levels.count, 3)
    }

    // MARK: - Packs

    func testAPackGetsAChainForEachModelThatNeedsOne() throws {
        let packURL = try writePack(
            models: [
                ("Tree A", "Site/Tree/Tree.untold", LODTestModel(meshes: [.wavySurface(cells: 64)])),
                ("Tree B", "Site/Tree/Tree.untold", nil),
                ("Rock", "Site/Rock/Rock.untold", LODTestModel(meshes: [.wavySurface(cells: 40)])),
                ("Sign", "Site/Sign/Sign.untold", LODTestModel(meshes: [.wavySurface(cells: 8)])),
            ],
            extra: ["exporter": "kept"]
        )
        let before = try XCTUnwrap(loadUntoldPack(url: packURL))

        let progress = ProgressLog()
        let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL) { done, total in progress.add(done, total) }

        XCTAssertEqual(report.modelCount, 3, "a model placed twice is one model")
        XCTAssertEqual(report.chainCount, 2)
        XCTAssertEqual(report.levelCount, 6)
        XCTAssertEqual(report.chainedTriangleCount, 8192 + 3200)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertGreaterThan(report.levelBytes, 0)
        XCTAssertEqual(progress.calls.map(\.0).sorted(), [1, 2, 3])
        XCTAssertEqual(Set(progress.calls.map(\.1)), [3])

        let after = try XCTUnwrap(loadUntoldPack(url: packURL))
        XCTAssertEqual(after.formatVersion, before.formatVersion)
        XCTAssertEqual(after.sourceAsset, before.sourceAsset)
        XCTAssertEqual(after.models.map(\.path), before.models.map(\.path))
        XCTAssertEqual(after.models.map(\.displayName), before.models.map(\.displayName))
        XCTAssertEqual(after.models.map(\.transform), before.models.map(\.transform))
        let chains = try XCTUnwrap(after.lodChains)
        XCTAssertEqual(Set(chains.keys), ["Site/Tree/Tree.untold", "Site/Rock/Rock.untold"])
        let tree = try XCTUnwrap(chains["Site/Tree/Tree.untold"])
        XCTAssertEqual(tree.map(\.path), ["Site/Tree/Tree_LOD1.untold", "Site/Tree/Tree_LOD2.untold", "Site/Tree/Tree_LOD3.untold"])
        XCTAssertEqual(tree.map(\.screenSize), tree.map(\.screenSize).sorted(by: >))
        for level in tree {
            XCTAssertTrue(FileManager.default.fileExists(atPath: packURL.deletingLastPathComponent().appendingPathComponent(level.path).path))
            XCTAssertNotNil(level.triangles)
            XCTAssertNotNil(level.error)
        }

        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: packURL)) as? [String: Any])
        XCTAssertEqual(raw["exporter"] as? String, "kept", "keys the cook does not know stay")
    }

    func testCookingAPackAgainGivesTheSameManifest() throws {
        let packURL = try writePack(models: [("Tree", "Site/Tree/Tree.untold", LODTestModel(meshes: [.wavySurface(cells: 64)]))])
        try UntoldMeshLODCooker.cookChains(forPackAt: packURL)
        let first = try Data(contentsOf: packURL)

        try UntoldMeshLODCooker.cookChains(forPackAt: packURL)

        XCTAssertEqual(try Data(contentsOf: packURL), first)
    }

    func testAPackWhoseModelsNeedNoChainHasNoChainTable() throws {
        let packURL = try writePack(models: [("Sign", "Site/Sign/Sign.untold", LODTestModel(meshes: [.wavySurface(cells: 8)]))])
        try UntoldMeshLODCooker.cookChains(forPackAt: packURL, options: UntoldMeshLODOptions(minimumTriangles: 0))
        XCTAssertNotNil(try XCTUnwrap(loadUntoldPack(url: packURL)).lodChains)

        let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL)

        XCTAssertEqual(report.chainCount, 0)
        XCTAssertNil(try XCTUnwrap(loadUntoldPack(url: packURL)).lodChains)
    }

    func testAModelThatCannotBeReadIsReportedAndTheOthersStillGetChains() throws {
        let packURL = try writePack(models: [
            ("Tree", "Site/Tree/Tree.untold", LODTestModel(meshes: [.wavySurface(cells: 64)])),
            ("Gone", "Site/Gone/Gone.untold", nil),
        ])

        let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL)

        XCTAssertEqual(report.chainCount, 1)
        XCTAssertEqual(report.failures.map(\.path), ["Site/Gone/Gone.untold"])
        XCTAssertEqual(try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains).keys.sorted(), ["Site/Tree/Tree.untold"])
    }

    func testAManifestThatIsNotAPackThrows() throws {
        let packURL = directory.appendingPathComponent("list.untoldpack")
        try Data("[1, 2, 3]".utf8).write(to: packURL)

        XCTAssertThrowsError(try UntoldMeshLODCooker.cookChains(forPackAt: packURL)) { error in
            guard case UntoldMeshLODError.unreadableManifest = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Helpers

    private final class ProgressLog: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(Int, Int)] = []

        func add(_ done: Int, _ total: Int) {
            lock.withLock { entries.append((done, total)) }
        }

        var calls: [(Int, Int)] {
            lock.withLock { entries }
        }
    }

    /// Writes a manifest placing `models`; a nil model reuses (or leaves out) the file at its path.
    private func writePack(models: [(name: String, path: String, model: LODTestModel?)], extra: [String: Any] = [:]) throws -> URL {
        var entries: [[String: Any]] = []
        for (index, model) in models.enumerated() {
            let url = directory.appendingPathComponent(model.path)
            if let content = model.model {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try content.data().write(to: url)
            }
            entries.append([
                "displayName": model.name,
                "path": model.path,
                "transform": [[1, 0, 0, Double(index) * 2.5], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]],
            ])
        }
        var manifest: [String: Any] = ["formatVersion": 1, "sourceAsset": "Site.blend", "models": entries]
        manifest.merge(extra) { current, _ in current }
        let packURL = directory.appendingPathComponent("Site.untoldpack")
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]).write(to: packURL)
        return packURL
    }

    private func contains(_ outer: UntoldAABB, _ inner: UntoldAABB) -> Bool {
        all(inner.min .>= outer.min - 1e-4) && all(inner.max .<= outer.max + 1e-4)
    }

    /// The vertex positions of every mesh of a level file.
    private func levelPositions(_ url: URL) throws -> [[SIMD3<Float>]] {
        let count = try UntoldReader().readAsset(from: url).meshes.count
        return try (0 ..< count).map { try levelGeometry(url, mesh: $0).positions }
    }

    private func levelGeometry(_ url: URL, mesh index: Int) throws -> (positions: [SIMD3<Float>], indices: [UInt32]) {
        let asset = try NativeFormatLoader().loadAssetSync(from: url)
        let primitive = try XCTUnwrap(asset.nodes.flatMap(\.primitives).dropFirst(index).first)
        let positions: [SIMD3<Float>] = primitive.vertexData.withUnsafeBytes { raw in
            (0 ..< primitive.vertexCount).map { vertex in
                SIMD3<Float>(
                    raw.loadUnaligned(fromByteOffset: vertex * 32, as: Float.self),
                    raw.loadUnaligned(fromByteOffset: vertex * 32 + 4, as: Float.self),
                    raw.loadUnaligned(fromByteOffset: vertex * 32 + 8, as: Float.self)
                )
            }
        }
        let indices: [UInt32] = primitive.indexData.withUnsafeBytes { raw in
            (0 ..< primitive.indexCount).map { position in
                primitive.indexFormat == .uint16
                    ? UInt32(raw.loadUnaligned(fromByteOffset: position * 2, as: UInt16.self))
                    : raw.loadUnaligned(fromByteOffset: position * 4, as: UInt32.self)
            }
        }
        return (positions, indices)
    }

    /// The texture coordinates and triangles of the first mesh of a level file.
    private func levelTextureCoordinates(_ url: URL) throws -> (uvs: [SIMD2<Float>], indices: [UInt32]) {
        let asset = try NativeFormatLoader().loadAssetSync(from: url)
        let primitive = try XCTUnwrap(asset.nodes.flatMap(\.primitives).first)
        let uvs: [SIMD2<Float>] = primitive.vertexData.withUnsafeBytes { raw in
            (0 ..< primitive.vertexCount).map { vertex in
                SIMD2<Float>(
                    Float(Float16(bitPattern: raw.loadUnaligned(fromByteOffset: vertex * 32 + 20, as: UInt16.self))),
                    Float(Float16(bitPattern: raw.loadUnaligned(fromByteOffset: vertex * 32 + 22, as: UInt16.self)))
                )
            }
        }
        return try (uvs, levelGeometry(url, mesh: 0).indices)
    }

    private func area(positions: [SIMD3<Float>], indices: [UInt32]) -> Float {
        stride(from: 0, to: indices.count, by: 3).reduce(Float(0)) { total, start in
            let a = positions[Int(indices[start])]
            let b = positions[Int(indices[start + 1])]
            let c = positions[Int(indices[start + 2])]
            return total + 0.5 * simd_length(simd_cross(b - a, c - a))
        }
    }

    /// Connected pieces, joining vertices at the same position.
    private func componentCount(positions: [SIMD3<Float>], indices: [UInt32]) -> Int {
        var firstAtPosition: [PositionKey: Int] = [:]
        var first = [Int](repeating: 0, count: positions.count)
        for index in positions.indices {
            let key = PositionKey(positions[index])
            if let existing = firstAtPosition[key] {
                first[index] = existing
            } else {
                firstAtPosition[key] = index
                first[index] = index
            }
        }
        var parent = Array(0 ..< positions.count)
        func find(_ start: Int) -> Int {
            var node = start
            while parent[node] != node {
                parent[node] = parent[parent[node]]
                node = parent[node]
            }
            return node
        }
        for start in stride(from: 0, to: indices.count, by: 3) {
            let a = find(first[Int(indices[start])])
            for corner in 1 ... 2 {
                let other = find(first[Int(indices[start + corner])])
                if other != a {
                    parent[other] = a
                }
            }
        }
        return Set(indices.map { find(first[Int($0)]) }).count
    }

    /// The share of the triangles whose first corner lies in each octant around the origin.
    private func octantShares(positions: [SIMD3<Float>], indices: [UInt32]) -> [Float] {
        var counts = [Float](repeating: 0, count: 8)
        for start in stride(from: 0, to: indices.count, by: 3) {
            let point = positions[Int(indices[start])]
            counts[(point.x > 0 ? 1 : 0) | (point.y > 0 ? 2 : 0) | (point.z > 0 ? 4 : 0)] += 1
        }
        let total = max(counts.reduce(0, +), 1)
        return counts.map { $0 / total }
    }
}

private struct PositionKey: Hashable {
    let x: UInt32
    let y: UInt32
    let z: UInt32

    init(_ position: SIMD3<Float>) {
        x = position.x.bitPattern
        y = position.y.bitPattern
        z = position.z.bitPattern
    }
}

// MARK: - Models for the tests

/// One mesh of a test model: positions, normals and triangles.
struct LODTestMesh {
    var positions: [SIMD3<Float>]
    var normals: [SIMD3<Float>]
    var indices: [UInt32]
    var material: UInt32 = 0
    /// Texture coordinates per vertex; all zero when empty.
    var uvs: [SIMD2<Float>] = []

    var vertexData: Data {
        let writer = UntoldBinaryWriter()
        for (index, (position, normal)) in zip(positions, normals).enumerated() {
            let uv = uvs.isEmpty ? SIMD2<Float>(0, 0) : uvs[index]
            UntoldPBRStaticVertexV1(
                position: position,
                normalPacked: UntoldVertexPacking.packNormal(normal),
                tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
                uv0: SIMD2<UInt16>(Float16(uv.x).bitPattern, Float16(uv.y).bitPattern)
            ).encode(to: writer)
        }
        return writer.data
    }

    /// A wavy surface unwrapped into `islands` x `islands` separate squares of the
    /// texture: the vertices on the lines between them exist once per island, at the
    /// same position with different texture coordinates.
    static func unwrappedSurface(cells: Int, islands: Int, material: UInt32 = 0) -> LODTestMesh {
        precondition(cells % islands == 0)
        let surface = wavySurface(cells: cells)
        let cellsPerIsland = cells / islands
        var mesh = LODTestMesh(positions: [], normals: [], indices: [], material: material)
        for islandRow in 0 ..< islands {
            for islandColumn in 0 ..< islands {
                let base = UInt32(mesh.positions.count)
                for row in 0 ... cellsPerIsland {
                    for column in 0 ... cellsPerIsland {
                        let source = (islandRow * cellsPerIsland + row) * (cells + 1) + islandColumn * cellsPerIsland + column
                        mesh.positions.append(surface.positions[source])
                        mesh.normals.append(surface.normals[source])
                        // Each island keeps clear of its neighbours in the texture.
                        mesh.uvs.append(SIMD2<Float>(
                            (Float(islandColumn) + 0.1 + 0.8 * Float(column) / Float(cellsPerIsland)) / Float(islands),
                            (Float(islandRow) + 0.1 + 0.8 * Float(row) / Float(cellsPerIsland)) / Float(islands)
                        ))
                    }
                }
                let stride = UInt32(cellsPerIsland + 1)
                for row in 0 ..< UInt32(cellsPerIsland) {
                    for column in 0 ..< UInt32(cellsPerIsland) {
                        let corner = base + row * stride + column
                        mesh.indices += [corner, corner + stride, corner + 1, corner + 1, corner + stride, corner + stride + 1]
                    }
                }
            }
        }
        return mesh
    }

    /// The island of `unwrappedSurface(cells:islands:)` a texture coordinate lies in.
    static func island(of uv: SIMD2<Float>, islands: Int) -> Int {
        Int(uv.y * Float(islands)) * islands + Int(uv.x * Float(islands))
    }

    /// A square of `cells` x `cells` quads in the XZ plane with gentle hills, shared
    /// vertices and smooth normals: a connected surface the simplifier can reduce.
    static func wavySurface(
        cells: Int,
        origin: SIMD2<Float> = SIMD2<Float>(-5, -5),
        size: SIMD2<Float> = SIMD2<Float>(10, 10),
        offset: SIMD3<Float> = .zero,
        material: UInt32 = 0
    ) -> LODTestMesh {
        func height(_ x: Float, _ z: Float) -> Float {
            0.4 * sin(x * 0.9) * cos(z * 0.7)
        }
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        for row in 0 ... cells {
            for column in 0 ... cells {
                // Exact at both ends, so two surfaces that meet share their border bit for bit.
                let x = column == cells ? origin.x + size.x : origin.x + size.x * Float(column) / Float(cells)
                let z = row == cells ? origin.y + size.y : origin.y + size.y * Float(row) / Float(cells)
                positions.append(SIMD3<Float>(x, height(x, z), z) + offset)
                let slopeX = 0.4 * 0.9 * cos(x * 0.9) * cos(z * 0.7)
                let slopeZ = -0.4 * 0.7 * sin(x * 0.9) * sin(z * 0.7)
                normals.append(simd_normalize(SIMD3<Float>(-slopeX, 1, -slopeZ)))
            }
        }
        var indices: [UInt32] = []
        let stride = UInt32(cells + 1)
        for row in 0 ..< UInt32(cells) {
            for column in 0 ..< UInt32(cells) {
                let corner = row * stride + column
                indices += [corner, corner + stride, corner + 1, corner + 1, corner + stride, corner + stride + 1]
            }
        }
        return LODTestMesh(positions: positions, normals: normals, indices: indices, material: material)
    }

    /// `count` small square cards of `cellsPerCard` x `cellsPerCard` quads, each its own
    /// piece, scattered through a ball of `radius` at random orientations.
    static func cards(count: Int, cellsPerCard: Int, cardSize: Float, radius: Float, seed: UInt64) -> LODTestMesh {
        var generator = SplitMix64(state: seed)
        var mesh = LODTestMesh(positions: [], normals: [], indices: [])
        for _ in 0 ..< count {
            var center: SIMD3<Float>
            repeat {
                center = SIMD3<Float>(generator.unit(), generator.unit(), generator.unit()) * 2 - 1
            } while simd_length(center) > 1
            center *= radius
            let normal = simd_normalize(SIMD3<Float>(generator.unit(), generator.unit(), generator.unit()) * 2 - 1 + SIMD3<Float>(0, 0.01, 0))
            let helper = abs(normal.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
            let tangent = simd_normalize(simd_cross(helper, normal))
            let bitangent = simd_cross(normal, tangent)

            let base = UInt32(mesh.positions.count)
            for row in 0 ... cellsPerCard {
                for column in 0 ... cellsPerCard {
                    let u = Float(column) / Float(cellsPerCard) - 0.5
                    let v = Float(row) / Float(cellsPerCard) - 0.5
                    mesh.positions.append(center + (tangent * u + bitangent * v) * cardSize)
                    mesh.normals.append(normal)
                }
            }
            let stride = UInt32(cellsPerCard + 1)
            for row in 0 ..< UInt32(cellsPerCard) {
                for column in 0 ..< UInt32(cellsPerCard) {
                    let corner = base + row * stride + column
                    mesh.indices += [corner, corner + stride, corner + 1, corner + 1, corner + stride, corner + stride + 1]
                }
            }
        }
        return mesh
    }

    static func merged(_ meshes: [LODTestMesh]) -> LODTestMesh {
        var result = LODTestMesh(positions: [], normals: [], indices: [], material: meshes.first?.material ?? 0)
        for mesh in meshes {
            let base = UInt32(result.positions.count)
            result.positions += mesh.positions
            result.normals += mesh.normals
            result.indices += mesh.indices.map { $0 + base }
        }
        return result
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A value in 0 ..< 1.
    mutating func unit() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }
}

/// A static model as the exporter cooks one: an entity and a mesh record per mesh, a
/// material per material index, no textures.
struct LODTestModel {
    var meshes: [LODTestMesh]
    var compressGeometry = false
    /// The materials that read a base colour texture.
    var texturedMaterials: Set<UInt32> = []

    func write(to directory: URL, name: String) throws -> URL {
        let url = directory.appendingPathComponent(name).appendingPathExtension("untold")
        try data().write(to: url)
        return url
    }

    func data() throws -> Data {
        let strings = UntoldBinaryWriter()
        func string(_ value: String) -> UInt32 {
            let offset = UInt32(strings.count)
            strings.writeNullTerminatedUTF8(value)
            return offset
        }

        var vertexChunk = Data()
        var indexChunk = Data()
        var entities: [UntoldEntityRecordV1] = []
        var records: [UntoldMeshRecordV1] = []
        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for (index, mesh) in meshes.enumerated() {
            let bounds = UntoldAABB(
                min: mesh.positions.reduce(SIMD3<Float>(repeating: .greatestFiniteMagnitude), simd_min),
                max: mesh.positions.reduce(SIMD3<Float>(repeating: -.greatestFiniteMagnitude), simd_max)
            )
            lower = simd_min(lower, bounds.min)
            upper = simd_max(upper, bounds.max)

            let usesShortIndices = mesh.positions.count <= 65536
            let vertexOffset = vertexChunk.count
            let indexOffset = indexChunk.count
            vertexChunk.append(mesh.vertexData)
            let indexWriter = UntoldBinaryWriter()
            for vertexIndex in mesh.indices {
                if usesShortIndices {
                    indexWriter.writeUInt16LE(UInt16(vertexIndex))
                } else {
                    indexWriter.writeUInt32LE(vertexIndex)
                }
            }
            indexChunk.append(indexWriter.data)

            entities.append(UntoldEntityRecordV1(
                entityId: UInt32(index),
                nameOffset: string("part_\(index)"),
                firstMeshRecordIndex: UInt32(index),
                meshRecordCount: 1,
                localBounds: bounds,
                worldBounds: bounds
            ))
            records.append(UntoldMeshRecordV1(
                entityId: UInt32(index),
                meshNameOffset: string("mesh_\(index)"),
                materialIndex: mesh.material,
                indexType: usesShortIndices ? .uint16 : .uint32,
                vertexCount: UInt32(mesh.positions.count),
                indexCount: UInt32(mesh.indices.count),
                vertexStrideBytes: 32,
                vertexDataOffset: UInt64(vertexOffset),
                indexDataOffset: UInt64(indexOffset),
                vertexDataSizeBytes: UInt64(vertexChunk.count - vertexOffset),
                indexDataSizeBytes: UInt64(indexChunk.count - indexOffset),
                estimatedGPUBytes: UInt64(vertexChunk.count - vertexOffset + indexChunk.count - indexOffset),
                localBounds: bounds
            ))
        }
        let materialCount = Int((meshes.map(\.material).max() ?? 0) + 1)
        let materials = (0 ..< materialCount).map { index in
            UntoldMaterialRecordV1(
                nameOffset: string("material_\(index)"),
                baseColorTextureIndex: texturedMaterials.contains(UInt32(index)) ? 0 : UntoldFormat.invalidIndex
            )
        }
        var textures: [UntoldTextureRefRecordV1] = []
        if !texturedMaterials.isEmpty {
            let name = string("albedo.png")
            textures.append(UntoldTextureRefRecordV1(nameOffset: name, uriOffset: name, textureFormat: .rgba8, width: 16, height: 16, mipCount: 1))
        }

        func table(_ values: [some UntoldBinaryEncodable]) -> Data {
            let writer = UntoldBinaryWriter()
            for value in values {
                value.encode(to: writer)
            }
            return writer.data
        }
        /// A raw LZ4 block, as the exporter writes with --compress-geometry.
        func geometry(_ bytes: Data) -> (Data, UntoldCompressionType) {
            guard compressGeometry else { return (bytes, .none) }
            var output = Data(count: bytes.count + 1024)
            let written = output.withUnsafeMutableBytes { destination in
                bytes.withUnsafeBytes { source in
                    compression_encode_buffer(
                        destination.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        destination.count,
                        source.baseAddress!.assumingMemoryBound(to: UInt8.self),
                        source.count,
                        nil,
                        COMPRESSION_LZ4_RAW
                    )
                }
            }
            return (output.prefix(written), .lz4)
        }
        let (storedVertices, vertexCompression) = geometry(vertexChunk)
        let (storedIndices, indexCompression) = geometry(indexChunk)
        // (type, stored bytes, compression, uncompressed size, element count)
        let payloads: [(UntoldChunkType, Data, UntoldCompressionType, Int, Int)] = [
            (.stringTable, strings.data, .none, strings.count, 0),
            (.entityTable, table(entities), .none, table(entities).count, entities.count),
            (.meshTable, table(records), .none, table(records).count, records.count),
            (.materialTable, table(materials), .none, table(materials).count, materials.count),
            (.textureTable, table(textures), .none, table(textures).count, textures.count),
            (.vertexData, storedVertices, vertexCompression, vertexChunk.count, 0),
            (.indexData, storedIndices, indexCompression, indexChunk.count, 0),
        ]

        var header = UntoldFileHeaderV1(
            fileType: .tile,
            chunkCount: UInt32(payloads.count),
            meshCount: UInt32(records.count),
            materialCount: UInt32(materials.count),
            textureRefCount: UInt32(textures.count),
            entityCount: UInt32(entities.count),
            vertexLayout: .pbrStaticV1,
            worldBounds: UntoldAABB(min: lower, max: upper)
        )
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        let alignment = Int(UntoldFormat.fileAlignment)
        var offset = headerWriter.count + 40 * payloads.count
        var chunkEntries: [UntoldChunkEntryV1] = []
        for (chunkType, stored, compression, uncompressedSize, elementCount) in payloads {
            offset += (alignment - offset % alignment) % alignment
            chunkEntries.append(UntoldChunkEntryV1(
                chunkType: chunkType,
                compressionType: compression,
                fileOffset: UInt64(offset),
                compressedSize: UInt64(stored.count),
                uncompressedSize: UInt64(uncompressedSize),
                elementCount: UInt32(elementCount)
            ))
            offset += stored.count
        }

        let body = UntoldBinaryWriter()
        header.encode(to: body)
        for entry in chunkEntries {
            entry.encode(to: body)
        }
        for (_, stored, _, _, _) in payloads {
            body.align(to: alignment)
            body.writeData(stored)
        }
        var data = body.data
        header.contentHash = try Array(UntoldFormat.contentHash(of: chunkEntries, in: data))
        let hashed = UntoldBinaryWriter()
        header.encode(to: hashed)
        data.replaceSubrange(0 ..< hashed.count, with: hashed.data)
        return data
    }
}
