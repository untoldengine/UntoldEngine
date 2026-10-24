//
//  SceneReloadPackLODTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Issue #1326: saving and reloading a scene used to drop three things the pack loader
// set up -- the shared builds of a model placed many times, the LOD chain of a
// multi-node model (so its parts switch level together), and
// LODComponent.selectsByScreenSize/screenSizeRadius (the serializer never wrote them).

import Foundation
import simd
@testable import UntoldEngine
@testable import UntoldEngineMeshCook
import XCTest

final class SceneReloadPackLODTests: BaseRenderSetup {
    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        LODSystem.shared.reset()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SceneReloadPackLODTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        LODSystem.shared.reset()
        destroyAllEntities()
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try await super.tearDown()
    }

    override func initializeAssets() {}

    private struct Placement {
        var name: String
        var asset: String
        var path: String
        var position = SIMD3<Float>(0, 0, 0)
        var scale: Float = 1
    }

    /// Same manifest-writing helper as UntoldPackLODRenderTests: copies a bundled test
    /// model to its path under tempRoot, writes a manifest placing it, and cooks its
    /// LOD chain. The pack manifest stays on disk at tempRoot, which is what lets
    /// packLODChain(forModelAt:) find it again on reload.
    private func writePack(_ placements: [Placement]) throws -> URL {
        var models: [[String: Any]] = []
        for placement in placements {
            let source = try XCTUnwrap(
                LoadingSystem.shared.resourceURL(forResource: placement.asset, withExtension: "untold"),
                "bundled \(placement.asset).untold not found"
            )
            let destination = tempRoot.appendingPathComponent(placement.path)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: source, to: destination)
            }
            let scale = Double(placement.scale)
            models.append([
                "displayName": placement.name,
                "path": placement.path,
                "transform": [
                    [scale, 0, 0, Double(placement.position.x)],
                    [0, scale, 0, Double(placement.position.y)],
                    [0, 0, scale, Double(placement.position.z)],
                    [0, 0, 0, 1],
                ],
            ])
        }
        let manifest: [String: Any] = ["formatVersion": 1, "sourceAsset": "Site.blend", "models": models]
        let packURL = tempRoot.appendingPathComponent("Site").appendingPathExtension("untoldpack")
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted]).write(to: packURL)
        let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL, options: UntoldMeshLODOptions(minimumTriangles: 0))
        XCTAssertTrue(report.failures.isEmpty)
        return packURL
    }

    private func loadPack(_ packURL: URL) async throws -> (root: EntityID, children: [String: EntityID]) {
        let rootId = createEntity()
        let expectation = expectation(description: "pack load completes")
        setEntityMeshAsync(entityId: rootId, filename: packURL.deletingPathExtension().path, withExtension: "untoldpack") { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 20.0)
        let scenegraph = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: rootId))
        return (rootId, Dictionary(uniqueKeysWithValues: scenegraph.children.map { (getEntityName(entityId: $0), $0) }))
    }

    /// Serializes the scene, destroys every entity, and deserializes it back, exactly
    /// as the editor's save-then-reload does. `.sync` to keep the tests deterministic
    /// (addLODLevel and loadEntityMeshAsync still run asynchronously underneath).
    private func reload(timeout: TimeInterval = 20.0) async throws {
        let sceneData = serializeScene()
        destroyAllEntities()
        let done = expectation(description: "scene reload completes")
        deserializeScene(sceneData: sceneData, meshLoadingMode: .asyncDefault, completion: { done.fulfill() })
        await fulfillment(of: [done], timeout: timeout)
    }

    private func lod(_ entityId: EntityID) throws -> LODComponent {
        try XCTUnwrap(scene.get(component: LODComponent.self, for: entityId), "entity \(entityId) has no LODComponent")
    }

    private func identities(_ meshes: [Mesh]) -> [ObjectIdentifier] {
        meshes.map { ObjectIdentifier($0.metalKitMesh) }
    }

    private func entityNamed(_ name: String) throws -> EntityID {
        for entityId in getAllGameEntities() where getEntityName(entityId: entityId) == name {
            return entityId
        }
        throw XCTSkip("entity '\(name)' not found after reload")
    }

    // MARK: - selectsByScreenSize / screenSizeRadius round-trip (a single-node LOD entity)

    func testSelectsByScreenSizeAndScreenSizeRadiusSurviveReload() async throws {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "Prop")
        registerTransformComponent(entityId: entityId)
        setEntityLodComponent(entityId: entityId)

        let assetURL = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "ball", withExtension: "untold"))
        let added = expectation(description: "LOD level added")
        addLODLevel(entityId: entityId, lodIndex: 0, fileName: assetURL.deletingPathExtension().lastPathComponent, withExtension: "untold", maxDistance: 100) { success in
            XCTAssertTrue(success)
            added.fulfill()
        }
        await fulfillment(of: [added], timeout: 10.0)

        let before = try lod(entityId)
        before.selectsByScreenSize = true
        before.screenSizeRadius = 1.23

        try await reload()

        let reloaded = try entityNamed("Prop")
        let after = try lod(reloaded)
        XCTAssertTrue(after.selectsByScreenSize)
        XCTAssertEqual(after.screenSizeRadius, 1.23, accuracy: 1e-5)
    }

    // MARK: - Multi-node pack model: parts keep their chain and switch together after reload

    func testMultiNodeModelKeepsItsLODChainAndScreenSizeSwitchingAfterReload() async throws {
        let packURL = try writePack([Placement(name: "Stadium", asset: "stadium", path: "Stadium/Stadium.untold")])
        let (_, children) = try await loadPack(packURL)
        let stadium = try XCTUnwrap(children["Stadium"])
        let partsBefore = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: stadium)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
        XCTAssertEqual(partsBefore.count, 7)
        let levelCountBefore = try lod(partsBefore[0]).lodLevels.count
        let partNames = Set(partsBefore.map { getEntityName(entityId: $0) })

        try await reload()

        let stadiumAfter = try entityNamed("Stadium")
        let partsAfter = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: stadiumAfter)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
        XCTAssertEqual(Set(partsAfter.map { getEntityName(entityId: $0) }), partNames, "every part came back")

        var firstSwitch: Float?
        for part in partsAfter {
            let component = try lod(part)
            XCTAssertTrue(component.selectsByScreenSize, getEntityName(entityId: part))
            XCTAssertGreaterThan(component.screenSizeRadius, 0, getEntityName(entityId: part))
            XCTAssertEqual(component.lodLevels.count, levelCountBefore, getEntityName(entityId: part))
            // The parts of a model change level together: the distances come from the model's size.
            XCTAssertEqual(component.lodLevels[0].maxDistance, firstSwitch ?? component.lodLevels[0].maxDistance, accuracy: 1e-2)
            firstSwitch = component.lodLevels[0].maxDistance
        }
    }

    // MARK: - Shared builds: repeated placements of one multi-node model share meshes after reload

    func testRepeatedMultiNodePlacementsShareMeshesAfterReload() async throws {
        let packURL = try writePack([
            Placement(name: "StadiumA", asset: "stadium", path: "Stadium/Stadium.untold"),
            Placement(name: "StadiumB", asset: "stadium", path: "Stadium/Stadium.untold", position: SIMD3<Float>(50, 0, 0)),
        ])
        _ = try await loadPack(packURL)

        try await reload()

        let a = try entityNamed("StadiumA")
        let b = try entityNamed("StadiumB")
        let partsA = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: a)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
            .sorted { getEntityName(entityId: $0) < getEntityName(entityId: $1) }
        let partsB = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: b)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
            .sorted { getEntityName(entityId: $0) < getEntityName(entityId: $1) }
        XCTAssertEqual(partsA.count, partsB.count)
        XCTAssertGreaterThan(partsA.count, 0)

        for (partA, partB) in zip(partsA, partsB) {
            let renderA = try XCTUnwrap(scene.get(component: RenderComponent.self, for: partA))
            let renderB = try XCTUnwrap(scene.get(component: RenderComponent.self, for: partB))
            XCTAssertEqual(identities(renderA.mesh), identities(renderB.mesh), "the two placements' base meshes are the same build after reload")

            let levelsA = try lod(partA).lodLevels
            let levelsB = try lod(partB).lodLevels
            XCTAssertEqual(levelsA.count, levelsB.count)
            for index in levelsA.indices {
                XCTAssertEqual(identities(levelsA[index].mesh), identities(levelsB[index].mesh), "level \(index) is shared across placements after reload")
            }
        }
    }
}
