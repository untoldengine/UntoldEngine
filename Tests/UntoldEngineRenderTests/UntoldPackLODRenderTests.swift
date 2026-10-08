//
//  UntoldPackLODRenderTests.swift
//  UntoldEngine
//
//  Loading a `.untoldpack` whose manifest carries LOD chains: the levels each placement
//  gets, where they switch, what the placements share and what stays their own.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
@testable import UntoldEngineMeshCook
import XCTest

final class UntoldPackLODRenderTests: BaseRenderSetup {
    private var tempRoot: URL!

    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        LODSystem.shared.reset()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldPackLODRenderTests-\(UUID().uuidString)", isDirectory: true)
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
        /// A bundled test model: "ball" (one mesh, 180 triangles) or "stadium" (seven).
        var asset: String
        var path: String
        var position = SIMD3<Float>(0, 0, 0)
        var scale: Float = 1
    }

    /// Copies the bundled models to their paths under tempRoot, writes a manifest that
    /// places them, and cooks the LOD chains of the pack. The bundled models are small,
    /// so the cook is asked to chain models of any size.
    private func writePack(_ placements: [Placement], cookChains: Bool = true) throws -> URL {
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
        if cookChains {
            let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL, options: UntoldMeshLODOptions(minimumTriangles: 0))
            XCTAssertTrue(report.failures.isEmpty)
        }
        return packURL
    }

    /// Loads a pack and returns its root and its placements by display name.
    private func loadPack(_ packURL: URL, expectSuccess: Bool = true) async throws -> (root: EntityID, children: [String: EntityID]) {
        let rootId = createEntity()
        let expectation = expectation(description: "pack load completes")
        setEntityMeshAsync(entityId: rootId, filename: packURL.deletingPathExtension().path, withExtension: "untoldpack") { success in
            XCTAssertEqual(success, expectSuccess)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 20.0)
        let scenegraph = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: rootId))
        return (rootId, Dictionary(uniqueKeysWithValues: scenegraph.children.map { (getEntityName(entityId: $0), $0) }))
    }

    private func lod(_ entityId: EntityID) throws -> LODComponent {
        try XCTUnwrap(scene.get(component: LODComponent.self, for: entityId), "entity \(entityId) has no LODComponent")
    }

    private func identities(_ meshes: [Mesh]) -> [ObjectIdentifier] {
        meshes.map { ObjectIdentifier($0.metalKitMesh) }
    }

    private func drawnMeshes(_ entityId: EntityID) throws -> [ObjectIdentifier] {
        try identities(XCTUnwrap(scene.get(component: RenderComponent.self, for: entityId)).mesh)
    }

    /// Puts the camera `distance` away from `entityId` and lets the LOD system choose.
    private func selectLOD(for entityId: EntityID, cameraAt distance: Float, camera: EntityID) {
        traverseSceneGraph()
        let center = getPosition(entityId: entityId)
        cameraLookAt(entityId: camera, eye: center + SIMD3<Float>(0, 0, distance), target: center, up: SIMD3<Float>(0, 1, 0))
        LODSystem.shared.reset()
        LODSystem.shared.update(deltaTime: 1.0 / 60.0)
    }

    private func makeCamera() -> EntityID {
        let camera = createEntity()
        createGameCamera(entityId: camera)
        CameraSystem.shared.activeCamera = camera
        return camera
    }

    // MARK: - Levels

    func testAPlacementGetsItsModelAndTheLevelsOfItsChain() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let chain = try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains?["Ball/Ball.untold"])
        XCTAssertEqual(chain.count, 3)

        let (_, children) = try await loadPack(packURL)

        let ball = try XCTUnwrap(children["Ball"])
        let component = try lod(ball)
        XCTAssertEqual(component.lodLevels.count, chain.count + 1)
        XCTAssertEqual(component.currentLOD, 0)
        XCTAssertTrue(component.levelsShareMaterials)
        XCTAssertEqual(identities(component.lodLevels[0].mesh), try drawnMeshes(ball), "level 0 is the model itself")
        XCTAssertEqual(component.lodLevels[0].url?.lastPathComponent, "Ball.untold")
        for (index, entry) in chain.enumerated() {
            let level = component.lodLevels[index + 1]
            XCTAssertEqual(level.url?.standardizedFileURL, packURL.deletingLastPathComponent().appendingPathComponent(entry.path).standardizedFileURL)
            XCTAssertEqual(level.screenPercentage, entry.screenSize)
            XCTAssertEqual(level.residencyState, .resident)
            XCTAssertEqual(level.mesh.count, 1)
            XCTAssertLessThan(
                level.mesh[0].metalKitMesh.submeshes[0].indexCount,
                component.lodLevels[index].mesh[0].metalKitMesh.submeshes[0].indexCount,
                "each level has fewer triangles than the one before"
            )
        }
    }

    func testEachLevelEndsWhereTheNextIsDetailedEnough() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let chain = try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains?["Ball/Ball.untold"])

        let (_, children) = try await loadPack(packURL)

        let levels = try lod(XCTUnwrap(children["Ball"])).lodLevels
        let model = try NativeFormatLoader().loadAssetSync(from: tempRoot.appendingPathComponent("Ball/Ball.untold"))
        let radius = boundingRadius(of: model.worldBounds)
        XCTAssertEqual(radius, Float(3).squareRoot() / 2, accuracy: 0.01, "the ball fills a cube of side 1")
        for (index, entry) in chain.enumerated() {
            let expected = lodSwitchDistance(radius: radius, screenSize: entry.screenSize, fovYDegrees: fov)
            XCTAssertEqual(levels[index].maxDistance, expected, accuracy: expected * 1e-3, "level \(index) hands over to level \(index + 1)")
        }
        XCTAssertEqual(levels.map(\.maxDistance), levels.map(\.maxDistance).sorted())
        XCTAssertEqual(levels.last?.maxDistance, .greatestFiniteMagnitude, "the last level has no end")
    }

    func testTheSwitchDistanceIsWhereTheModelCoversTheScreenSize() {
        // A sphere of radius 1 fills the viewport height at the distance where the half
        // height of the view is 1.
        let fullHeight = lodSwitchDistance(radius: 1, screenSize: 1, fovYDegrees: 90)
        XCTAssertEqual(fullHeight, 1, accuracy: 1e-5)
        XCTAssertEqual(lodSwitchDistance(radius: 1, screenSize: 0.25, fovYDegrees: 90), 4, accuracy: 1e-4)
        XCTAssertEqual(lodSwitchDistance(radius: 3, screenSize: 0.25, fovYDegrees: 90), 12, accuracy: 1e-4)
        XCTAssertEqual(lodSwitchDistance(radius: 1, screenSize: 0, fovYDegrees: 90), .greatestFiniteMagnitude)
        XCTAssertEqual(lodSwitchDistance(radius: 0, screenSize: 0.5, fovYDegrees: 90), .greatestFiniteMagnitude)
    }

    func testALargerPlacementSwitchesFartherAway() async throws {
        let packURL = try writePack([
            Placement(name: "Small", asset: "ball", path: "Ball/Ball.untold"),
            Placement(name: "Large", asset: "ball", path: "Ball/Ball.untold", position: SIMD3<Float>(20, 0, 0), scale: 3),
        ])

        let (_, children) = try await loadPack(packURL)

        let small = try lod(XCTUnwrap(children["Small"])).lodLevels
        let large = try lod(XCTUnwrap(children["Large"])).lodLevels
        XCTAssertEqual(small.count, large.count)
        for index in 0 ..< small.count - 1 {
            XCTAssertEqual(large[index].maxDistance, small[index].maxDistance * 3, accuracy: small[index].maxDistance * 3e-3)
        }
    }

    func testEveryNodeOfAModelGetsItsLevels() async throws {
        let packURL = try writePack([Placement(name: "Stadium", asset: "stadium", path: "Stadium/Stadium.untold")])
        let chain = try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains?["Stadium/Stadium.untold"])

        let (_, children) = try await loadPack(packURL)

        let stadium = try XCTUnwrap(children["Stadium"])
        let nodes = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: stadium)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
        XCTAssertEqual(nodes.count, 7)
        var firstSwitch: Float?
        for node in nodes {
            let component = try lod(node)
            XCTAssertEqual(component.lodLevels.count, chain.count + 1, getEntityName(entityId: node))
            XCTAssertEqual(identities(component.lodLevels[0].mesh), try drawnMeshes(node))
            // The parts of a model change level together: the distances come from the model's size.
            XCTAssertEqual(component.lodLevels[0].maxDistance, firstSwitch ?? component.lodLevels[0].maxDistance)
            firstSwitch = component.lodLevels[0].maxDistance
        }
    }

    // MARK: - What the placements share

    func testPlacementsOfOneModelShareTheMeshesOfEveryLevel() async throws {
        let packURL = try writePack([
            Placement(name: "Ball A", asset: "ball", path: "Ball/Ball.untold"),
            Placement(name: "Ball B", asset: "ball", path: "Ball/Ball.untold", position: SIMD3<Float>(5, 0, 0)),
            Placement(name: "Other", asset: "ball", path: "Other/Other.untold", position: SIMD3<Float>(10, 0, 0)),
        ])

        let (_, children) = try await loadPack(packURL)

        let first = try lod(XCTUnwrap(children["Ball A"])).lodLevels
        let second = try lod(XCTUnwrap(children["Ball B"])).lodLevels
        let other = try lod(XCTUnwrap(children["Other"])).lodLevels
        XCTAssertEqual(first.count, second.count)
        for index in first.indices {
            XCTAssertEqual(identities(first[index].mesh), identities(second[index].mesh), "level \(index) is built once")
            XCTAssertNotEqual(identities(first[index].mesh), identities(other[index].mesh), "another model has its own")
        }
        XCTAssertEqual(Set(first.flatMap { identities($0.mesh) }).count, first.count, "every level has buffers of its own")
    }

    func testLevelsAreDrawnWithTheModelsMaterials() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        // The level files carry a copy of the model's materials from the time of the
        // cook. Change the model's afterwards: the levels must follow the model.
        try setRoughnessFactor(0.777, inModelAt: tempRoot.appendingPathComponent("Ball/Ball.untold"))

        let (_, children) = try await loadPack(packURL)

        let levels = try lod(XCTUnwrap(children["Ball"])).lodLevels
        XCTAssertGreaterThanOrEqual(levels.count, 3)
        XCTAssertEqual(levels[0].mesh[0].submeshes[0].material?.roughnessValue, 0.777)
        for level in levels.dropFirst() {
            XCTAssertEqual(level.mesh[0].submeshes[0].material?.roughnessValue, 0.777, level.url?.lastPathComponent ?? "")
        }
    }

    /// Rewrites the roughness factor of the first material of a `.untold` file in place.
    private func setRoughnessFactor(_ roughness: Float, inModelAt url: URL) throws {
        var data = try Data(contentsOf: url)
        let decoded = try UntoldReader().readAsset(from: data)
        let table = try XCTUnwrap(decoded.chunks.first { $0.chunkType == .materialTable })
        XCTAssertEqual(table.compressionType, .none)
        // nameOffset, flags, baseColorFactor (4), emissiveFactor (3), normalScale, metallicFactor, roughnessFactor.
        let offset = Int(table.fileOffset) + 4 * 11
        withUnsafeBytes(of: roughness.bitPattern.littleEndian) { data.replaceSubrange(offset ..< offset + 4, with: $0) }
        // The header's hash covers the chunk; a zero hash is not checked.
        let hashOffset = 8 + 4 * 11 + 24 + 64
        data.replaceSubrange(hashOffset ..< hashOffset + 32, with: [UInt8](repeating: 0, count: 32))
        XCTAssertEqual(try UntoldReader().readAsset(from: data).materials.first?.roughnessFactor, roughness)
        try data.write(to: url)
    }

    // MARK: - Switching

    func testTheDistanceToThePlacementSelectsItsLevel() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let (_, children) = try await loadPack(packURL)
        let ball = try XCTUnwrap(children["Ball"])
        let component = try lod(ball)
        let camera = makeCamera()

        for (index, level) in component.lodLevels.enumerated() {
            let from = index == 0 ? 0 : component.lodLevels[index - 1].maxDistance
            let to = min(level.maxDistance, from * 4 + 10)
            selectLOD(for: ball, cameraAt: (from + to) / 2, camera: camera)

            XCTAssertEqual(component.currentLOD, index, "between \(from) and \(to)")
            XCTAssertEqual(try drawnMeshes(ball), identities(level.mesh))
        }
    }

    // MARK: - Switching by the size on screen

    /// The projection the tests draw with, for another field of view.
    private func projection(fovYDegrees: Float) -> simd_float4x4 {
        matrixPerspectiveRightHandReverseZ(
            fovyRadians: degreesToRadians(degrees: fovYDegrees),
            aspectRatio: Float(windowWidth) / Float(windowHeight),
            nearZ: near,
            farZ: far
        )
    }

    func testAPlacementSelectsItsLevelsByItsSizeOnScreen() async throws {
        let packURL = try writePack([
            Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold"),
            Placement(name: "Stadium", asset: "stadium", path: "Stadium/Stadium.untold", position: SIMD3<Float>(300, 0, 0), scale: 2),
        ])
        let (_, children) = try await loadPack(packURL)
        traverseSceneGraph()

        // A model of one node is measured by its own bounds.
        let ball = try lod(XCTUnwrap(children["Ball"]))
        XCTAssertTrue(ball.selectsByScreenSize)
        XCTAssertEqual(ball.screenSizeRadius, 0)

        // The parts of a model carry the radius of the whole model.
        let model = try NativeFormatLoader().loadAssetSync(from: tempRoot.appendingPathComponent("Stadium/Stadium.untold"))
        let stadium = try XCTUnwrap(children["Stadium"])
        let nodes = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: stadium)).children
            .filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
        XCTAssertEqual(nodes.count, 7)
        for node in nodes {
            let component = try lod(node)
            XCTAssertTrue(component.selectsByScreenSize)
            let measured = entityDistanceAndRadius(entityId: node, cameraPosition: .zero, localRadius: component.screenSizeRadius)
            let expected = boundingRadius(of: model.worldBounds) * 2
            XCTAssertEqual(measured.radius, expected, accuracy: expected * 1e-3, getEntityName(entityId: node))
        }
    }

    func testAPlacementScaledAfterTheLoadSwitchesAtItsNewSize() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let (_, children) = try await loadPack(packURL)
        let ball = try XCTUnwrap(children["Ball"])
        let component = try lod(ball)
        let camera = makeCamera()
        let firstSwitch = component.lodLevels[0].maxDistance

        selectLOD(for: ball, cameraAt: firstSwitch * 1.4, camera: camera)
        XCTAssertEqual(component.currentLOD, 1, "past the first switch")

        // Three times as large, the ball covers from there more than it did at the switch.
        scaleTo(entityId: ball, scale: simd_float3(repeating: 3))
        selectLOD(for: ball, cameraAt: firstSwitch * 1.4, camera: camera)
        XCTAssertEqual(component.currentLOD, 0)

        selectLOD(for: ball, cameraAt: firstSwitch * 3.2, camera: camera)
        XCTAssertEqual(component.currentLOD, 1, "the switch moved out three times")
        XCTAssertEqual(component.lodLevels[0].maxDistance, firstSwitch, "the distance of the load stays as it was written")
    }

    func testTheFieldOfViewMovesTheSwitchesAndTheResolutionDoesNot() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let (_, children) = try await loadPack(packURL)
        let ball = try XCTUnwrap(children["Ball"])
        let component = try lod(ball)
        let camera = makeCamera()
        let firstSwitch = component.lodLevels[0].maxDistance
        let savedProjection = renderInfo.perspectiveSpace
        let savedViewPort = renderInfo.viewPort
        defer {
            renderInfo.perspectiveSpace = savedProjection
            renderInfo.viewPort = savedViewPort
        }

        // Half the field of view magnifies by tan(fov / 2) / tan(fov / 4), a little over two.
        renderInfo.perspectiveSpace = projection(fovYDegrees: fov / 2)
        let zoom = tan(degreesToRadians(degrees: fov) / 2) / tan(degreesToRadians(degrees: fov) / 4)
        selectLOD(for: ball, cameraAt: firstSwitch * zoom * 0.95, camera: camera)
        XCTAssertEqual(component.currentLOD, 0)
        selectLOD(for: ball, cameraAt: firstSwitch * zoom * 1.15, camera: camera)
        XCTAssertEqual(component.currentLOD, 1)

        // Twice the lines under the field of view of the load: the ball covers the same
        // share of the viewport, and switches where it did.
        renderInfo.perspectiveSpace = savedProjection
        renderInfo.viewPort = simd_float2(Float(windowWidth) * 2, Float(windowHeight) * 2)
        selectLOD(for: ball, cameraAt: firstSwitch * 0.9, camera: camera)
        XCTAssertEqual(component.currentLOD, 0)
        selectLOD(for: ball, cameraAt: firstSwitch * 1.2, camera: camera)
        XCTAssertEqual(component.currentLOD, 1)
    }

    func testAViewWithoutPerspectiveSwitchesAtTheDistancesOfTheLoad() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let (_, children) = try await loadPack(packURL)
        let ball = try XCTUnwrap(children["Ball"])
        let component = try lod(ball)
        let camera = makeCamera()
        let firstSwitch = component.lodLevels[0].maxDistance
        let savedProjection = renderInfo.perspectiveSpace
        defer { renderInfo.perspectiveSpace = savedProjection }

        // Scaled, the ball would keep its model three times as far by its size on screen.
        scaleTo(entityId: ball, scale: simd_float3(repeating: 3))
        renderInfo.perspectiveSpace = simd_float4x4(diagonal: simd_float4(0.1, 0.1, 0.01, 1))

        selectLOD(for: ball, cameraAt: firstSwitch * 0.9, camera: camera)
        XCTAssertEqual(component.currentLOD, 0)
        selectLOD(for: ball, cameraAt: firstSwitch * 1.2, camera: camera)
        XCTAssertEqual(component.currentLOD, 1)
    }

    func testAMaterialEditStaysWithThePlacementThroughItsLevels() async throws {
        let packURL = try writePack([
            Placement(name: "Ball A", asset: "ball", path: "Ball/Ball.untold"),
            Placement(name: "Ball B", asset: "ball", path: "Ball/Ball.untold", position: SIMD3<Float>(500, 0, 0)),
        ])
        let (_, children) = try await loadPack(packURL)
        let edited = try XCTUnwrap(children["Ball A"])
        let untouched = try XCTUnwrap(children["Ball B"])
        let component = try lod(edited)
        let camera = makeCamera()
        let far = component.lodLevels[component.lodLevels.count - 2].maxDistance * 2
        let original = getMaterialRoughness(entityId: untouched)

        updateMaterialRoughness(entityId: edited, roughness: 0.123)
        selectLOD(for: edited, cameraAt: far, camera: camera)

        XCTAssertEqual(component.currentLOD, component.lodLevels.count - 1)
        XCTAssertEqual(getMaterialRoughness(entityId: edited), 0.123, "the coarsest level is drawn with the edited material")

        updateMaterialRoughness(entityId: edited, roughness: 0.456)
        selectLOD(for: edited, cameraAt: 0.5, camera: camera)

        XCTAssertEqual(component.currentLOD, 0)
        XCTAssertEqual(getMaterialRoughness(entityId: edited), 0.456, "an edit made on a coarse level comes back with the model")
        for level in try lod(untouched).lodLevels {
            XCTAssertEqual(level.mesh[0].submeshes[0].material?.roughnessValue, original, "the other placement keeps its own")
        }
    }

    // MARK: - Packs that are not what the manifest says

    func testALevelWhoseFileIsMissingIsLeftOut() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")])
        let chain = try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains?["Ball/Ball.untold"])
        XCTAssertEqual(chain.count, 3)
        try FileManager.default.removeItem(at: tempRoot.appendingPathComponent(chain[0].path))

        // The pack still loads: the model is there, and so are two of its levels.
        let (_, children) = try await loadPack(packURL)

        let levels = try lod(XCTUnwrap(children["Ball"])).lodLevels
        XCTAssertEqual(levels.map { $0.url?.lastPathComponent }, ["Ball.untold", "Ball_LOD2.untold", "Ball_LOD3.untold"])
        XCTAssertEqual(levels[1].screenPercentage, chain[1].screenSize)
        let model = try NativeFormatLoader().loadAssetSync(from: tempRoot.appendingPathComponent("Ball/Ball.untold"))
        let expected = lodSwitchDistance(radius: boundingRadius(of: model.worldBounds), screenSize: chain[1].screenSize, fovYDegrees: fov)
        XCTAssertEqual(levels[0].maxDistance, expected, accuracy: expected * 1e-3, "the model stays until the next level that is there")
    }

    func testAPackWithoutChainsLoadsWithoutLevels() async throws {
        let packURL = try writePack([Placement(name: "Ball", asset: "ball", path: "Ball/Ball.untold")], cookChains: false)
        XCTAssertNil(loadUntoldPack(url: packURL)?.lodChains)

        let (_, children) = try await loadPack(packURL)

        let ball = try XCTUnwrap(children["Ball"])
        XCTAssertTrue(hasComponent(entityId: ball, componentType: RenderComponent.self))
        XCTAssertFalse(hasComponent(entityId: ball, componentType: LODComponent.self))
    }
}
