//
//  TransparencyTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import ModelIO
import simd
@testable import UntoldEngine
import XCTest

// MARK: - Material Alpha Decoding Tests

final class MaterialAlphaDecodingTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 1: Explicit alphaMode from MDLMaterial properties

    func testAlphaMode_decodesBlendFromExplicitProperty() {
        let mdlMaterial = MDLMaterial(name: "blendMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "blend"))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .blend, "Explicit 'blend' string should decode to .blend")
    }

    func testAlphaMode_decodesMaskFromExplicitProperty() {
        let mdlMaterial = MDLMaterial(name: "maskMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "mask"))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .mask, "Explicit 'mask' string should decode to .mask")
    }

    func testAlphaMode_decodesOpaqueFromExplicitProperty() {
        let mdlMaterial = MDLMaterial(name: "opaqueMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "opaque"))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .opaque, "Explicit 'opaque' string should decode to .opaque")
    }

    func testAlphaMode_decodesFromTransparencyModeAlias() {
        let mdlMaterial = MDLMaterial(name: "transparentMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "transparencyMode", semantic: .userDefined, string: "transparent"))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .blend, "transparencyMode='transparent' should decode to .blend")
    }

    func testAlphaMode_decodesFromCutoutAlias() {
        let mdlMaterial = MDLMaterial(name: "cutoutMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "cutout"))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .mask, "Explicit 'cutout' string should decode to .mask")
    }

    func testAlphaMode_decodesFromNumericScalar() {
        // scalar < 0.5 => opaque, 0.5..<1.5 => mask, >= 1.5 => blend
        let mdlMaterialOpaque = MDLMaterial(name: "numOpaque", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterialOpaque.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, float: 0.0))

        let mdlMaterialMask = MDLMaterial(name: "numMask", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterialMask.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, float: 1.0))

        let mdlMaterialBlend = MDLMaterial(name: "numBlend", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterialBlend.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, float: 2.0))

        let textureLoader = TextureLoader(device: renderInfo.device)

        let matOpaque = Material(mdlMaterial: mdlMaterialOpaque, textureLoader: textureLoader, name: "test")
        let matMask = Material(mdlMaterial: mdlMaterialMask, textureLoader: textureLoader, name: "test")
        let matBlend = Material(mdlMaterial: mdlMaterialBlend, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(matOpaque.alphaMode, .opaque, "Scalar 0.0 should decode to .opaque")
        XCTAssertEqual(matMask.alphaMode, .mask, "Scalar 1.0 should decode to .mask")
        XCTAssertEqual(matBlend.alphaMode, .blend, "Scalar 2.0 should decode to .blend")
    }

    // MARK: - Test 2: Inferred alphaMode when explicit properties are absent

    func testAlphaMode_infersBlendFromBaseColorAlpha() {
        let mdlMaterial = MDLMaterial(name: "semiTransparent", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        // Set base color with alpha < 1.0 using a float4 property
        let color = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.5)
        mdlMaterial.setProperty(MDLMaterialProperty(name: "baseColor", semantic: .baseColor, color: color))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .blend,
                       "Base color with alpha < 1.0 should infer .blend when no explicit alphaMode is set")
    }

    func testAlphaMode_infersBlendFromOpacityBelowOne() {
        let mdlMaterial = MDLMaterial(name: "opacityMat", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "opacity", semantic: .opacity, float: 0.7))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .blend,
                       "Opacity < 1.0 should infer .blend when no explicit alphaMode is set")
    }

    func testAlphaMode_infersOpaqueWhenFullyOpaque() {
        let mdlMaterial = MDLMaterial(name: "fullyOpaque", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        // No alphaMode property, no opacity property, no alpha in base color
        // Base color without explicit alpha (float3 path returns hasExplicitAlpha=false)

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaMode, .opaque,
                       "Material with no transparency signals should default to .opaque")
    }

    // MARK: - Test 3: alphaCutoff clamping

    func testAlphaCutoff_clampsValueAboveOne() {
        let mdlMaterial = MDLMaterial(name: "highCutoff", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "mask"))
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaCutoff", semantic: .userDefined, float: 2.5))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaCutoff, 1.0, accuracy: 0.0001,
                       "alphaCutoff above 1.0 should be clamped to 1.0")
    }

    func testAlphaCutoff_clampsValueBelowZero() {
        let mdlMaterial = MDLMaterial(name: "lowCutoff", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "mask"))
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaCutoff", semantic: .userDefined, float: -0.5))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaCutoff, 0.0, accuracy: 0.0001,
                       "alphaCutoff below 0.0 should be clamped to 0.0")
    }

    func testAlphaCutoff_preservesValidValue() {
        let mdlMaterial = MDLMaterial(name: "validCutoff", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "mask"))
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaCutoff", semantic: .userDefined, float: 0.3))

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaCutoff, 0.3, accuracy: 0.0001,
                       "alphaCutoff within [0,1] should be preserved as-is")
    }

    func testAlphaCutoff_defaultsWhenNotProvided() {
        let mdlMaterial = MDLMaterial(name: "noCutoff", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        mdlMaterial.setProperty(MDLMaterialProperty(name: "alphaMode", semantic: .userDefined, string: "mask"))
        // No alphaCutoff property

        let textureLoader = TextureLoader(device: renderInfo.device)
        let material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: "test")

        XCTAssertEqual(material.alphaCutoff, 0.5, accuracy: 0.0001,
                       "alphaCutoff should default to 0.5 when not explicitly provided")
    }
}

// MARK: - Transparency Pipeline & Render Graph Tests

final class TransparencyRenderGraphTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Test 4: Transparency pipeline initialization and render graph

    func testTransparencyPipeline_isRegistered() {
        let pipeline = PipelineManager.shared.renderPipelinesByType[.transparency]

        XCTAssertNotNil(pipeline, "Transparency pipeline should be registered in PipelineManager")
        XCTAssertTrue(pipeline?.success ?? false, "Transparency pipeline should be successfully initialized")
    }

    func testTransparencyPass_existsInGameModeGraph() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["transparency"], "Transparency pass should exist in the game mode graph")
    }

    func testTransparencyPass_dependsOnLightPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertEqual(graph["transparency"]?.dependencies, ["lightPass"],
                       "Transparency pass should depend on lightPass")
    }

    func testTransparencyPass_hasExecutionFunction() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["transparency"]?.execute,
                        "Transparency pass should have an execution function")
    }

    func testTransparencyPass_existsInAllRenderModes() {
        let modes: [(UntoldImmersionMode, Bool, String)] = [
            (.none, true, "environment"),
            (.none, false, "grid"),
            (.full, true, "full immersion"),
            (.mixed, false, "passthrough"),
        ]

        for (immersionStyle, useEnvironment, description) in modes {
            renderInfo.immersionStyle = immersionStyle
            renderEnvironment = useEnvironment

            let (graph, _) = buildGameModeGraph()

            XCTAssertNotNil(graph["transparency"],
                            "Transparency pass should exist in \(description) mode")
            XCTAssertEqual(graph["transparency"]?.dependencies, ["lightPass"],
                           "Transparency should depend on lightPass in \(description) mode")
        }
    }

    func testTransparencyPass_topologicalPositionAfterLightBeforePostProcess() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = false

        let (graph, _) = buildGameModeGraph()
        let sorted = try! topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        guard let transparencyIndex = order.firstIndex(of: "transparency"),
              let lightIndex = order.firstIndex(of: "lightPass")
        else {
            XCTFail("Both transparency and lightPass should exist in the graph")
            return
        }

        XCTAssertTrue(lightIndex < transparencyIndex,
                      "Light pass must come before transparency pass")

        guard let dofIndex = order.firstIndex(of: "depthOfField") else {
            XCTFail("depthOfField pass should exist")
            return
        }

        XCTAssertTrue(transparencyIndex < dofIndex,
                      "Transparency pass must come before post-processing (depthOfField)")
    }

    func testTransparencyPass_bypassModeDepends() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        defer { bypassPostProcessing = false }

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["transparency"],
                        "Transparency pass should exist when bypassing post-processing")
        XCTAssertEqual(graph["postProcessBypass"]?.dependencies, ["transparency"],
                       "Bypass pass should depend on transparency")
    }

    // MARK: - Test 5: Transparent objects sorted back-to-front

    func testTransparentEntities_sortedBackToFront() {
        // Create three entities at different distances from the camera.
        // Camera is at (0, 3, 7), looking at origin.
        let nearEntity = createEntity()
        setEntityMeshDirect(entityId: nearEntity, meshes: BasicPrimitives.createCube(), assetName: "NearCube")
        translateTo(entityId: nearEntity, position: simd_float3(0.0, 0.0, 5.0)) // close to camera
        setEntityName(entityId: nearEntity, name: "NearCube")

        let midEntity = createEntity()
        setEntityMeshDirect(entityId: midEntity, meshes: BasicPrimitives.createCube(), assetName: "MidCube")
        translateTo(entityId: midEntity, position: simd_float3(0.0, 0.0, 0.0)) // at origin
        setEntityName(entityId: midEntity, name: "MidCube")

        let farEntity = createEntity()
        setEntityMeshDirect(entityId: farEntity, meshes: BasicPrimitives.createCube(), assetName: "FarCube")
        translateTo(entityId: farEntity, position: simd_float3(0.0, 0.0, -10.0)) // far from camera
        setEntityName(entityId: farEntity, name: "FarCube")

        // Set all to blend mode so they qualify as transparent
        updateMaterialAlphaMode(entityId: nearEntity, mode: .blend)
        updateMaterialAlphaMode(entityId: midEntity, mode: .blend)
        updateMaterialAlphaMode(entityId: farEntity, mode: .blend)

        // Propagate local transforms so world-space distance sorting is meaningful.
        traverseSceneGraph()

        // Refresh visible entities to include new ones
        setVisibleEntities()

        // Replicate the sorting logic from transparencyExecution:
        // Gather transparent entities with their distances from camera.
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            XCTFail("Active camera should exist")
            return
        }

        var transparentEntities: [(entityId: EntityID, distanceSq: Float)] = []

        for entityId in visibleEntityIds {
            guard scene.mask(for: entityId) != nil else { continue }
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { continue }
            guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId) else { continue }

            let hasTransparentSubmesh = renderComponent.mesh.contains { mesh in
                mesh.submeshes.contains { $0.material?.alphaMode == .blend }
            }
            guard hasTransparentSubmesh else { continue }

            let worldPos = simd_float3(
                worldTransform.space.columns.3.x,
                worldTransform.space.columns.3.y,
                worldTransform.space.columns.3.z
            )
            let distanceSq = simd_length_squared(cameraComponent.localPosition - worldPos)
            transparentEntities.append((entityId: entityId, distanceSq: distanceSq))
        }

        // Sort back-to-front (highest distanceSq first)
        transparentEntities.sort { $0.distanceSq > $1.distanceSq }

        XCTAssertGreaterThanOrEqual(transparentEntities.count, 3,
                                    "Should have at least 3 transparent entities (near, mid, far)")

        // Verify back-to-front ordering: distances should be descending
        for i in 0 ..< (transparentEntities.count - 1) {
            XCTAssertGreaterThanOrEqual(
                transparentEntities[i].distanceSq,
                transparentEntities[i + 1].distanceSq,
                "Transparent entities should be sorted back-to-front (descending distance)"
            )
        }

        // Verify the far entity comes first and the near entity comes last among our three
        let farIndex = transparentEntities.firstIndex(where: { $0.entityId == farEntity })
        let midIndex = transparentEntities.firstIndex(where: { $0.entityId == midEntity })
        let nearIndex = transparentEntities.firstIndex(where: { $0.entityId == nearEntity })

        XCTAssertNotNil(farIndex, "Far entity should be in the transparent list")
        XCTAssertNotNil(midIndex, "Mid entity should be in the transparent list")
        XCTAssertNotNil(nearIndex, "Near entity should be in the transparent list")

        if let far = farIndex, let mid = midIndex, let near = nearIndex {
            XCTAssertTrue(far < mid, "Far entity should be rendered before mid entity (back-to-front)")
            XCTAssertTrue(mid < near, "Mid entity should be rendered before near entity (back-to-front)")
        }
    }
}
