//
//  NativeFormatRegistrationTests.swift
//  UntoldEngine
//
//  Verifies that `.untold` assets can flow through the public registration APIs
//  and produce renderable entities without the USD/ModelIO file-loading path.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@preconcurrency @testable import UntoldEngine
import XCTest

final class NativeFormatRegistrationTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        LoadingSystem.shared.resourceURLFn = getResourceURL
    }

    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    func testSetEntityMesh_loadsUntoldMesh() async {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "UntoldSyncEntity")

        let loadExp_entityId = expectation(description: "redplayer loaded")
        setEntityMeshAsync(entityId: entityId, filename: "redplayer", withExtension: "untold") { _ in loadExp_entityId.fulfill() }
        await fulfillment(of: [loadExp_entityId], timeout: 10)

        // The root entity always gets transform + scenegraph components.
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        // redplayer.untold is hierarchical: the skinned mesh lives on a child entity,
        // not the root. Resolve down to the entity that carries the render component.
        let renderEntityId = resolveEntityForAnimationBinding(entityId: entityId) ?? entityId
        XCTAssertTrue(hasComponent(entityId: renderEntityId, componentType: RenderComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: renderEntityId) else {
            XCTFail("RenderComponent should exist for .untold sync load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Sync .untold load should register at least one mesh")
        XCTAssertEqual(renderComponent.assetURL.pathExtension, "untold")
        XCTAssertFalse(renderComponent.assetName.isEmpty, "Sync .untold load should register an asset name")
    }

    func testSetEntityMeshAsync_loadsUntoldMesh() async {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "UntoldAsyncEntity")

        let expectation = XCTestExpectation(description: "Untold mesh loaded asynchronously")
        var loadSuccess = false

        setEntityMeshAsync(
            entityId: entityId,
            filename: "redplayer",
            withExtension: "untold"
        ) { success in
            loadSuccess = success
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertTrue(loadSuccess, "Async .untold load should succeed")
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: ScenegraphComponent.self))

        // redplayer.untold is hierarchical: the skinned mesh lives on a child entity,
        // not the root. Resolve down to the entity that carries the render component.
        let renderEntityId = resolveEntityForAnimationBinding(entityId: entityId) ?? entityId
        XCTAssertTrue(hasComponent(entityId: renderEntityId, componentType: RenderComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: renderEntityId) else {
            XCTFail("RenderComponent should exist for .untold async load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Async .untold load should register at least one mesh")
        XCTAssertEqual(renderComponent.assetURL.pathExtension, "untold")
        XCTAssertFalse(renderComponent.assetName.isEmpty, "Async .untold load should register an asset name")
        XCTAssertTrue(renderComponent.isVisible, "Async .untold load should leave the entity visible")
    }

    func testSetEntityMeshLoadsOnlyMeshAndLoadSceneAuthoredLoadsMeshAndScene() throws {
        let fixture = try makeSceneAuthoredUntoldFixture()
        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, subName in
            if name == fixture.stem, ext == "untold" {
                return fixture.url
            }
            return getResourceURL(resourceName: name, ext: ext, subName: subName)
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        // Mesh-only load — no lights or camera should appear.
        let meshRoot = createEntity()
        setEntityMesh(entityId: meshRoot, filename: fixture.stem, withExtension: "untold")

        XCTAssertNil(findEntity(named: fixture.sunName))
        XCTAssertNil(findEntity(named: fixture.spotName))
        XCTAssertNil(findEntity(named: fixture.cameraName))

        // Separate scene-authored load — lights and camera registered as top-level entities.
        let sceneExpectation = expectation(description: "scene authored loaded")
        loadSceneAuthored(filename: fixture.stem, withExtension: "untold") { _ in
            sceneExpectation.fulfill()
        }
        wait(for: [sceneExpectation], timeout: 5.0)

        let sunEntity = try XCTUnwrap(findEntity(named: fixture.sunName))
        XCTAssertEqual(LightingSystem.shared.activeDirectionalLight, sunEntity)
        let sunDirComponent = try XCTUnwrap(scene.get(component: DirectionalLightComponent.self, for: sunEntity))
        XCTAssertTrue(sunDirComponent.castsShadow)
        let sunLightComponent = try XCTUnwrap(scene.get(component: LightComponent.self, for: sunEntity))
        XCTAssertTrue(sunLightComponent.usesRadiometricUnits, "sun record's radiometric flag should decode to W/m\u{b2} strength on the directional light")
        XCTAssertEqual(sunLightComponent.intensity, 2.0, accuracy: 0.001)

        let spotEntity = try XCTUnwrap(findEntity(named: fixture.spotName))
        let spotComponent = try XCTUnwrap(scene.get(component: SpotLightComponent.self, for: spotEntity))
        XCTAssertEqual(spotComponent.innerCone, 14.0, accuracy: 0.001)
        XCTAssertEqual(spotComponent.outerCone, 36.0, accuracy: 0.001)
        XCTAssertEqual(spotComponent.radius, 0.2, accuracy: 0.001)
        XCTAssertEqual(spotComponent.range, 18.0, accuracy: 0.001)
        XCTAssertTrue(spotComponent.castsShadow)
        XCTAssertTrue(try XCTUnwrap(scene.get(component: LightComponent.self, for: spotEntity)).usesRadiometricUnits)

        let spotParameters = getSpotLights()
        let importedSpot = try XCTUnwrap(spotParameters.first(where: { abs($0.outerCone - degreesToRadians(degrees: 36.0)) < 0.001 }))
        XCTAssertEqual(importedSpot.innerCone, degreesToRadians(degrees: 14.0), accuracy: 0.001)
        XCTAssertEqual(importedSpot.direction.x, 0.0, accuracy: 0.001)
        XCTAssertEqual(importedSpot.direction.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(importedSpot.direction.z, -1.0, accuracy: 0.001)

        let cameraEntity = try XCTUnwrap(findEntity(named: fixture.cameraName))
        XCTAssertEqual(CameraSystem.shared.activeCamera, cameraEntity)
        XCTAssertEqual(fov, 58.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 650.0, accuracy: 0.001)
    }

    func testSetEntityMesh_loadsNamedNodeFromUntold() async throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold")
            return
        }

        // Discover the first node that has renderable primitives.
        let asset = try await NativeFormatLoader().loadAsset(from: untoldURL)
        guard let nodeName = asset.nodes.first(where: { !$0.primitives.isEmpty })?.name else {
            XCTFail("redplayer.untold has no nodes with primitives")
            return
        }

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "NamedNodeEntity")

        let namedLoadExp = expectation(description: "named node loaded")
        setEntityMeshAsync(entityId: entityId, filename: "redplayer", withExtension: "untold", assetName: nodeName) { _ in namedLoadExp.fulfill() }
        await fulfillment(of: [namedLoadExp], timeout: 10)

        // Named-node load registers the mesh directly on entityId — no child entities.
        XCTAssertTrue(
            hasComponent(entityId: entityId, componentType: RenderComponent.self),
            "Named-node load must register RenderComponent on entityId for node '\(nodeName)'"
        )
        XCTAssertTrue(hasComponent(entityId: entityId, componentType: LocalTransformComponent.self))

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            XCTFail("RenderComponent must exist after named-node load")
            return
        }

        XCTAssertFalse(renderComponent.mesh.isEmpty, "Named-node load must produce at least one mesh")
        XCTAssertEqual(renderComponent.assetName, nodeName, "RenderComponent assetName must match requested node name")
    }

    func testSetEntityMesh_returnsFalseForUnknownNodeName() async {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "BadNameEntity")

        // An unknown assetName should fall back to the fallback mesh, not crash.
        let badNameExp = expectation(description: "bad name loaded")
        setEntityMeshAsync(entityId: entityId, filename: "redplayer", withExtension: "untold", assetName: "nonexistent_node_xyz") { _ in badNameExp.fulfill() }
        await fulfillment(of: [badNameExp], timeout: 10)

        // The entity should still have components (fallback mesh registers them),
        // but no RenderComponent with the bad name.
        if let rc = scene.get(component: RenderComponent.self, for: entityId) {
            XCTAssertNotEqual(rc.assetName, "nonexistent_node_xyz", "Fallback must not claim the bad node name")
        }
    }

    func testSetEntityAnimations_resolvesHierarchicalUntoldRootToSkinnedDescendant() async throws {
        guard let modelURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold")
            return
        }
        guard let animationURL = Bundle.module.url(forResource: "running", withExtension: "untold") else {
            XCTFail("Failed to locate running.untold")
            return
        }

        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, subName in
            if name == "redplayer", ext == "untold" {
                return modelURL
            }
            if name == "running", ext == "untold" {
                return animationURL
            }
            return getResourceURL(resourceName: name, ext: ext, subName: subName)
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        let rootEntity = createEntity()
        setEntityName(entityId: rootEntity, name: "HierarchicalUntoldRoot")

        let loadExp_rootEntity = expectation(description: "redplayer loaded")
        setEntityMeshAsync(entityId: rootEntity, filename: "redplayer", withExtension: "untold") { _ in loadExp_rootEntity.fulfill() }
        await fulfillment(of: [loadExp_rootEntity], timeout: 10)

        let bindingEntity = try XCTUnwrap(resolveEntityForAnimationBinding(entityId: rootEntity))
        XCTAssertNotEqual(bindingEntity, rootEntity)
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: SkeletonComponent.self))
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: RenderComponent.self))

        setEntityAnimations(entityId: rootEntity, filename: "running", withExtension: "untold", name: "running")

        let clipNames = getAllAnimationClips(entityId: rootEntity)
        XCTAssertTrue(clipNames.contains("running"))
        XCTAssertTrue(hasComponent(entityId: bindingEntity, componentType: AnimationComponent.self))

        changeAnimation(entityId: rootEntity, name: "running")

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: bindingEntity) else {
            XCTFail("AnimationComponent should exist on the resolved binding entity")
            return
        }

        XCTAssertNotNil(animationComponent.currentAnimation)
    }

    func testSetEntityAnimationsRegistersEverySkinnedDescendant() {
        guard let animationURL = Bundle.module.url(forResource: "running", withExtension: "untold") else {
            XCTFail("Failed to locate running.untold")
            return
        }

        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, subName in
            if name == "running", ext == "untold" {
                return animationURL
            }
            return getResourceURL(resourceName: name, ext: ext, subName: subName)
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        let rootEntity = createEntity()
        registerTransformComponent(entityId: rootEntity)
        registerSceneGraphComponent(entityId: rootEntity)

        let shirtEntity = makeSkinnedRenderChild(named: "CH38_Shirt", parent: rootEntity)
        let bodyEntity = makeSkinnedRenderChild(named: "CH38_Body", parent: rootEntity)

        let bindingEntities = resolveEntitiesForAnimationBinding(entityId: rootEntity)
        XCTAssertEqual(Set(bindingEntities), Set([shirtEntity, bodyEntity]))

        setEntityAnimations(entityId: rootEntity, filename: "running", withExtension: "untold", name: "running")

        for entityId in [shirtEntity, bodyEntity] {
            guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
                XCTFail("Expected AnimationComponent on skinned child \(entityId)")
                continue
            }

            XCTAssertNotNil(animationComponent.animationClips["running"])
            XCTAssertNotNil(animationComponent.currentAnimation)
        }

        changeAnimation(entityId: rootEntity, name: "running", withPause: true)
        XCTAssertTrue(isAnimationComponentPaused(entityId: rootEntity))

        setAnimationPlaybackSpeed(entityId: rootEntity, speed: 0.5)
        XCTAssertEqual(getAnimationPlaybackSpeed(entityId: rootEntity), 0.5, accuracy: 0.0001)

        removeAnimationClip(entityId: rootEntity, animationClip: "running")
        XCTAssertFalse(getAllAnimationClips(entityId: rootEntity).contains("running"))
    }

    private func findEntity(named name: String) -> EntityID? {
        reverseEntityNameMap[name]?.first(where: { scene.exists($0) && getEntityName(entityId: $0) == name })
    }

    private func makeSkinnedRenderChild(named name: String, parent: EntityID) -> EntityID {
        let entityId = createEntity()
        setEntityName(entityId: entityId, name: name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
        setParent(childId: entityId, parentId: parent)
        return entityId
    }
}

private struct SceneAuthoredUntoldFixture {
    var url: URL
    var stem: String
    var sunName: String
    var spotName: String
    var cameraName: String
}

private func makeSceneAuthoredUntoldFixture() throws -> SceneAuthoredUntoldFixture {
    let stem = "scene-authored-\(UUID().uuidString)"
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(stem).untold")
    let sunName = "Imported Sun"
    let spotName = "Imported Spot"
    let cameraName = "Imported Camera"

    let strings = makeNativeStringTable([
        "root_entity",
        "mesh_0",
        "mat_0",
        "albedo.ktx2",
        sunName,
        spotName,
        cameraName,
    ])
    let bounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
    let entity = UntoldEntityRecordV1(
        entityId: 0,
        nameOffset: strings.offsets["root_entity"]!,
        firstMeshRecordIndex: 0,
        meshRecordCount: 1,
        localBounds: bounds,
        worldBounds: bounds
    )
    let material = UntoldMaterialRecordV1(
        nameOffset: strings.offsets["mat_0"]!,
        baseColorTextureIndex: UntoldFormat.invalidIndex
    )
    let texture = UntoldTextureRefRecordV1(
        nameOffset: strings.offsets["albedo.ktx2"]!,
        uriOffset: strings.offsets["albedo.ktx2"]!,
        textureFormat: .rgba8,
        width: 16,
        height: 16,
        mipCount: 1
    )
    let vertex = UntoldPBRStaticVertexV1(
        position: SIMD3<Float>(0, 0, 0),
        normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 1, 0)),
        tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1)
    )
    let vertexWriter = UntoldBinaryWriter()
    vertex.encode(to: vertexWriter)
    let vertexData = vertexWriter.data
    let indexWriter = UntoldBinaryWriter()
    indexWriter.writeUInt16LE(0)
    indexWriter.writeUInt16LE(0)
    indexWriter.writeUInt16LE(0)
    let indexData = indexWriter.data
    let mesh = UntoldMeshRecordV1(
        entityId: 0,
        meshNameOffset: strings.offsets["mesh_0"]!,
        materialIndex: 0,
        indexType: .uint16,
        vertexCount: 1,
        indexCount: 3,
        vertexStrideBytes: UInt32(vertexData.count),
        vertexDataOffset: 0,
        indexDataOffset: 0,
        vertexDataSizeBytes: UInt64(vertexData.count),
        indexDataSizeBytes: UInt64(indexData.count),
        estimatedGPUBytes: UInt64(vertexData.count + indexData.count),
        localBounds: bounds
    )

    var sunTransform = matrix_identity_float4x4
    sunTransform.columns.3 = SIMD4<Float>(0, 4, 0, 1)
    let sun = UntoldLightRecordV1(
        entityId: 1,
        nameOffset: strings.offsets[sunName]!,
        lightType: .directional,
        flags: UntoldLightFlags.castsShadow | UntoldLightFlags.radiometric,
        color: SIMD3<Float>(1.0, 0.95, 0.8),
        intensity: 2.0,
        localTransform: sunTransform
    )
    var spotTransform = matrix_identity_float4x4
    spotTransform.columns.3 = SIMD4<Float>(2, 3, 4, 1)
    let spot = UntoldLightRecordV1(
        entityId: 2,
        nameOffset: strings.offsets[spotName]!,
        lightType: .spot,
        flags: UntoldLightFlags.castsShadow | UntoldLightFlags.radiometric | UntoldLightFlags.customDistance,
        color: SIMD3<Float>(0.2, 0.4, 1.0),
        intensity: 5.0,
        position: SIMD3<Float>(2, 3, 4),
        radius: 0.2,
        falloff: 18.0,
        innerCone: 14.0,
        outerCone: 36.0,
        localTransform: spotTransform
    )
    var cameraTransform = matrix_identity_float4x4
    cameraTransform.columns.3 = SIMD4<Float>(0, 1, 6, 1)
    let camera = UntoldCameraRecordV1(
        entityId: 3,
        nameOffset: strings.offsets[cameraName]!,
        position: SIMD3<Float>(0, 1, 6),
        fovYDegrees: 58.0,
        nearClip: 0.05,
        farClip: 650.0,
        aspectRatio: 1.6,
        localTransform: cameraTransform
    )

    var header = UntoldFileHeaderV1(
        fileType: .tile,
        chunkCount: 0,
        meshCount: 1,
        materialCount: 1,
        textureRefCount: 1,
        entityCount: 1,
        vertexLayout: .pbrStaticV1,
        worldBounds: bounds
    )
    let payloads: [(UntoldChunkType, Data, UInt32)] = [
        (.stringTable, strings.data, 0),
        (.entityTable, encodeNativeRecords([entity]), 1),
        (.meshTable, encodeNativeRecords([mesh]), 1),
        (.materialTable, encodeNativeRecords([material]), 1),
        (.textureTable, encodeNativeRecords([texture]), 1),
        (.vertexData, vertexData, 0),
        (.indexData, indexData, 0),
        (.lightTable, encodeNativeRecords([sun, spot]), 2),
        (.cameraTable, encodeNativeRecords([camera]), 1),
    ]
    header.chunkCount = UInt32(payloads.count)
    let fileData = buildNativeFileData(header: header, payloads: payloads)
    try fileData.write(to: url, options: .atomic)

    return SceneAuthoredUntoldFixture(url: url, stem: stem, sunName: sunName, spotName: spotName, cameraName: cameraName)
}

private func encodeNativeRecords(_ records: [some UntoldBinaryEncodable]) -> Data {
    let writer = UntoldBinaryWriter()
    for record in records {
        record.encode(to: writer)
    }
    return writer.data
}

private func makeNativeStringTable(_ strings: [String]) -> (data: Data, offsets: [String: UInt32]) {
    let writer = UntoldBinaryWriter()
    var offsets: [String: UInt32] = [:]
    for string in strings {
        offsets[string] = UInt32(writer.count)
        writer.writeNullTerminatedUTF8(string)
    }
    return (writer.data, offsets)
}

private func buildNativeFileData(
    header: UntoldFileHeaderV1,
    payloads: [(UntoldChunkType, Data, UInt32)]
) -> Data {
    let headerWriter = UntoldBinaryWriter()
    header.encode(to: headerWriter)

    let chunkTableBytes = 40 * payloads.count
    var runningOffset = headerWriter.count + chunkTableBytes
    var entries: [UntoldChunkEntryV1] = []
    for payload in payloads {
        runningOffset = alignNativeOffset(runningOffset, to: Int(UntoldFormat.fileAlignment))
        entries.append(
            UntoldChunkEntryV1(
                chunkType: payload.0,
                fileOffset: UInt64(runningOffset),
                compressedSize: UInt64(payload.1.count),
                uncompressedSize: UInt64(payload.1.count),
                elementCount: payload.2
            )
        )
        runningOffset += payload.1.count
    }

    let writer = UntoldBinaryWriter()
    header.encode(to: writer)
    for entry in entries {
        entry.encode(to: writer)
    }
    for payload in payloads {
        writer.align(to: Int(UntoldFormat.fileAlignment))
        writer.writeData(payload.1)
    }
    return writer.data
}

private func alignNativeOffset(_ value: Int, to alignment: Int) -> Int {
    let remainder = value % alignment
    return remainder == 0 ? value : value + (alignment - remainder)
}
