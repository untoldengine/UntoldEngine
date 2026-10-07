//
//  GlassShadingTests.swift
//  UntoldEngine
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

/// A material's transmission: what is behind the surface shows through it, tinted by
/// its base color, and the surface keeps its reflections and its glow whole.
final class GlassShadingTests: MaterialShadingTestCase {
    private var ambientIntensityBefore: Float = 0.0

    override func setUp() async throws {
        try await super.setUp()
        ambientIntensityBefore = ambientIntensity
    }

    override func tearDown() async throws {
        ambientIntensity = ambientIntensityBefore
        // A test may have left the pass with the pipeline that has no color filter.
        PipelineManager.shared.initRenderPipelines([(.transparency, InitTransparencyPipeline)])
        try await super.tearDown()
    }

    private func material(
        color: simd_float3 = simd_float3(1, 1, 1),
        transmission: Float,
        roughness: Float = 0.0,
        metallic: Float = 0.0,
        alpha: Float = 1.0,
        emissive: simd_float3 = .zero,
        blended: Bool = false
    ) -> RuntimeMaterialSource {
        RuntimeMaterialSource(
            baseColorFactor: simd_float4(color.x, color.y, color.z, alpha),
            emissiveFactor: emissive,
            metallicFactor: metallic,
            roughnessFactor: roughness,
            flags: blended ? 2 : 0,
            transmissionFactor: transmission
        )
    }

    /// A material that draws nothing: what the frame shows without the shape.
    private var nothing: RuntimeMaterialSource {
        material(transmission: 0.0, alpha: 0.0, blended: true)
    }

    /// A wall behind the shape that gives off `color` and takes no light: what a
    /// surface in front of it lets through is a share of exactly that. With a base
    /// color it is a matte wall, which shows the light that reaches it.
    @discardableResult
    private func putAWallBehind(glowing color: simd_float3, baseColor: simd_float3 = .zero) throws -> EntityID {
        let wall = createEntity()
        var meshes = BasicPrimitives.createCube(extent: 30.0)
        let glow = Material(
            runtimeMaterial: RuntimeMaterialSource(
                baseColorFactor: simd_float4(baseColor.x, baseColor.y, baseColor.z, 1),
                emissiveFactor: color,
                metallicFactor: 0.0,
                roughnessFactor: 1.0
            ),
            device: renderInfo.device
        )
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                meshes[meshIndex].submeshes[submeshIndex].material = glow
            }
        }
        let renderComponent = try XCTUnwrap(scene.assign(to: wall, component: RenderComponent.self))
        renderComponent.mesh = meshes
        renderComponent.assetURL = URL(fileURLWithPath: "/dev/null/glass-shading-wall.untold")
        if let local = scene.get(component: LocalTransformComponent.self, for: wall) {
            local.boundingBox = Mesh.computeMeshBoundingBox(for: meshes)
        }
        // Its near face stands 3.5 behind the shape's far one.
        translateTo(entityId: wall, position: simd_float3(0, 0, -20))
        setVisibleEntities()
        return wall
    }

    private func setWallGlow(_ wall: EntityID, to color: simd_float3) {
        updateMaterialEmmisive(entityId: wall, emmissive: color)
    }

    /// The brightness of a color as the eye weighs it, which is what one share for
    /// red, green and blue goes by.
    private func brightness(_ color: simd_float3) -> Float {
        simd_dot(color, simd_float3(0.2126, 0.7152, 0.0722))
    }

    /// What a polished non-metal reflects seen head on: about 4 % of the light. Each
    /// face of a pane lets the rest through.
    private static let reflectedHeadOn: Float = 0.04

    /// The cube shows two faces to the middle of the frame, its far one through its
    /// near one: what is behind it crosses both.
    private static let throughBothFaces: Float = (1.0 - reflectedHeadOn) * (1.0 - reflectedHeadOn)

    // MARK: - What shows through

    /// Glass was drawn as a blended surface 10 % opaque. A transmissive material now
    /// shows what is behind it, less what each face reflects, and scatters no light.
    func testClearGlassShowsWhatIsBehindIt() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let wall = try shade(nothing)
        let solid = try shade(material(transmission: 0.0))
        let glass = try shade(material(transmission: 1.0))

        XCTAssertEqual(wall.x, 0.8, accuracy: 0.02, "the wall gives off its own color")
        XCTAssertLessThan(simd_reduce_max(solid), 0.01, "a solid surface hides the wall")
        for channel in 0 ..< 3 {
            XCTAssertEqual(glass[channel] / wall[channel], Self.throughBothFaces, accuracy: 0.03)
        }
    }

    /// A material is glass by its transmission, not by its alpha mode: it needs no
    /// blend flag to be drawn over the scene, and it writes nothing where the solid
    /// surfaces go.
    func testAMaterialIsSeeThroughByItsTransmissionAlone() {
        let glass = Material(runtimeMaterial: material(transmission: 0.4), device: renderInfo.device)
        XCTAssertEqual(glass.alphaMode, .opaque)
        XCTAssertEqual(glass.transmission, 0.4)
        XCTAssertTrue(glass.hasTransparency)

        let solid = Material(runtimeMaterial: material(transmission: 0.0), device: renderInfo.device)
        XCTAssertFalse(solid.hasTransparency)
        let blended = Material(runtimeMaterial: material(transmission: 0.0, alpha: 0.5, blended: true), device: renderInfo.device)
        XCTAssertTrue(blended.hasTransparency)
    }

    /// A surface that is all metal, or too rough to see through, lets nothing through
    /// whatever its transmission says: it stays among the solid surfaces, with their
    /// depth, their shadows and their batches. (A car body left with a transmission
    /// of 1 on its metallic or matte paints is such a surface.)
    func testASurfaceThatLetsNothingThroughStaysSolid() throws {
        let metal = Material(runtimeMaterial: material(transmission: 1.0, roughness: 0.3, metallic: 1.0), device: renderInfo.device)
        XCTAssertFalse(metal.transmitsLight)
        XCTAssertFalse(metal.hasTransparency)
        let rough = Material(runtimeMaterial: material(transmission: 1.0, roughness: 1.0), device: renderInfo.device)
        XCTAssertFalse(rough.hasTransparency)
        let frosted = Material(runtimeMaterial: material(transmission: 1.0, roughness: GLASS_FROSTED_FROM_ROUGHNESS), device: renderInfo.device)
        XCTAssertFalse(frosted.hasTransparency)
        let nearlyFrosted = Material(runtimeMaterial: material(transmission: 1.0, roughness: GLASS_FROSTED_FROM_ROUGHNESS - 0.01), device: renderInfo.device)
        XCTAssertTrue(nearlyFrosted.hasTransparency)

        // A texture can leave parts of the surface clear.
        let texture = try writeGrayscaleTexture(value: 128)
        var patchy = material(transmission: 1.0, roughness: 0.3, metallic: 1.0)
        patchy.metallicTexture = RuntimeTextureReference(name: texture.lastPathComponent, sourceURL: texture, isSRGB: false)
        XCTAssertTrue(Material(runtimeMaterial: patchy, device: renderInfo.device).hasTransparency)

        // The wall behind a fully rough "glass" stays hidden, as behind the solid surface.
        try buildScene(towardsLight: simd_float3(0, 0, 1))
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))
        let solid = try shade(material(color: simd_float3(0.5, 0.5, 0.5), transmission: 0.0, roughness: 1.0))
        let ground = try shade(material(color: simd_float3(0.5, 0.5, 0.5), transmission: 1.0, roughness: 1.0))
        XCTAssertGreaterThan(solid.x, 0.05, "the light reaches the near face")
        for channel in 0 ..< 3 {
            XCTAssertEqual(ground[channel], solid[channel], accuracy: 0.005)
        }
    }

    /// The base color tints what crosses the glass, each of red, green and blue by its
    /// own share: it is the tint of a pane seen through its two faces, as in Blender.
    /// A blended surface could only cover the wall with a lit film of that color.
    func testTintedGlassFiltersEachColorOnItsOwn() throws {
        try XCTSkipUnless(
            PipelineManager.shared.pipeline(for: .transparency)?.name == transparencyPipelineName,
            "this device blends without a color filter"
        )
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let tint = simd_float3(0.9, 0.6, 0.3)
        let clear = try shade(material(transmission: 1.0))
        let tinted = try shade(material(color: tint, transmission: 1.0))

        // Through both faces of the cube, each taking the square root of the tint.
        for channel in 0 ..< 3 {
            XCTAssertEqual(tinted[channel] / clear[channel], tint[channel], accuracy: 0.02)
        }
    }

    /// Where the device cannot filter by color, the glass is as dark as it should be
    /// and gray: one share for the three colors, by the brightness of the tint.
    func testWithoutAColorFilterTintedGlassDarkensEvenly() throws {
        PipelineManager.shared.initRenderPipelines([(.transparency, { try? makeTransparencyPipeline(filteringByColor: false) })])
        XCTAssertEqual(PipelineManager.shared.pipeline(for: .transparency)?.name, transparencyPipelineNameWithoutColorFilter)

        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let tint = simd_float3(0.9, 0.6, 0.3)
        let wall = try shade(nothing)
        let clear = try shade(material(transmission: 1.0))
        let tinted = try shade(material(color: tint, transmission: 1.0))

        // Each face lets through the brightness of its share of the tint.
        let throughOneFace = brightness(simd_float3(tint.x.squareRoot(), tint.y.squareRoot(), tint.z.squareRoot()))
        for channel in 0 ..< 3 {
            XCTAssertEqual(clear[channel] / wall[channel], Self.throughBothFaces, accuracy: 0.03)
            XCTAssertEqual(tinted[channel] / clear[channel], throughOneFace * throughOneFace, accuracy: 0.02)
        }
    }

    /// A blended material draws as it did: its alpha is how much of it is there.
    func testABlendedMaterialWithoutTransmissionCoversByItsAlpha() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let wall = try shade(nothing)
        let halfThere = try shade(material(color: .zero, transmission: 0.0, alpha: 0.5, blended: true))

        // Two faces, each hiding half of what is behind it.
        for channel in 0 ..< 3 {
            XCTAssertEqual(halfThere[channel] / wall[channel], 0.25, accuracy: 0.01)
        }
    }

    /// Alpha and transmission together: the part of the surface that is there filters
    /// what is behind it, and the rest lets it by untouched.
    func testGlassThatIsHalfThereFiltersHalfOfWhatIsBehindIt() throws {
        try XCTSkipUnless(
            PipelineManager.shared.pipeline(for: .transparency)?.name == transparencyPipelineName,
            "this device blends without a color filter"
        )
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let tint = simd_float3(0.9, 0.6, 0.3)
        let wall = try shade(nothing)
        let halfThere = try shade(material(color: tint, transmission: 1.0, alpha: 0.5, blended: true))

        for channel in 0 ..< 3 {
            let throughOneFace = 0.5 + 0.5 * tint[channel].squareRoot() * (1.0 - Self.reflectedHeadOn)
            XCTAssertEqual(halfThere[channel] / wall[channel], throughOneFace * throughOneFace, accuracy: 0.03)
        }
    }

    // MARK: - What the surface keeps

    /// Glass stood in for by a blended surface showed a tenth of its reflections. Black
    /// glass lets nothing through and reflects like a black solid: a black mirror.
    func testGlassReflectsAsMuchAsASolidSurface() throws {
        try buildScene(.sphere, towardsLight: simd_float3(1, 1, 1))
        try lightWithAnEvenEnvironment()

        let solid = try shadeFrame(material(color: .zero, transmission: 0.0, roughness: 0.2))
        let glass = try shadeFrame(material(color: .zero, transmission: 1.0, roughness: 0.2))

        let centre = (x: solid.width / 2, y: solid.height / 2)
        let solidCentre = Self.meanColor(of: solid, aroundX: centre.x, y: centre.y, window: 16)
        let glassCentre = Self.meanColor(of: glass, aroundX: centre.x, y: centre.y, window: 16)
        XCTAssertGreaterThan(solidCentre.x, 0.005, "the sphere reflects the light around it")
        XCTAssertEqual(glassCentre.x, solidCentre.x, accuracy: 0.1 * solidCentre.x)

        // Its rim, where it reflects most, and the highlight of the light: the brightest
        // pixel and the whole frame come out the same.
        let solidPeak = solid.pixels.map(\.x).max() ?? 0
        let glassPeak = glass.pixels.map(\.x).max() ?? 0
        XCTAssertGreaterThan(solidPeak, 5.0 * solidCentre.x)
        XCTAssertEqual(glassPeak, solidPeak, accuracy: 0.05 * solidPeak)
        let solidSum = solid.pixels.reduce(Float(0)) { $0 + $1.x }
        let glassSum = glass.pixels.reduce(Float(0)) { $0 + $1.x }
        XCTAssertEqual(glassSum, solidSum, accuracy: 0.03 * solidSum)

        // And pixel by pixel: the triangles of a mesh come in no order, and the near
        // side of the sphere is what shows everywhere, never its far side over it.
        var worst: Float = 0
        for index in solid.pixels.indices {
            worst = max(worst, abs(glass.pixels[index].x - solid.pixels[index].x))
        }
        XCTAssertLessThan(worst, 0.05 * solidPeak)
    }

    /// The light crosses glass: what is behind a pane is lit through it. (A blended
    /// surface casts the shadow of a solid one.)
    func testGlassCastsNoShadow() throws {
        // A little off the line of sight, so that the pane's own highlight is elsewhere.
        try buildScene(towardsLight: simd_float3(0.15, 0.15, 1))
        ambientIntensity = 0.0
        try putAWallBehind(glowing: .zero, baseColor: simd_float3(1, 1, 1))

        let glass = try shadeFrame(material(transmission: 1.0))
        // The wall in the light, well to the side of the cube and of any shadow of it.
        let wall = Self.meanColor(of: glass, aroundX: glass.width * 9 / 10, y: glass.height / 2, window: 16)
        let behindGlass = Self.meanColor(of: glass, aroundX: glass.width / 2, y: glass.height / 2, window: 16)
        let behindABlendedCube = try shade(material(color: .zero, transmission: 0.0, alpha: 0.05, blended: true))

        XCTAssertGreaterThan(wall.x, 0.2, "the light reaches the wall")
        XCTAssertEqual(behindGlass.x / wall.x, Self.throughBothFaces, accuracy: 0.03)
        XCTAssertLessThan(behindABlendedCube.x, 0.05 * wall.x, "the wall behind a blended cube is in its shadow")
    }

    /// What glass reflects it does not let through, and the other way round: with the
    /// same light behind it as around it, a clear glass sphere is not to be seen,
    /// from its middle, where it lets nearly everything through, to its rim, where
    /// it is a mirror.
    func testClearGlassAddsAndTakesNoLight() throws {
        try buildScene(.sphere, towardsLight: nil)
        try lightWithAnEvenEnvironment()

        // The light around: what a matte white sphere gives back.
        let around = try shade(material(transmission: 0.0, roughness: 1.0)).x
        XCTAssertGreaterThan(around, 0.1)

        // A wall of that brightness. It reflects a little of the light around it besides
        // what it gives off: take that from its glow.
        let wall = try putAWallBehind(glowing: simd_float3(repeating: around))
        let tooBright = try shade(nothing).x
        setWallGlow(wall, to: simd_float3(repeating: around * around / tooBright))
        let behind = try shadeFrame(nothing)
        XCTAssertEqual(Self.meanColor(of: behind, aroundX: behind.width / 2, y: behind.height / 2, window: 16).x, around, accuracy: 0.01 * around)

        // Clear glass, and glass half frosted, which shows half of what is behind it and
        // glows with the light there for the other half.
        for roughness in [Float(0.0), (GLASS_CLEAR_UP_TO_ROUGHNESS + GLASS_FROSTED_FROM_ROUGHNESS) / 2.0] {
            let glass = try shadeFrame(material(transmission: 1.0, roughness: roughness))
            var worst: Float = 0
            for index in glass.pixels.indices {
                worst = max(worst, abs(glass.pixels[index].x - behind.pixels[index].x))
            }
            XCTAssertLessThan(worst, 0.01 * around, "roughness \(roughness): the sphere shows against the wall")
        }
    }

    /// A blended surface gave off its glow by its alpha. Glass gives it off whole.
    func testGlassGlowsWhole() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0

        // Black glass, so that only the near face shows.
        let dark = try shade(material(color: .zero, transmission: 1.0))
        let glowing = try shade(material(color: .zero, transmission: 1.0, emissive: simd_float3(1.0, 0.5, 0.25)))

        for channel in 0 ..< 3 {
            XCTAssertEqual(glowing[channel] - dark[channel], simd_float3(1.0, 0.5, 0.25)[channel], accuracy: 0.02)
        }
    }

    // MARK: - What takes from it

    /// Nothing blurs what is seen through a rough surface, so it gives up its
    /// transmission instead. Polished glass is clear, a pane as rough as window glass
    /// is authored included, and frosted glass shows nothing: half way between the
    /// two, each face lets half as much through.
    func testRoughGlassLetsLessThrough() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let clear = try shade(material(transmission: 1.0))
        let window = try shade(material(transmission: 1.0, roughness: 0.04))
        let halfWay = (GLASS_CLEAR_UP_TO_ROUGHNESS + GLASS_FROSTED_FROM_ROUGHNESS) / 2.0
        let halfFrosted = try shade(material(transmission: 1.0, roughness: halfWay))

        for channel in 0 ..< 3 {
            XCTAssertEqual(window[channel] / clear[channel], 1.0, accuracy: 0.01)
            XCTAssertEqual(halfFrosted[channel] / clear[channel], 0.5 * 0.5, accuracy: 0.02)
        }
    }

    /// Frosted glass shows nothing of what is behind it and glows with the light that
    /// falls on its far side: lit from behind it is as bright as a matte white surface
    /// lit from the front, less what the glass reflects, and lit from the front it
    /// shows only the highlight of the light.
    func testFrostedGlassGlowsWithTheLightBehindIt() throws {
        try buildScene(towardsLight: simd_float3(0, 0, 1))
        ambientIntensity = 0.0
        let sun = try XCTUnwrap(LightingSystem.shared.activeDirectionalLight)
        let matteWhite = material(transmission: 0.0, roughness: 1.0)
        let frosted = material(transmission: 1.0, roughness: GLASS_FROSTED_FROM_ROUGHNESS - 0.01)

        let solidLitFromTheFront = try shade(matteWhite)
        let frostedLitFromTheFront = try shade(frosted)
        rotateTo(entityId: sun, rotation: quaternion_lookAt(eye: simd_float3(0, 0, -1), target: .zero, up: simd_float3(0, 1, 0)))
        let frostedLitFromBehind = try shade(frosted)
        let solidLitFromBehind = try shade(matteWhite)

        XCTAssertGreaterThan(solidLitFromTheFront.x, 0.2, "the light reaches the near face")
        XCTAssertLessThan(solidLitFromBehind.x, 0.01, "a solid surface shows nothing of the light behind it")
        for channel in 0 ..< 3 {
            XCTAssertEqual(frostedLitFromBehind[channel] / solidLitFromTheFront[channel], 1.0 - Self.reflectedHeadOn, accuracy: 0.03)
            XCTAssertLessThan(frostedLitFromTheFront[channel], 0.3 * solidLitFromTheFront[channel])
        }
    }

    /// The metal of a surface lets nothing through: half metal, each face lets half
    /// as much through, the glass of the half that is not metal.
    func testTheMetalOfASurfaceLetsNothingThrough() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let clear = try shade(material(transmission: 1.0))
        let halfMetal = try shade(material(transmission: 1.0, metallic: 0.5))

        for channel in 0 ..< 3 {
            XCTAssertEqual(halfMetal[channel] / clear[channel], 0.5 * 0.5, accuracy: 0.02)
        }
    }

    /// The transmission is a share of the surface: at a half, the surface lets half
    /// through and scatters light with the other half.
    func testATransmissionOfAHalfLetsHalfThrough() throws {
        try buildScene(towardsLight: nil)
        ambientIntensity = 0.0
        try putAWallBehind(glowing: simd_float3(0.8, 0.6, 0.4))

        let clear = try shade(material(transmission: 1.0))
        let half = try shade(material(transmission: 0.5))

        for channel in 0 ..< 3 {
            XCTAssertEqual(half[channel] / clear[channel], 0.5 * 0.5, accuracy: 0.02)
        }
    }

    // MARK: - Setting it

    func testTransmissionIsSetAndReadThroughTheMaterialFunctions() throws {
        try buildScene(towardsLight: nil)
        _ = try shade(material(transmission: 0.0))
        let entity = try XCTUnwrap(scene.getAllEntities().first { scene.get(component: RenderComponent.self, for: $0) != nil })

        XCTAssertEqual(getMaterialTransmission(entityId: entity), 0.0)
        updateMaterialTransmission(entityId: entity, transmission: 0.6)
        XCTAssertEqual(getMaterialTransmission(entityId: entity), 0.6)
        XCTAssertEqual(getMaterialAlphaMode(entityId: entity), .opaque, "transmission leaves the alpha mode alone")
        updateMaterialTransmission(entityId: entity, transmission: 7.0)
        XCTAssertEqual(getMaterialTransmission(entityId: entity), 1.0)
        updateMaterialTransmission(entityId: entity, transmission: -1.0)
        XCTAssertEqual(getMaterialTransmission(entityId: entity), 0.0)
    }

    /// The values of a saved scene, without what it says of any material's transmission.
    private static func withoutTransmission(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.filter { $0.key != "transmission" }.mapValues(withoutTransmission)
        }
        if let array = value as? [Any] {
            return array.map(withoutTransmission)
        }
        return value
    }

    func testASavedSceneKeepsTheTransmission() throws {
        try buildScene(towardsLight: nil)
        _ = try shade(material(transmission: 0.0))
        let entity = try XCTUnwrap(scene.getAllEntities().first { scene.get(component: RenderComponent.self, for: $0) != nil })
        updateMaterialTransmission(entityId: entity, transmission: 0.6)

        let saved = try JSONEncoder().encode(serializeScene())
        let read = try JSONDecoder().decode(SceneData.self, from: saved)
        XCTAssertEqual(read.entities.compactMap(\.materialData).first?.transmission, 0.6)

        // A scene saved before materials had a transmission says nothing about it, and
        // leaves the material with its own.
        let before = try JSONSerialization.data(withJSONObject: Self.withoutTransmission(JSONSerialization.jsonObject(with: saved)))
        XCTAssertTrue(String(decoding: saved, as: UTF8.self).contains("\"transmission\""), "the saved scene names the transmission")
        XCTAssertFalse(String(decoding: before, as: UTF8.self).contains("\"transmission\""))
        let old = try JSONDecoder().decode(SceneData.self, from: before)
        XCTAssertNotNil(old.entities.compactMap(\.materialData).first)
        XCTAssertNil(old.entities.compactMap(\.materialData).first?.transmission)
    }
}
