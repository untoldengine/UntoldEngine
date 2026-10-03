//
//  UntoldPackRenderTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class UntoldPackRenderTests: BaseRenderSetup {
    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldPackRenderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try await super.tearDown()
    }

    override func initializeAssets() {}

    /// Copies the bundled "ball" test asset to `path` under tempRoot so a real .untold
    /// binary backs each pack model, and writes a .untoldpack manifest referencing them.
    private func writePack(models: [(displayName: String, path: String, translationX: Float)]) throws -> URL {
        guard let ballURL = LoadingSystem.shared.resourceURL(forResource: "ball", withExtension: "untold") else {
            XCTFail("bundled ball.untold test asset not found")
            throw CocoaError(.fileNoSuchFile)
        }

        let modelsJSON = models.map { model in
            let destination = tempRoot.appendingPathComponent(model.path)
            try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: ballURL, to: destination)

            return """
            {
              "displayName": "\(model.displayName)",
              "path": "\(model.path)",
              "transform": [
                [1.0, 0.0, 0.0, \(model.translationX)],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
              ]
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
          "formatVersion": 1,
          "sourceAsset": "Robot.blend",
          "models": [\(modelsJSON)]
        }
        """
        let packURL = tempRoot.appendingPathComponent("Robot").appendingPathExtension("untoldpack")
        try Data(json.utf8).write(to: packURL)
        return packURL
    }

    func testSetEntityMeshAsyncRoutesUntoldpackToOneChildEntityPerModelWithTransform() async throws {
        let packURL = try writePack(models: [
            (displayName: "Body", path: "Body/Body.untold", translationX: 0.0),
            (displayName: "Arm", path: "Arm/Arm.untold", translationX: 2.5),
        ])

        let rootId = createEntity()
        let expectation = expectation(description: "pack load completes")
        setEntityMeshAsync(entityId: rootId, filename: packURL.deletingPathExtension().path, withExtension: "untoldpack") { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)

        guard let scenegraph = scene.get(component: ScenegraphComponent.self, for: rootId) else {
            XCTFail("root entity missing ScenegraphComponent")
            return
        }
        XCTAssertEqual(scenegraph.children.count, 2)

        let armId = try XCTUnwrap(scenegraph.children.first { getEntityName(entityId: $0) == "Arm" })
        XCTAssertEqual(getPosition(entityId: armId).x, 2.5, accuracy: 0.0001)
        XCTAssertTrue(hasComponent(entityId: armId, componentType: RenderComponent.self))
    }

    /// Loads a pack and returns its children by display name.
    private func loadPack(_ packURL: URL) async throws -> [String: EntityID] {
        let rootId = createEntity()
        let expectation = expectation(description: "pack load completes")
        setEntityMeshAsync(entityId: rootId, filename: packURL.deletingPathExtension().path, withExtension: "untoldpack") { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 10.0)
        let scenegraph = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: rootId))
        return Dictionary(uniqueKeysWithValues: scenegraph.children.map { (getEntityName(entityId: $0) ?? "", $0) })
    }

    private func meshIdentity(_ entityId: EntityID) throws -> ObjectIdentifier {
        let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: entityId))
        let mesh = try XCTUnwrap(render.mesh.first)
        return ObjectIdentifier(mesh.metalKitMesh)
    }

    func testPlacementsOfOneFileShareItsGPUMeshes() async throws {
        // Two placements of one file (the exporter writes a repeated model once) and one
        // of another file with the same content.
        let packURL = try writePack(models: [
            (displayName: "Tree A", path: "Tree/Tree.untold", translationX: 0.0),
            (displayName: "Tree B", path: "Tree/Tree.untold", translationX: 5.0),
            (displayName: "Rock", path: "Rock/Rock.untold", translationX: 10.0),
        ])

        let children = try await loadPack(packURL)

        let treeA = try XCTUnwrap(children["Tree A"])
        let treeB = try XCTUnwrap(children["Tree B"])
        let rock = try XCTUnwrap(children["Rock"])
        XCTAssertEqual(try meshIdentity(treeA), try meshIdentity(treeB), "both placements draw the same GPU buffers")
        XCTAssertNotEqual(try meshIdentity(treeA), try meshIdentity(rock), "another file is built on its own")
        XCTAssertEqual(getPosition(entityId: treeB).x, 5.0, accuracy: 0.0001, "each placement keeps its own transform")
    }

    func testAMaterialEditOnOnePlacementLeavesTheOtherAlone() async throws {
        let packURL = try writePack(models: [
            (displayName: "Tree A", path: "Tree/Tree.untold", translationX: 0.0),
            (displayName: "Tree B", path: "Tree/Tree.untold", translationX: 5.0),
        ])
        let children = try await loadPack(packURL)
        let treeA = try XCTUnwrap(children["Tree A"])
        let treeB = try XCTUnwrap(children["Tree B"])
        let before = scene.get(component: RenderComponent.self, for: treeB)?.mesh.first?.submeshes.first?.material?.roughnessValue

        updateMaterialRoughness(entityId: treeA, roughness: 0.123)

        XCTAssertEqual(scene.get(component: RenderComponent.self, for: treeA)?.mesh.first?.submeshes.first?.material?.roughnessValue, 0.123)
        XCTAssertEqual(scene.get(component: RenderComponent.self, for: treeB)?.mesh.first?.submeshes.first?.material?.roughnessValue, before)
    }

    // MARK: - Memory budget

    /// The vertex and index buffers behind an entity's meshes, each once.
    private func bufferBytes(_ entityIds: [EntityID]) throws -> Int {
        var seen = Set<ObjectIdentifier>()
        var bytes = 0
        for entityId in entityIds {
            let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: entityId))
            for allocation in meshBufferAllocations(of: render.mesh) where seen.insert(ObjectIdentifier(allocation.object)).inserted {
                bytes += allocation.bytes
            }
        }
        return bytes
    }

    func testPlacementsOfOneFileAreInTheMemoryBudgetOnce() async throws {
        // Start from an empty ledger: entities of earlier tests leave it only when their
        // destruction is finalized.
        MemoryBudgetManager.shared.clear()
        let packURL = try writePack(models: [
            (displayName: "Tree A", path: "Tree/Tree.untold", translationX: 0.0),
            (displayName: "Tree B", path: "Tree/Tree.untold", translationX: 5.0),
            (displayName: "Tree C", path: "Tree/Tree.untold", translationX: 10.0),
            (displayName: "Rock", path: "Rock/Rock.untold", translationX: 15.0),
        ])

        let children = try await loadPack(packURL)

        let trees = try ["Tree A", "Tree B", "Tree C"].map { try XCTUnwrap(children[$0]) }
        let rock = try XCTUnwrap(children["Rock"])
        let treeBytes = try bufferBytes(trees)
        let rockBytes = try bufferBytes([rock])
        XCTAssertGreaterThan(treeBytes, 0)
        XCTAssertEqual(treeBytes, try bufferBytes([trees[0]]), "the three placements hold one set of buffers")
        func tracked() -> Int {
            MemoryBudgetManager.shared.getStats().meshMemoryUsed
        }
        XCTAssertEqual(tracked(), treeBytes + rockBytes, "the budget holds the tree's buffers once, not once per placement")
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: trees[0]), 0, "evicting one of three placements frees nothing")

        // The buffers stay in the budget while a placement holds them, and leave with the last.
        destroyEntity(entityId: trees[0])
        destroyEntity(entityId: trees[1])
        finalizePendingDestroys()
        XCTAssertEqual(tracked(), treeBytes + rockBytes)
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: trees[2]), treeBytes)

        destroyEntity(entityId: trees[2])
        finalizePendingDestroys()
        XCTAssertEqual(tracked(), rockBytes)
    }

    // MARK: - Image textures

    private func makeTexture() throws -> MTLTexture {
        let device = try XCTUnwrap(renderInfo.device)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 4, height: 4, mipmapped: false)
        return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var value = 0

        func increment() {
            lock.withLock { value += 1 }
        }

        var count: Int {
            lock.withLock { value }
        }
    }

    func testLoadedImageTexturesAreSharedWhileInUseAndReleasedAfter() throws {
        let key = LoadedTextureCache.key(url: tempRoot.appendingPathComponent("shared.png"), isSRGB: true)
        let loads = Counter()
        try autoreleasepool {
            let made = try makeTexture()
            let first = LoadedTextureCache.shared.texture(for: key) {
                loads.increment()
                return made
            }
            let second = LoadedTextureCache.shared.texture(for: key) {
                loads.increment()
                return nil
            }
            XCTAssertTrue(first === made)
            XCTAssertTrue(second === made, "a material that asks while another holds the texture gets the same one")
        }
        XCTAssertEqual(loads.count, 1)

        // Nothing holds it any more: the cache lets it go, and the next material loads it.
        let again = LoadedTextureCache.shared.texture(for: key) {
            loads.increment()
            return nil
        }
        XCTAssertNil(again)
        XCTAssertEqual(loads.count, 2, "the cache does not keep a texture no material holds")
    }

    func testAnImageThatSeveralThreadsAskForAtOnceIsDecodedOnce() throws {
        // A pack loads eight models at a time, and they share the images of its Textures folder.
        let key = LoadedTextureCache.key(url: tempRoot.appendingPathComponent("atlas.png"), isSRGB: true)
        let loads = Counter()
        let made = try makeTexture()
        let results = UnsafeMutablePointer<Unmanaged<AnyObject>?>.allocate(capacity: 8)
        results.initialize(repeating: nil, count: 8)
        defer { results.deallocate() }

        DispatchQueue.concurrentPerform(iterations: 8) { index in
            let texture = LoadedTextureCache.shared.texture(for: key) {
                loads.increment()
                Thread.sleep(forTimeInterval: 0.05)
                return made
            }
            results[index] = texture.map { Unmanaged.passRetained($0 as AnyObject) }
        }

        XCTAssertEqual(loads.count, 1, "the threads that arrive while it is decoded wait for it")
        for index in 0 ..< 8 {
            let texture = results[index]?.takeRetainedValue()
            XCTAssertTrue(texture === made, "thread \(index)")
        }
    }

    func testAnImageThatFailsToLoadIsTriedAgain() throws {
        let key = LoadedTextureCache.key(url: tempRoot.appendingPathComponent("missing.png"), isSRGB: false)
        let loads = Counter()
        let made = try makeTexture()

        let failed = LoadedTextureCache.shared.texture(for: key) {
            loads.increment()
            return nil
        }
        let loaded = LoadedTextureCache.shared.texture(for: key) {
            loads.increment()
            return made
        }

        XCTAssertNil(failed)
        XCTAssertTrue(loaded === made)
        XCTAssertEqual(loads.count, 2)
    }
}
