//
//  SceneSerializer.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct SceneData: Codable {
    var schemaVersion: Int? = 2
    var entities: [EntityData] = []
    var sceneAuthoredSource: SceneAssetReference? = nil
    var environment: EnvironmentData? = nil
    var toneMapping: ToneMappingData? = nil
    /// The native Look-pass tonemap operator (see TonemapParams/setPostFX(.tonemapOperator(_))
    /// -- ACES/AgX). Distinct from the legacy `toneMapping` field above, which
    /// backs an older, currently-unused RTX tonemap pass.
    var tonemapOperator: TonemapOperator? = nil
    /// A standalone .cube color-grade LUT set via setColorGradeLUT(filename:),
    /// independent of any scene-authored asset. nil when the active grade LUT
    /// (if any) instead came from sceneAuthoredSource's colorGradeLUT, which is
    /// already restorable via that reference alone.
    var colorGradeLUTFilename: String? = nil
    var colorGradeLUTExtension: String? = nil
    var colorGrading: ColorGradingData? = nil
    var colorCorrection: ColorCorrectionData? = nil
    var bloom: BloomThresholdData? = nil
    var vignette: VignetteData? = nil
    var chromaticAberration: ChromaticAberrationData? = nil
    var depthOfField: DepthOfFieldData? = nil
    var ssao: SSAOData? = nil
    var antiAliasing: AntiAliasingData? = nil
}

enum SceneAssetKind: String, Codable, Equatable {
    case model
    case animation
    case streamModel
    case procedural
}

struct SceneAssetReference: Codable {
    var kind: SceneAssetKind
    /// Asset path. For local assets this is a project-relative path from the asset base folder
    /// (e.g. "Models/Robot/Robot.untold"). For remote stream models this is the full
    /// https:// URL string (e.g. "https://cdn.example.com/dungeon/dungeon.json").
    var path: String
    var displayName: String? = nil
}

struct ToneMappingData: Codable {
    var exposure: Float = 1.0
    var toneMapOperator: Int = 0
    var gamma: Float = 1.0
}

struct ColorGradingData: Codable {
    var brightness: Float = 0.0
    var contrast: Float = 1.0
    var saturation: Float = 1.0
    var exposure: Float = 0.0
    var temperature: Float = 0.0
    var tint: Float = 0.0
    var enabled: Bool? = false
}

struct ColorCorrectionData: Codable {
    var temperature: Float = 0.0 // -1.0 to 1.0 (-1.0 bluish, 0.0 neutral, +1.0 warm, yellowish/orange)
    var tint: Float = 0.0 // -1.0 to 1.0 Green (-)/Magenta (+)
    var lift: simd_float3 = .zero // RGB adjustment for shadows (0 - 2)
    var gamma: simd_float3 = .one // RGB adjustment for midtones (0.5 - 2.5)
    var gain: simd_float3 = .one // RGB adjustment for highlights (0 - 2)
    var enabled: Bool? = false
}

struct BloomThresholdData: Codable {
    var threshold: Float = 1.0 // 0.0 to 5.0
    var intensity: Float = 1.0 // 0.0 to 2.0
    var enabled: Bool? = false
}

struct VignetteData: Codable {
    var intensity: Float = 0.7 // 0.0 to 1.0
    var radius: Float = 0.75 // 0.5 to 1.0
    var softness: Float = 0.45 // 0.0 to 1.0
    var center: simd_float2 = .init(0.5, 0.5) // 0-1
    var enabled: Bool? = false
}

struct ChromaticAberrationData: Codable {
    var intensity: Float = 0.0 // 0.0 to 0.1
    var center: simd_float2 = .init(0.5, 0.5) // 0-1
    var enabled: Bool? = false
}

struct DepthOfFieldData: Codable {
    var focusDistance: Float = 1.0 // 0.0 to 1.0
    var focusRange: Float = 0.1 // 0.01-0.3
    var maxBlur: Float = 0 // 0.005-0.05
    var enabled: Bool? = false
}

struct SSAOData: Codable {
    var radius: Float = 0.5
    var bias: Float = 0.0
    var intensity: Float = 0.0
    var enabled: Bool? = false
}

enum AntiAliasingModeData: String, Codable {
    case none
    case fxaa
    case smaa
    case msaa
}

struct FXAAData: Codable {
    var subpixelQuality: Float = 0.75
    var edgeThreshold: Float = 0.125
    var edgeThresholdMin: Float = 0.0625
}

struct SMAAData: Codable {
    var edgeThreshold: Float = 0.1
}

struct AntiAliasingData: Codable {
    var mode: AntiAliasingModeData = .fxaa
    var fxaa: FXAAData = .init()
    var smaa: SMAAData = .init()
}

struct LightData: Codable {
    var color: simd_float3 = .one
    var radius: Float = 1.0
    var range: Float? = nil
    var intensity: Float = 1.0
    var usesRadiometricUnits: Bool? = nil
    var falloff: Float = 0.5
    var coneAngle: Float = 30.0
    var forward: simd_float3 = .init(0.0, 0.0, -1.0) // Normal vector of the light's surface
    var right: simd_float3 = .init(1.0, 0.0, 0.0) // Right vector defining the surface orientation
    var up: simd_float3 = .init(0.0, 1.0, 0.0) // Up vector defining the surface orientation
    var bounds: simd_float2 = .one
    var twoSided: Bool = false
    var castsShadow: Bool? = nil
}

struct CameraData: Codable {
    var eye: simd_float3 = .zero
    var target: simd_float3 = .zero
    var up: simd_float3 = .init(0.0, 1.0, 0.0)
}

struct EnvironmentData: Codable {
    var applyIBL: Bool? = nil
    var renderEnvironment: Bool? = nil
    var hdr: String? = nil
    var ambientIntensity: Float? = nil
}

struct MaterialData: Codable {
    var baseColorValue: simd_float4 = .zero
    var emissiveValue: simd_float3 = .zero
    var roughnessValue: Float = 1.0
    var metallicValue: Float = 0.0
    var opacity: Float? = nil
    var alphaCutoff: Float? = nil
    var alphaMode: Int32? = nil // MaterialAlphaMode rawValue
    var baseColorURL: URL? = nil
    var roughnessURL: URL? = nil
    var metallicURL: URL? = nil
    var normalURL: URL? = nil
    var heightURL: URL? = nil
    var stScale: Float? = nil
    var baseColorWrapMode: Int? = nil // WrapMode rawValue
    var roughnessWrapMode: Int? = nil // WrapMode rawValue
    var metallicWrapMode: Int? = nil // WrapMode rawValue
    var normalWrapMode: Int? = nil // WrapMode rawValue
    var heightWrapMode: Int? = nil // WrapMode rawValue
    var heightScale: Float? = nil
    var heightMidlevel: Float? = nil
    var heightEnabled: Bool? = nil
    var heightRemapMin: Float? = nil
    var heightRemapMax: Float? = nil
}

// MARK: - Asset Instance Data

struct LocalTransformOverrideData: Codable {
    var position: simd_float3?
    var scale: simd_float3?
    var axisOfRotations: simd_float3?
}

struct AssetOverrideData: Codable {
    var nodePath: String
    var transform: LocalTransformOverrideData?
    var material: MaterialData?
    var visibility: Bool?
    var name: String?
    var pickParticipation: Bool?
    var pickHitRepresentationMode: Int?
    /// Explicit per-node static batching state for derived asset nodes.
    /// true  -> force static for this node
    /// false -> force non-static for this node
    /// nil   -> no override (legacy scenes)
    var hasStaticBatchComponent: Bool?
}

struct AssetInstanceData: Codable {
    var assetURL: URL
    var asset: SceneAssetReference? = nil
    var assetName: String
    var importMode: String // "preserveHierarchy" | "combineMeshes"
    var rootPrimPath: String?
    var overrides: [AssetOverrideData]
}

// MARK: - LOD Data

struct LODLevelData: Codable {
    var url: URL
    var maxDistance: Float
    var screenPercentage: Float
}

struct LODData: Codable {
    var lodLevels: [LODLevelData]
    var currentLOD: Int
    var fadeTransition: Bool
    var transitionDuration: Float
}

// MARK: - Geometry Streaming Data

struct StreamingData: Codable {
    var streamingRadius: Float
    var unloadRadius: Float
    var priority: Int
    var assetFilename: String
    var assetExtension: String
    var assetName: String?
}

struct EntityData: Codable {
    var uuid: UUID = .init() // Unique identifier for this entity
    var parentUUID: UUID? = nil // UUID of the parent entity, if any
    var name: String = "" // entity name
    var assetName: String = "" // asset name in 3D software (legacy)
    // `fileURLWithPath: ""` resolves against the process's current working directory, which
    // leaked machine-specific build paths (e.g. Xcode DerivedData) into entities with no asset.
    // Pin the default to "/" so it's deterministic and never carries local filesystem state.
    var assetURL: URL = .init(fileURLWithPath: "/") // legacy
    var asset: SceneAssetReference? = nil
    var position: simd_float3 = .zero
    var axisOfRotations: simd_float3 = .zero // legacy: stale for quaternion-rotated entities, kept for old-file fallback
    var rotation: simd_float4? = nil // quaternion (x, y, z, w) — source of truth for orientation
    var scale: simd_float3 = .one
    var animations: [URL] = []
    var animationAssets: [SceneAssetReference]? = nil
    var mass: Float = .init(1.0)
    var lightData: LightData? = nil
    var cameraData: CameraData? = nil
    var materialData: MaterialData? = nil
    var hasRenderingComponent: Bool = false // legacy
    var castsShadow: Bool? = nil
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
    var hasDirLightComponent: Bool?
    var hasPointLightComponent: Bool?
    var hasSpotLightComponent: Bool?
    var hasAreaLightComponent: Bool?
    var hasCameraComponent: Bool?
    var hasLODComponent: Bool?
    var hasStaticBatchComponent: Bool?
    var hasStreamingComponent: Bool?
    var pickParticipation: Bool? = nil
    var pickHitRepresentationMode: Int? = nil

    var customComponents: [String: Data]? = nil

    /// New Asset Instance system
    var assetInstance: AssetInstanceData? = nil

    /// LOD system
    var lodData: LODData? = nil

    /// Geometry Streaming system
    var streamingData: StreamingData? = nil
}

private func isProceduralAssetURL(_ url: URL) -> Bool {
    let path = url.path
    return path.hasPrefix("/primitive/") || path.hasPrefix("/fallback/")
}

private func projectRelativeAssetPath(for url: URL) -> String? {
    guard let basePath = assetBasePath else {
        return nil
    }

    let base = basePath.standardizedFileURL.resolvingSymlinksInPath().path
    let target = url.standardizedFileURL.resolvingSymlinksInPath().path
    let prefix = base.hasSuffix("/") ? base : base + "/"

    guard target.hasPrefix(prefix) else {
        return nil
    }

    return String(target.dropFirst(prefix.count))
}

func sceneAssetReference(kind: SceneAssetKind, url: URL, displayName: String? = nil) -> SceneAssetReference? {
    if kind == .procedural || isProceduralAssetURL(url) {
        return SceneAssetReference(kind: .procedural, path: url.path, displayName: displayName)
    }

    // Remote URLs are stored as their full https:// string so they survive round-trips.
    if url.scheme?.lowercased() == "https" {
        return SceneAssetReference(kind: kind, path: url.absoluteString, displayName: displayName)
    }

    guard let relativePath = projectRelativeAssetPath(for: url) else {
        Logger.logWarning(message: "[SceneSerializer] Skipping non-project asset reference: \(url.path)")
        return nil
    }

    return SceneAssetReference(kind: kind, path: relativePath, displayName: displayName)
}

/// Value stored in the legacy (pre-`SceneAssetReference`) `assetURL`/`animations` fields.
/// These fields are kept only so older scene files (saved before the relative-path asset
/// reference system existed) still decode. When we successfully computed a project-relative
/// `reference`, mirror that same relative path here instead of the absolute filesystem URL —
/// otherwise every save re-bakes the current machine's absolute path into the scene file, even
/// though loading always prefers `reference` when it's present.
private func legacyAssetURL(for url: URL, reference: SceneAssetReference?) -> URL {
    guard let reference, reference.kind != .procedural, !reference.path.hasPrefix("https://") else {
        return url
    }
    return URL(string: reference.path) ?? url
}

func resolvedSceneAssetURL(_ reference: SceneAssetReference) -> URL? {
    if reference.kind == .procedural {
        return URL(fileURLWithPath: reference.path)
    }

    // Remote URLs were stored as full https:// strings — return them directly.
    if reference.path.hasPrefix("https://") {
        return URL(string: reference.path)
    }

    guard let basePath = assetBasePath else {
        Logger.logWarning(message: "[SceneSerializer] Cannot resolve asset '\(reference.path)' because assetBasePath is not set")
        return nil
    }

    return basePath.appendingPathComponent(reference.path)
}

private func resourceNameForLoading(from url: URL) -> String {
    let noExtension = url.deletingPathExtension()
    let path = noExtension.path
    if path.hasPrefix("/") || path.hasPrefix("~") {
        return path
    }
    return noExtension.lastPathComponent
}

private func animationURLs(for entityData: EntityData) -> [URL] {
    if let animationAssets = entityData.animationAssets, animationAssets.isEmpty == false {
        return animationAssets.compactMap { resolvedSceneAssetURL($0) }
    }

    return entityData.animations.filter { $0.pathExtension.lowercased() == "untold" }
}

private func applyDeserializedAnimations(entityId: EntityID, entityData: EntityData) {
    let urls = animationURLs(for: entityData)
    guard urls.isEmpty == false else { return }

    for animationURL in urls {
        let animationFilename = resourceNameForLoading(from: animationURL)
        let animationFilenameExt = animationURL.pathExtension
        let animationName = animationURL.deletingPathExtension().lastPathComponent
        setEntityAnimations(entityId: entityId, filename: animationFilename, withExtension: animationFilenameExt, name: animationName)
        changeAnimation(entityId: entityId, name: animationName)
    }

    if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
        animationComponent.animationsFilenames = urls
    }
}

private func appendUniqueURL(_ url: URL, to urls: inout [URL], seen: inout Set<String>) {
    let key = url.standardizedFileURL.path
    guard seen.contains(key) == false else { return }
    seen.insert(key)
    urls.append(url)
}

private func collectDerivedAnimationSourceURLs(rootEntityId: EntityID, currentEntityId: EntityID, urls: inout [URL], seen: inout Set<String>) {
    for childId in getEntityChildren(parentId: currentEntityId) {
        if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childId),
           derived.assetRootEntityId == rootEntityId,
           let animationComponent = scene.get(component: AnimationComponent.self, for: childId)
        {
            for url in animationComponent.animationsFilenames {
                appendUniqueURL(url, to: &urls, seen: &seen)
            }
        }

        collectDerivedAnimationSourceURLs(rootEntityId: rootEntityId, currentEntityId: childId, urls: &urls, seen: &seen)
    }
}

private func collectDerivedAssetNodeIds(rootEntityId: EntityID, currentEntityId: EntityID, derivedEntityIds: inout [EntityID]) {
    for childId in getEntityChildren(parentId: currentEntityId) {
        if let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId),
           derivedComp.assetRootEntityId == rootEntityId
        {
            derivedEntityIds.append(childId)
        }

        collectDerivedAssetNodeIds(rootEntityId: rootEntityId, currentEntityId: childId, derivedEntityIds: &derivedEntityIds)
    }
}

private func derivedAssetNodeIds(rootEntityId: EntityID) -> [EntityID] {
    var derivedEntityIds: [EntityID] = []
    collectDerivedAssetNodeIds(rootEntityId: rootEntityId, currentEntityId: rootEntityId, derivedEntityIds: &derivedEntityIds)
    return derivedEntityIds
}

private func animationSourceURLsForSerialization(entityId: EntityID) -> [URL] {
    var urls: [URL] = []
    var seen = Set<String>()

    if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
        for url in animationComponent.animationsFilenames {
            appendUniqueURL(url, to: &urls, seen: &seen)
        }
    }

    if hasComponent(entityId: entityId, componentType: AssetInstanceComponent.self) {
        collectDerivedAnimationSourceURLs(rootEntityId: entityId, currentEntityId: entityId, urls: &urls, seen: &seen)
    }

    return urls
}

private func isRuntimeGeneratedTiledSceneEntity(_ entityId: EntityID) -> Bool {
    var current: EntityID? = entityId
    while let candidate = current {
        if hasComponent(entityId: candidate, componentType: TileComponent.self) {
            return true
        }
        current = getEntityParent(entityId: candidate)
    }
    return false
}

private func createProceduralMeshes(assetName: String) -> [Mesh] {
    let typeName = assetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if typeName.contains("sphere") {
        return BasicPrimitives.createSphere()
    }
    if typeName.contains("plane") {
        return BasicPrimitives.createPlane()
    }
    if typeName.contains("cylinder") {
        return BasicPrimitives.createCylinder()
    }
    if typeName.contains("cone") {
        return BasicPrimitives.createCone()
    }
    // Default to cube
    return BasicPrimitives.createCube()
}

private func applyDeserializedLocalTransform(entityId: EntityID, entityData: EntityData) {
    guard entityData.hasLocalTransformComponent == true else { return }
    translateTo(entityId: entityId, position: entityData.position)
    scaleTo(entityId: entityId, scale: entityData.scale)
    // Prefer the quaternion (exact, matches whatever actually rotated the entity — gizmo drag,
    // lookAt, light defaults, etc). axisOfRotations is a legacy fallback for scenes saved before
    // this field existed; it can be stale for entities that were only ever rotated via the
    // quaternion-based APIs, since those never wrote back to rotationX/Y/Z.
    if let rotation = entityData.rotation {
        rotateTo(entityId: entityId, rotation: simd_quatf(vector: rotation))
    } else {
        applyAxisRotations(entityId: entityId, axis: entityData.axisOfRotations)
    }
}

private func applyDeserializedRenderProperties(entityId: EntityID, entityData: EntityData) {
    guard scene.get(component: RenderComponent.self, for: entityId) != nil else { return }
    if let castsShadow = entityData.castsShadow {
        setEntityCastsShadow(entityId: entityId, castsShadow)
    }
}

/// Applies saved material overrides (colors, scalars, texture URLs, wrap modes) to an entity.
/// Must run only once the entity's mesh/submeshes actually exist — updateMaterial's material-slot
/// lookup silently no-ops otherwise, which previously dropped every texture reassignment made
/// through the Inspector because this ran before setEntityMeshAsync's completion fired.
private func applyDeserializedMaterialData(entityId: EntityID, entityData: EntityData) {
    guard let materialData = entityData.materialData else { return }

    let baseColorValue: simd_float4 = materialData.baseColorValue
    let roughnessValue: Float = materialData.roughnessValue
    let metallicValue: Float = materialData.metallicValue
    let emissiveValue: simd_float3 = materialData.emissiveValue

    updateMaterialColor(entityId: entityId, color: colorFromSimd(baseColorValue))
    updateMaterialRoughness(entityId: entityId, roughness: roughnessValue)
    updateMaterialMetallic(entityId: entityId, metallic: metallicValue)
    updateMaterialEmmisive(entityId: entityId, emmissive: emissiveValue)
    if let opacity = materialData.opacity {
        updateMaterialOpacity(entityId: entityId, opacity: opacity)
    }
    if let alphaCutoff = materialData.alphaCutoff {
        updateMaterialAlphaCutoff(entityId: entityId, cutoff: alphaCutoff)
    }
    if let alphaModeRawValue = materialData.alphaMode,
       let alphaMode = MaterialAlphaMode(rawValue: alphaModeRawValue)
    {
        updateMaterialAlphaMode(entityId: entityId, mode: alphaMode)
    }

    if let baseColorURL = materialData.baseColorURL {
        updateMaterialTexture(entityId: entityId, textureType: .baseColor, path: baseColorURL)
    }

    if let roughnessURL = materialData.roughnessURL {
        updateMaterialTexture(entityId: entityId, textureType: .roughness, path: roughnessURL)
    }

    if let metallicURL = materialData.metallicURL {
        updateMaterialTexture(entityId: entityId, textureType: .metallic, path: metallicURL)
    }

    if let normalURL = materialData.normalURL {
        updateMaterialTexture(entityId: entityId, textureType: .normal, path: normalURL)
    }

    if let heightURL = materialData.heightURL {
        updateMaterialTexture(entityId: entityId, textureType: .height, path: heightURL)
    }

    if let stScale = materialData.stScale {
        updateMaterialSTScale(entityId: entityId, stScale: stScale)
    }

    if let heightScale = materialData.heightScale {
        updateMaterialHeightScale(entityId: entityId, heightScale: heightScale)
    }

    if let heightMidlevel = materialData.heightMidlevel {
        updateMaterialHeightMidlevel(entityId: entityId, heightMidlevel: heightMidlevel)
    }

    if let heightEnabled = materialData.heightEnabled {
        updateMaterialHeightEnabled(entityId: entityId, heightEnabled: heightEnabled)
    }

    if let heightRemapMin = materialData.heightRemapMin {
        updateMaterialHeightRemapMin(entityId: entityId, heightRemapMin: heightRemapMin)
    }

    if let heightRemapMax = materialData.heightRemapMax {
        updateMaterialHeightRemapMax(entityId: entityId, heightRemapMax: heightRemapMax)
    }

    if let baseColorWrapModeRawValue = materialData.baseColorWrapMode,
       let wrapMode = WrapMode(rawValue: baseColorWrapModeRawValue)
    {
        updateTextureSampler(entityId: entityId, textureType: .baseColor, wrapMode: wrapMode)
    }

    if let roughnessWrapModeRawValue = materialData.roughnessWrapMode,
       let wrapMode = WrapMode(rawValue: roughnessWrapModeRawValue)
    {
        updateTextureSampler(entityId: entityId, textureType: .roughness, wrapMode: wrapMode)
    }

    if let metallicWrapModeRawValue = materialData.metallicWrapMode,
       let wrapMode = WrapMode(rawValue: metallicWrapModeRawValue)
    {
        updateTextureSampler(entityId: entityId, textureType: .metallic, wrapMode: wrapMode)
    }

    if let normalWrapModeRawValue = materialData.normalWrapMode,
       let wrapMode = WrapMode(rawValue: normalWrapModeRawValue)
    {
        updateTextureSampler(entityId: entityId, textureType: .normal, wrapMode: wrapMode)
    }

    if let heightWrapModeRawValue = materialData.heightWrapMode,
       let wrapMode = WrapMode(rawValue: heightWrapModeRawValue)
    {
        updateTextureSampler(entityId: entityId, textureType: .height, wrapMode: wrapMode)
    }
}

public func serializeScene() -> SceneData {
    var sceneData = SceneData()
    sceneData.sceneAuthoredSource = SceneAuthoredSourceStore.shared.source
    var entityIdToUUID: [EntityID: UUID] = [:]

    var authoredEntityCount = 0
    var derivedEntityCount = 0

    // assign UUIDs only to authored entities (skip derived/runtime-generated nodes)
    for entityId in getAllGameEntities() {
        // Skip derived asset nodes and generated stream tiles - they will be recreated on import
        if hasComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self)
            || isRuntimeGeneratedTiledSceneEntity(entityId)
        {
            derivedEntityCount += 1
            continue
        }

        let uuid = UUID()
        entityIdToUUID[entityId] = uuid
        authoredEntityCount += 1
    }

    Logger.log(message: "[SceneSerializer] Serializing \(authoredEntityCount) authored entities, skipping \(derivedEntityCount) derived nodes")

    for entityId in getAllGameEntities() {
        // Skip derived asset nodes and generated stream tiles
        if hasComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self)
            || isRuntimeGeneratedTiledSceneEntity(entityId)
        {
            continue
        }

        var entityData = EntityData()

        // assign uuid
        entityData.uuid = entityIdToUUID[entityId]!

        // parent uuid (if any)
        if let parentId = getEntityParent(entityId: entityId) {
            entityData.parentUUID = entityIdToUUID[parentId]
        }

        entityData.name = getEntityName(entityId: entityId)

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            entityData.assetName = renderComponent.assetName
            entityData.castsShadow = renderComponent.castsShadow

            let assetKind: SceneAssetKind = isProceduralAssetURL(renderComponent.assetURL) ? .procedural : .model
            entityData.asset = sceneAssetReference(
                kind: assetKind,
                url: renderComponent.assetURL,
                displayName: renderComponent.assetName.isEmpty ? nil : renderComponent.assetName
            )
            entityData.assetURL = legacyAssetURL(for: renderComponent.assetURL, reference: entityData.asset)

            // material data
            let baseColor: simd_float4 = getMaterialBaseColor(entityId: entityId)
            let roughnessValue: Float = getMaterialRoughness(entityId: entityId)
            let metallicValue: Float = getMaterialMetallic(entityId: entityId)
            let emissiveValue: simd_float3 = getMaterialEmmissive(entityId: entityId)
            let opacity: Float = getMaterialOpacity(entityId: entityId)
            let alphaCutoff: Float = getMaterialAlphaCutoff(entityId: entityId)
            let alphaModeRawValue: Int32 = getMaterialAlphaMode(entityId: entityId).rawValue

            var baseColorURL: URL?
            var roughnessURL: URL?
            var metallicURL: URL?
            var normalURL: URL?
            var heightURL: URL?

            if let baseColorTexture: URL = getMaterialTextureURL(entityId: entityId, type: .baseColor) {
                baseColorURL = baseColorTexture
            }

            if let roughnessTexture: URL = getMaterialTextureURL(entityId: entityId, type: .roughness) {
                roughnessURL = roughnessTexture
            }

            if let metallicTexture: URL = getMaterialTextureURL(entityId: entityId, type: .metallic) {
                metallicURL = metallicTexture
            }

            if let normalTexture: URL = getMaterialTextureURL(entityId: entityId, type: .normal) {
                normalURL = normalTexture
            }

            if let heightTexture: URL = getMaterialTextureURL(entityId: entityId, type: .height) {
                heightURL = heightTexture
            }

            let stScale: Float = getMaterialSTScale(entityId: entityId)
            let heightScale: Float = getMaterialHeightScale(entityId: entityId)
            let heightMidlevel: Float = getMaterialHeightMidlevel(entityId: entityId)
            let heightEnabled: Bool = getMaterialHeightEnabled(entityId: entityId)
            let heightRemapMin: Float = getMaterialHeightRemapMin(entityId: entityId)
            let heightRemapMax: Float = getMaterialHeightRemapMax(entityId: entityId)
            let baseColorWrapMode = getTextureWrapMode(entityId: entityId, textureType: .baseColor)?.rawValue
            let roughnessWrapMode = getTextureWrapMode(entityId: entityId, textureType: .roughness)?.rawValue
            let metallicWrapMode = getTextureWrapMode(entityId: entityId, textureType: .metallic)?.rawValue
            let normalWrapMode = getTextureWrapMode(entityId: entityId, textureType: .normal)?.rawValue
            let heightWrapMode = getTextureWrapMode(entityId: entityId, textureType: .height)?.rawValue

            entityData.materialData = MaterialData(
                baseColorValue: baseColor,
                emissiveValue: emissiveValue,
                roughnessValue: roughnessValue,
                metallicValue: metallicValue,
                opacity: opacity,
                alphaCutoff: alphaCutoff,
                alphaMode: alphaModeRawValue,
                baseColorURL: baseColorURL,
                roughnessURL: roughnessURL,
                metallicURL: metallicURL,
                normalURL: normalURL,
                heightURL: heightURL,
                stScale: stScale,
                baseColorWrapMode: baseColorWrapMode,
                roughnessWrapMode: roughnessWrapMode,
                metallicWrapMode: metallicWrapMode,
                normalWrapMode: normalWrapMode,
                heightWrapMode: heightWrapMode,
                heightScale: heightScale,
                heightMidlevel: heightMidlevel,
                heightEnabled: heightEnabled,
                heightRemapMin: heightRemapMin,
                heightRemapMax: heightRemapMax
            )
        }

        // Rendering properties
        entityData.hasRenderingComponent = hasComponent(entityId: entityId, componentType: RenderComponent.self)
        if let pickInteractionComponent = scene.get(component: PickInteractionComponent.self, for: entityId) {
            entityData.pickParticipation = pickInteractionComponent.participatesInPicking
            entityData.pickHitRepresentationMode = pickInteractionComponent.hitRepresentationMode.rawValue
        }

        // Transform properties
        if scene.get(component: LocalTransformComponent.self, for: entityId) != nil {
            entityData.position = getLocalPosition(entityId: entityId)
            entityData.scale = getScale(entityId: entityId)
            let axisOfRotations = getAxisRotations(entityId: entityId)

            entityData.axisOfRotations = axisOfRotations
            entityData.rotation = getRotationQuaternion(entityId: entityId).vector
        }

        entityData.hasLocalTransformComponent = hasComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        // Animation properties. For hierarchical runtime assets, AnimationComponent may
        // live on a derived skeleton child that is skipped by scene serialization, so
        // asset roots collect animation source URLs from their derived descendants.
        let animationSourceURLs = animationSourceURLsForSerialization(entityId: entityId)
        if animationSourceURLs.isEmpty == false {
            let animationReferences = animationSourceURLs.map {
                sceneAssetReference(kind: .animation, url: $0, displayName: $0.deletingPathExtension().lastPathComponent)
            }
            entityData.animations = zip(animationSourceURLs, animationReferences).map(legacyAssetURL(for:reference:))
            let validReferences = animationReferences.compactMap { $0 }
            entityData.animationAssets = validReferences.isEmpty ? nil : validReferences
        }

        entityData.hasAnimationComponent = animationSourceURLs.isEmpty == false || hasComponent(entityId: entityId, componentType: AnimationComponent.self)

        if let tiledSceneComponent = scene.get(component: TiledSceneComponent.self, for: entityId),
           let manifestURL = tiledSceneComponent.manifestURL
        {
            entityData.asset = sceneAssetReference(
                kind: .streamModel,
                url: manifestURL,
                displayName: tiledSceneComponent.manifestLabel.isEmpty ? nil : tiledSceneComponent.manifestLabel
            )
        }

        // Kinetic properties
        entityData.mass = getMass(entityId: entityId)

        entityData.hasKineticComponent = hasComponent(entityId: entityId, componentType: KineticComponent.self)

        // Dir Light properties
        let hasDirLight: Bool = hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self)

        if hasDirLight {
            entityData.hasDirLightComponent = hasDirLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)
            entityData.lightData?.usesRadiometricUnits = scene.get(component: LightComponent.self, for: entityId)?.usesRadiometricUnits
            entityData.lightData?.castsShadow = scene.get(component: DirectionalLightComponent.self, for: entityId)?.castsShadow
        }

        // Point Light properties
        let hasPointLight: Bool = hasComponent(entityId: entityId, componentType: PointLightComponent.self)

        if hasPointLight {
            entityData.hasPointLightComponent = hasPointLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.radius = getLightRadius(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)
            entityData.lightData?.falloff = getLightFalloff(entityId: entityId)
            entityData.lightData?.castsShadow = getPointLightCastsShadow(entityId: entityId)
            entityData.lightData?.range = scene.get(component: PointLightComponent.self, for: entityId)?.range
            entityData.lightData?.usesRadiometricUnits = scene.get(component: LightComponent.self, for: entityId)?.usesRadiometricUnits
        }

        // Spot light properties
        let hasSpotLight: Bool = hasComponent(entityId: entityId, componentType: SpotLightComponent.self)

        if hasSpotLight {
            entityData.hasSpotLightComponent = hasSpotLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.radius = getLightRadius(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)

            entityData.lightData?.falloff = getLightFalloff(entityId: entityId)

            entityData.lightData?.coneAngle = getLightConeAngle(entityId: entityId)

            entityData.lightData?.castsShadow = getSpotLightCastsShadow(entityId: entityId)
            entityData.lightData?.range = scene.get(component: SpotLightComponent.self, for: entityId)?.range
            entityData.lightData?.usesRadiometricUnits = scene.get(component: LightComponent.self, for: entityId)?.usesRadiometricUnits
        }

        // Area light properties
        let hasAreaLight: Bool = hasComponent(entityId: entityId, componentType: AreaLightComponent.self)

        if hasAreaLight {
            entityData.hasAreaLightComponent = hasAreaLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)
            entityData.lightData?.forward = getForwardAxisVector(entityId: entityId)

            entityData.lightData?.right = getRightAxisVector(entityId: entityId)

            entityData.lightData?.up = getUpAxisVector(entityId: entityId)

            let (width, height, _) = getDimension(entityId: entityId)

            entityData.lightData?.bounds = simd_float2(width, height)

            if let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) {
                entityData.lightData?.twoSided = areaLightComponent.twoSided
                entityData.lightData?.range = areaLightComponent.range
                entityData.lightData?.castsShadow = areaLightComponent.castsShadow
            }
            entityData.lightData?.usesRadiometricUnits = scene.get(component: LightComponent.self, for: entityId)?.usesRadiometricUnits
        }

        // Camera properties
        let hasCamera: Bool = hasComponent(entityId: entityId, componentType: CameraComponent.self)

        if hasCamera {
            entityData.hasCameraComponent = hasCamera

            entityData.cameraData = CameraData()

            entityData.cameraData?.eye = getCameraEye(entityId: entityId)
            entityData.cameraData?.target = getCameraTarget(entityId: entityId)
            entityData.cameraData?.up = getCameraUp(entityId: entityId)
        }

        // LOD properties
        let hasLOD: Bool = hasComponent(entityId: entityId, componentType: LODComponent.self)

        if hasLOD {
            entityData.hasLODComponent = hasLOD

            if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
                var lodLevelsData: [LODLevelData] = []

                for lodLevel in lodComponent.lodLevels {
                    // Only serialize if URL is available
                    if let url = lodLevel.url {
                        let lodLevelData = LODLevelData(
                            url: url,
                            maxDistance: lodLevel.maxDistance,
                            screenPercentage: lodLevel.screenPercentage
                        )
                        lodLevelsData.append(lodLevelData)
                    }
                }

                if !lodLevelsData.isEmpty {
                    entityData.lodData = LODData(
                        lodLevels: lodLevelsData,
                        currentLOD: lodComponent.currentLOD,
                        fadeTransition: lodComponent.fadeTransition,
                        transitionDuration: lodComponent.transitionDuration
                    )
                }
            }
        }

        /// Static Batch properties
        /// Check if entity or any of its children have StaticBatchComponent
        func hasStaticBatchInHierarchy(entityId: EntityID) -> Bool {
            // Check self
            if hasComponent(entityId: entityId, componentType: StaticBatchComponent.self) {
                return true
            }
            // Check children recursively
            let children = getEntityChildren(parentId: entityId)
            for child in children {
                if hasStaticBatchInHierarchy(entityId: child) {
                    return true
                }
            }
            return false
        }

        // Only set the flag if true (leave as nil otherwise)
        if hasStaticBatchInHierarchy(entityId: entityId) {
            entityData.hasStaticBatchComponent = true
        }

        // Geometry Streaming properties
        let hasStreaming: Bool = hasComponent(entityId: entityId, componentType: StreamingComponent.self)

        if hasStreaming {
            entityData.hasStreamingComponent = hasStreaming

            if let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) {
                entityData.streamingData = StreamingData(
                    streamingRadius: streamingComponent.streamingRadius,
                    unloadRadius: streamingComponent.unloadRadius,
                    priority: streamingComponent.priority,
                    assetFilename: streamingComponent.assetFilename,
                    assetExtension: streamingComponent.assetExtension,
                    assetName: streamingComponent.assetName
                )
            }
        }

        // custom component
        var customComponents: [String: Data] = [:]

        // Serialize every registered custom component; the closure returns nil if the entity doesn’t have it
        for (encKey, serialize) in customComponentEncoderMap {
            if let data = serialize(entityId),
               let typeName = customComponentTypeNameById[encKey]
            {
                customComponents[typeName] = data
            }
        }

        entityData.customComponents = customComponents

        // Check if this is an Asset Instance root
        if let assetInstanceComp = scene.get(component: AssetInstanceComponent.self, for: entityId) {
            // Collect overrides from derived descendants
            var overrides: [AssetOverrideData] = []

            for childId in derivedAssetNodeIds(rootEntityId: entityId) {
                if let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) {
                    // Only collect overrides if the derived node belongs to this asset instance
                    if derivedComp.assetRootEntityId == entityId {
                        // MVP: always serialize derived node state (we don't track "initial" values yet)
                        let transformOverride = LocalTransformOverrideData(
                            position: getLocalPosition(entityId: childId),
                            scale: getScale(entityId: childId),
                            axisOfRotations: getAxisRotations(entityId: childId)
                        )

                        var materialOverride: MaterialData? = nil
                        if hasComponent(entityId: childId, componentType: RenderComponent.self) {
                            let baseColor = getMaterialBaseColor(entityId: childId)
                            let roughness = getMaterialRoughness(entityId: childId)
                            let metallic = getMaterialMetallic(entityId: childId)
                            let emissive = getMaterialEmmissive(entityId: childId)
                            let opacity = getMaterialOpacity(entityId: childId)
                            let alphaCutoff = getMaterialAlphaCutoff(entityId: childId)
                            let alphaModeRawValue = getMaterialAlphaMode(entityId: childId).rawValue
                            let stScale = getMaterialSTScale(entityId: childId)
                            let heightScale = getMaterialHeightScale(entityId: childId)
                            let heightMidlevel = getMaterialHeightMidlevel(entityId: childId)
                            let heightEnabled = getMaterialHeightEnabled(entityId: childId)
                            let heightRemapMin = getMaterialHeightRemapMin(entityId: childId)
                            let heightRemapMax = getMaterialHeightRemapMax(entityId: childId)
                            let baseColorWrapMode = getTextureWrapMode(entityId: childId, textureType: .baseColor)?.rawValue
                            let roughnessWrapMode = getTextureWrapMode(entityId: childId, textureType: .roughness)?.rawValue
                            let metallicWrapMode = getTextureWrapMode(entityId: childId, textureType: .metallic)?.rawValue
                            let normalWrapMode = getTextureWrapMode(entityId: childId, textureType: .normal)?.rawValue
                            let heightWrapMode = getTextureWrapMode(entityId: childId, textureType: .height)?.rawValue
                            let baseColorURL = getMaterialTextureURL(entityId: childId, type: .baseColor)
                            let roughnessURL = getMaterialTextureURL(entityId: childId, type: .roughness)
                            let metallicURL = getMaterialTextureURL(entityId: childId, type: .metallic)
                            let normalURL = getMaterialTextureURL(entityId: childId, type: .normal)
                            let heightURL = getMaterialTextureURL(entityId: childId, type: .height)
                            materialOverride = MaterialData(
                                baseColorValue: baseColor,
                                emissiveValue: emissive,
                                roughnessValue: roughness,
                                metallicValue: metallic,
                                opacity: opacity,
                                alphaCutoff: alphaCutoff,
                                alphaMode: alphaModeRawValue,
                                baseColorURL: baseColorURL,
                                roughnessURL: roughnessURL,
                                metallicURL: metallicURL,
                                normalURL: normalURL,
                                heightURL: heightURL,
                                stScale: stScale,
                                baseColorWrapMode: baseColorWrapMode,
                                roughnessWrapMode: roughnessWrapMode,
                                metallicWrapMode: metallicWrapMode,
                                normalWrapMode: normalWrapMode,
                                heightWrapMode: heightWrapMode,
                                heightScale: heightScale,
                                heightMidlevel: heightMidlevel,
                                heightEnabled: heightEnabled,
                                heightRemapMin: heightRemapMin,
                                heightRemapMax: heightRemapMax
                            )
                        }

                        let visibilityOverride: Bool? = nil // TODO: track visibility if needed

                        let entityName = getEntityName(entityId: childId)

                        let override = AssetOverrideData(
                            nodePath: derivedComp.nodePath,
                            transform: transformOverride,
                            material: materialOverride,
                            visibility: visibilityOverride,
                            name: entityName,
                            pickParticipation: scene.get(component: PickInteractionComponent.self, for: childId)?.participatesInPicking,
                            pickHitRepresentationMode: scene.get(component: PickInteractionComponent.self, for: childId)?.hitRepresentationMode.rawValue,
                            hasStaticBatchComponent: hasComponent(entityId: childId, componentType: StaticBatchComponent.self)
                        )
                        overrides.append(override)
                    }
                }
            }

            let assetInstanceReference = sceneAssetReference(kind: .model, url: assetInstanceComp.assetURL, displayName: assetInstanceComp.assetName)
            entityData.assetInstance = AssetInstanceData(
                assetURL: legacyAssetURL(for: assetInstanceComp.assetURL, reference: assetInstanceReference),
                asset: assetInstanceReference,
                assetName: assetInstanceComp.assetName,
                importMode: assetInstanceComp.importMode,
                rootPrimPath: assetInstanceComp.rootPrimPath,
                overrides: overrides
            )

            Logger.log(message: "[SceneSerializer] Asset instance '\(entityData.name)' serialized with \(overrides.count) overrides")
        }

        sceneData.entities.append(entityData)
    }

    // Persist the HDR choice and environment toggles independently. IBL and
    // environment rendering are separate controls in the editor.
    if applyIBL || renderEnvironment || hdrURL.isEmpty == false {
        var validatedHDR: String? = hdrURL
        var shouldApplyIBL = applyIBL

        if hdrURL.isEmpty == false {
            var hdrExists = false

            // Check in user's asset base path (HDR folder)
            if let basePath = assetBasePath {
                let hdrPath = basePath.appendingPathComponent("HDR").appendingPathComponent(hdrURL)
                hdrExists = FileManager.default.fileExists(atPath: hdrPath.path)

                if !hdrExists {
                    Logger.logWarning(message: "[SceneSerializer] HDR file not found in assets: \(hdrURL), disabling IBL")
                    validatedHDR = nil
                    shouldApplyIBL = false
                }
            } else {
                // No asset base path set, can't validate
                Logger.logWarning(message: "[SceneSerializer] No asset base path set, cannot validate HDR")
                validatedHDR = nil
                shouldApplyIBL = false
            }
        }

        if shouldApplyIBL || renderEnvironment || validatedHDR != nil {
            sceneData.environment = EnvironmentData(
                applyIBL: shouldApplyIBL,
                renderEnvironment: renderEnvironment,
                hdr: validatedHDR,
                ambientIntensity: ambientIntensity
            )
        }
    }

    // Load post-process data
    sceneData.toneMapping = ToneMappingData(
        toneMapOperator: ToneMappingParams.shared.toneMapOperator,
        gamma: ToneMappingParams.shared.gamma
    )

    sceneData.tonemapOperator = TonemapParams.shared.operator
    if let source = ColorGradeLUTParams.shared.source {
        sceneData.colorGradeLUTFilename = source.filename
        sceneData.colorGradeLUTExtension = source.extension
    }

    sceneData.colorCorrection = ColorCorrectionData(
        lift: ColorCorrectionParams.shared.lift,
        gamma: ColorCorrectionParams.shared.gamma,
        gain: ColorCorrectionParams.shared.gain,
        enabled: ColorCorrectionParams.shared.enabled
    )

    sceneData.colorGrading = ColorGradingData(
        brightness: ColorGradingParams.shared.brightness,
        contrast: ColorGradingParams.shared.contrast,
        saturation: ColorGradingParams.shared.saturation,
        exposure: ColorGradingParams.shared.exposure,
        temperature: ColorGradingParams.shared.temperature,
        tint: ColorGradingParams.shared.tint,
        enabled: ColorGradingParams.shared.enabled
    )

    sceneData.bloom = BloomThresholdData(threshold: BloomThresholdParams.shared.threshold, intensity: BloomThresholdParams.shared.intensity, enabled: BloomThresholdParams.shared.enabled)

    sceneData.vignette = VignetteData(intensity: VignetteParams.shared.intensity, radius: VignetteParams.shared.radius, softness: VignetteParams.shared.softness, center: VignetteParams.shared.center, enabled: VignetteParams.shared.enabled)

    sceneData.chromaticAberration = ChromaticAberrationData(intensity: ChromaticAberrationParams.shared.intensity, center: ChromaticAberrationParams.shared.center, enabled: ChromaticAberrationParams.shared.enabled)

    sceneData.depthOfField = DepthOfFieldData(focusDistance: DepthOfFieldParams.shared.focusDistance, focusRange: DepthOfFieldParams.shared.focusRange, maxBlur: DepthOfFieldParams.shared.maxBlur, enabled: DepthOfFieldParams.shared.enabled)

    sceneData.ssao = SSAOData(radius: SSAOParams.shared.radius, bias: SSAOParams.shared.bias, intensity: SSAOParams.shared.intensity, enabled: SSAOParams.shared.enabled)

    let antiAliasingModeData: AntiAliasingModeData
    switch antiAliasingMode {
    case .none:
        antiAliasingModeData = .none
    case .fxaa:
        antiAliasingModeData = .fxaa
    case .smaa:
        antiAliasingModeData = .smaa
    case .msaa:
        antiAliasingModeData = .msaa
    }
    sceneData.antiAliasing = AntiAliasingData(
        mode: antiAliasingModeData,
        fxaa: FXAAData(
            subpixelQuality: FXAAParams.shared.subpixelQuality,
            edgeThreshold: FXAAParams.shared.edgeThreshold,
            edgeThresholdMin: FXAAParams.shared.edgeThresholdMin
        ),
        smaa: SMAAData(edgeThreshold: SMAAParams.shared.edgeThreshold)
    )

    // Intentionally not persisting `assetBasePath`: it's an absolute, machine-specific
    // filesystem path. Baking it into the scene file breaks portability when the project
    // (and its .untoldscene files) is shared or checked into version control. Consumers
    // should establish assetBasePath themselves (e.g. via setupAssetPaths()).

    return sceneData
}

public func loadGameScene(from url: URL) -> SceneData? {
    // Ensure it's a file URL
    guard url.isFileURL else {
        Logger.log(message: "Invalid URL: must be a file URL")
        return nil
    }

    // Check if file exists and is readable
    guard FileManager.default.isReadableFile(atPath: url.path) else {
        Logger.log(message: "File not accesible or doesn't exist: \(url.path)")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let scene = try JSONDecoder().decode(SceneData.self, from: data)
        Logger.log(message: "Scene loaded from \(url.path)")
        return scene
    } catch {
        Logger.log(message: "Failed to load scene: \(error)")
        return nil
    }
}

public enum MeshLoadingMode: Sendable {
    case asyncDefault
    case sync
}

/// Tracks async loading operations during scene deserialization
private struct VoidCompletionBox: @unchecked Sendable {
    let callback: () -> Void

    func call() {
        if Thread.isMainThread {
            callback()
            return
        }
        Task { @MainActor in
            callback()
        }
    }
}

private final class AsyncLoadTracker: @unchecked Sendable {
    private var pendingLoads = 0
    private var completedLoads = 0
    private var didFinishRegistration = false
    private var didCallCompletion = false
    private let lock = NSLock()
    var completion: VoidCompletionBox?

    /// Register a new async operation
    func registerLoad() {
        lock.lock()
        pendingLoads += 1
        lock.unlock()
    }

    /// Mark an async operation as complete
    func completeLoad() {
        lock.lock()
        completedLoads += 1
        let callback = completionIfReadyLocked()
        lock.unlock()

        dispatchCompletion(callback)
    }

    /// Marks registration as complete and resolves completion if all async work is done.
    func finishRegistration() {
        lock.lock()
        didFinishRegistration = true
        let callback = completionIfReadyLocked()
        lock.unlock()

        dispatchCompletion(callback)
    }

    private func completionIfReadyLocked() -> VoidCompletionBox? {
        guard didFinishRegistration, didCallCompletion == false else {
            return nil
        }

        guard completedLoads >= pendingLoads else {
            return nil
        }

        didCallCompletion = true
        return completion
    }

    private func dispatchCompletion(_ callback: VoidCompletionBox?) {
        callback?.call()
    }
}

public func deserializeScene(
    sceneData: SceneData,
    meshLoadingMode: MeshLoadingMode = .asyncDefault,
    completion: (() -> Void)? = nil
) {
    var uuidToEntityMap: [UUID: EntityID] = [:]

    // Track async loading operations for completion callback
    let loadTracker = AsyncLoadTracker()
    loadTracker.completion = VoidCompletionBox(callback: {
        // Finalize static-batch membership for authored entities after all async imports finish.
        // This preserves explicit opt-outs (entity flag not true) even if an ancestor marked
        // static re-applied recursive tagging during mesh restoration.
        withWorldMutationGate {
            for sceneDataEntity in sceneData.entities {
                guard let entityId = uuidToEntityMap[sceneDataEntity.uuid] else { continue }
                if sceneDataEntity.hasStaticBatchComponent != true {
                    removeEntityStaticBatch(entityId: entityId)
                }
            }
        }
        completion?()
    })

    if let sceneAuthoredSource = sceneData.sceneAuthoredSource {
        loadTracker.registerLoad()
        let standaloneLUTFilename = sceneData.colorGradeLUTFilename
        let standaloneLUTExtension = sceneData.colorGradeLUTExtension
        loadSceneAuthoredColorManagement(from: sceneAuthoredSource) { success in
            if success == false {
                Logger.logWarning(message: "[SceneSerializer] Failed to restore scene-authored color management")
            }
            // Applied after scene-authored restoration completes so a standalone
            // choice (set independently of any scene asset) always wins over
            // whatever colorGradeLUT the scene-authored source itself carries.
            if let filename = standaloneLUTFilename {
                setColorGradeLUT(filename: filename, withExtension: standaloneLUTExtension ?? "cube")
            }
            loadTracker.completeLoad()
        }
    } else {
        SceneAuthoredSourceStore.shared.clear()
        ColorLUTParams.shared.clear()
        ColorGradeLUTParams.shared.clear()
        if let filename = sceneData.colorGradeLUTFilename {
            setColorGradeLUT(filename: filename, withExtension: sceneData.colorGradeLUTExtension ?? "cube")
        }
    }

    if let tonemapOperator = sceneData.tonemapOperator {
        TonemapParams.shared.operator = tonemapOperator
    }

    if let env = sceneData.environment {
        applyIBL = env.applyIBL ?? false
        renderEnvironment = env.renderEnvironment ?? false
        ambientIntensity = env.ambientIntensity ?? 0.4

        if let hdr = env.hdr, !hdr.isEmpty {
            hdrURL = hdr
            setRendering(.environment(.asset(hdr)))
            hdrURL = hdr
        } else {
            hdrURL = ""
        }
    } else {
        applyIBL = false
        renderEnvironment = false
        ambientIntensity = 0.4
        hdrURL = ""
    }

    if let colorGrading = sceneData.colorGrading {
        ColorGradingParams.shared.brightness = colorGrading.brightness
        ColorGradingParams.shared.contrast = colorGrading.contrast
        ColorGradingParams.shared.saturation = colorGrading.saturation
        ColorGradingParams.shared.exposure = colorGrading.exposure
        ColorGradingParams.shared.temperature = colorGrading.temperature
        ColorGradingParams.shared.tint = colorGrading.tint
        if let enabled = colorGrading.enabled {
            ColorGradingParams.shared.enabled = enabled
        }
    }

    if let colorCorrection = sceneData.colorCorrection {
        ColorCorrectionParams.shared.lift = colorCorrection.lift
        ColorCorrectionParams.shared.gamma = colorCorrection.gamma
        ColorCorrectionParams.shared.gain = colorCorrection.gain
        if let enabled = colorCorrection.enabled {
            ColorCorrectionParams.shared.enabled = enabled
        }
    }

    if let bloomThreshold = sceneData.bloom {
        BloomThresholdParams.shared.intensity = bloomThreshold.intensity
        BloomThresholdParams.shared.threshold = bloomThreshold.threshold
        if let enabled = bloomThreshold.enabled {
            BloomThresholdParams.shared.enabled = enabled
        }
    }

    if let vignette = sceneData.vignette {
        VignetteParams.shared.intensity = vignette.intensity
        VignetteParams.shared.radius = vignette.radius
        VignetteParams.shared.softness = vignette.softness
        VignetteParams.shared.center = vignette.center
        if let enabled = vignette.enabled {
            VignetteParams.shared.enabled = enabled
        }
    }

    if let chromaticAberration = sceneData.chromaticAberration {
        ChromaticAberrationParams.shared.intensity = chromaticAberration.intensity
        ChromaticAberrationParams.shared.center = chromaticAberration.center
        if let enabled = chromaticAberration.enabled {
            ChromaticAberrationParams.shared.enabled = enabled
        }
    }

    if let depthOfField = sceneData.depthOfField {
        DepthOfFieldParams.shared.focusDistance = depthOfField.focusDistance
        DepthOfFieldParams.shared.focusRange = depthOfField.focusRange
        DepthOfFieldParams.shared.maxBlur = depthOfField.maxBlur
        if let enabled = depthOfField.enabled {
            DepthOfFieldParams.shared.enabled = enabled
        }
    }

    if let ssao = sceneData.ssao {
        SSAOParams.shared.radius = ssao.radius
        SSAOParams.shared.intensity = ssao.intensity
        SSAOParams.shared.bias = ssao.bias
        if let enabled = ssao.enabled {
            SSAOParams.shared.enabled = enabled
        }
    }

    if let antiAliasing = sceneData.antiAliasing {
        switch antiAliasing.mode {
        case .none:
            antiAliasingMode = .none
        case .fxaa:
            antiAliasingMode = .fxaa
        case .smaa:
            antiAliasingMode = .smaa
        case .msaa:
            antiAliasingMode = .msaa
        }

        FXAAParams.shared.subpixelQuality = antiAliasing.fxaa.subpixelQuality
        FXAAParams.shared.edgeThreshold = antiAliasing.fxaa.edgeThreshold
        FXAAParams.shared.edgeThresholdMin = antiAliasing.fxaa.edgeThresholdMin
        SMAAParams.shared.edgeThreshold = antiAliasing.smaa.edgeThreshold
    }

    withWorldMutationGate {
        for sourceEntityData in sceneData.entities {
            var sceneDataEntity = sourceEntityData
            let entityId = createEntity()

            uuidToEntityMap[sceneDataEntity.uuid] = entityId

            setEntityName(entityId: entityId, name: sceneDataEntity.name)
            registerTransformComponent(entityId: entityId)
            registerSceneGraphComponent(entityId: entityId)
            if let pickParticipation = sceneDataEntity.pickParticipation {
                setEntityPickParticipation(entityId: entityId, enabled: pickParticipation)
            }
            if let pickHitRepresentationMode = sceneDataEntity.pickHitRepresentationMode,
               let mode = PickHitRepresentationMode(rawValue: pickHitRepresentationMode)
            {
                setEntityPickHitRepresentationMode(entityId: entityId, mode: mode)
            }

            if let assetReference = sceneDataEntity.asset {
                switch assetReference.kind {
                case .model, .procedural:
                    if let resolvedURL = resolvedSceneAssetURL(assetReference) {
                        sceneDataEntity.assetURL = resolvedURL
                        sceneDataEntity.hasRenderingComponent = assetReference.kind == .model || assetReference.kind == .procedural
                        if sceneDataEntity.assetName.isEmpty {
                            sceneDataEntity.assetName = assetReference.displayName ?? resolvedURL.deletingPathExtension().lastPathComponent
                        }
                    }
                case .streamModel:
                    if let manifestURL = resolvedSceneAssetURL(assetReference) {
                        let entityName = sceneDataEntity.name
                        loadTracker.registerLoad()
                        setEntityStreamScene(entityId: entityId, url: manifestURL) { success in
                            if success {
                                Logger.log(message: "✅ Stream model loaded for \(entityName)")
                            } else {
                                Logger.logWarning(message: "❌ Stream model failed for \(entityName)")
                            }
                            loadTracker.completeLoad()
                        }
                    }
                case .animation:
                    break
                }
            }

            // Check for new Asset Instance system
            if let assetInstance = sceneDataEntity.assetInstance {
                // New asset instance workflow
                let assetURL = assetInstance.asset.flatMap { resolvedSceneAssetURL($0) } ?? assetInstance.assetURL
                let filename = resourceNameForLoading(from: assetURL)
                let withExtension = assetURL.pathExtension

                switch meshLoadingMode {
                case .sync:
                    loadTracker.registerLoad()
                    setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: nil) { success in
                        applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                        if success {
                            if sceneDataEntity.hasStaticBatchComponent == true {
                                setEntityStaticBatchComponent(entityId: entityId)
                            }
                            applyAssetInstanceOverrides(entityId: entityId, overrides: assetInstance.overrides)
                            if sceneDataEntity.hasAnimationComponent == true {
                                applyDeserializedAnimations(entityId: entityId, entityData: sceneDataEntity)
                            }
                        }
                        loadTracker.completeLoad()
                    }
                case .asyncDefault:
                    loadTracker.registerLoad()
                    setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: nil) { success in
                        applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                        if success {
                            Logger.log(message: "✅ Asset instance '\(sceneDataEntity.name)' loaded")
                            // Restore Static Batch Component (meshes now loaded)
                            if sceneDataEntity.hasStaticBatchComponent == true {
                                setEntityStaticBatchComponent(entityId: entityId)
                            }
                            // Apply overrides after async import completes (must run after static restore so
                            // per-node static opt-outs can remove static from selected children).
                            applyAssetInstanceOverrides(entityId: entityId, overrides: assetInstance.overrides)

                            // Setup animations (skeleton is now available)
                            if sceneDataEntity.hasAnimationComponent == true {
                                applyDeserializedAnimations(entityId: entityId, entityData: sceneDataEntity)
                            }
                        } else {
                            Logger.logWarning(message: "❌ Asset instance '\(sceneDataEntity.name)' failed to load")
                        }
                        loadTracker.completeLoad()
                    }
                }
            } else if sceneDataEntity.hasRenderingComponent == true {
                // Legacy rendering component workflow (backward compatibility)
                let filename = resourceNameForLoading(from: sceneDataEntity.assetURL)
                let withExtension = sceneDataEntity.assetURL.pathExtension
                let isProcedural = isProceduralAssetURL(sceneDataEntity.assetURL)
                switch meshLoadingMode {
                case .sync:
                    if isProcedural {
                        let meshes = createProceduralMeshes(assetName: sceneDataEntity.assetName)
                        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: sceneDataEntity.assetName)
                        applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedMaterialData(entityId: entityId, entityData: sceneDataEntity)

                        // Restore Static Batch Component (procedural mesh already loaded)
                        if sceneDataEntity.hasStaticBatchComponent == true {
                            setEntityStaticBatchComponent(entityId: entityId)
                        }
                    } else {
                        loadTracker.registerLoad()
                        setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: sceneDataEntity.assetName) { success in
                            applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                            applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                            if success {
                                applyDeserializedMaterialData(entityId: entityId, entityData: sceneDataEntity)
                                if sceneDataEntity.hasStaticBatchComponent == true {
                                    setEntityStaticBatchComponent(entityId: entityId)
                                }
                                if sceneDataEntity.hasAnimationComponent == true {
                                    applyDeserializedAnimations(entityId: entityId, entityData: sceneDataEntity)
                                }
                            }
                            loadTracker.completeLoad()
                        }
                    }
                case .asyncDefault:
                    if isProcedural {
                        let meshes = createProceduralMeshes(assetName: sceneDataEntity.assetName)
                        setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: sceneDataEntity.assetName)
                        applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                        applyDeserializedMaterialData(entityId: entityId, entityData: sceneDataEntity)

                        // Restore Static Batch Component (procedural mesh already loaded)
                        if sceneDataEntity.hasStaticBatchComponent == true {
                            setEntityStaticBatchComponent(entityId: entityId)
                        }
                    } else {
                        let fallbackLabel = withExtension.isEmpty ? filename : "\(filename).\(withExtension)"
                        let meshLabel = sceneDataEntity.name.isEmpty ? fallbackLabel : sceneDataEntity.name
                        loadTracker.registerLoad()
                        setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: sceneDataEntity.assetName) { success in
                            applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                            applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
                            if success {
                                Logger.log(message: "✅ Mesh loaded for \(meshLabel)")

                                applyDeserializedMaterialData(entityId: entityId, entityData: sceneDataEntity)

                                // Restore Static Batch Component (mesh now loaded)
                                if sceneDataEntity.hasStaticBatchComponent == true {
                                    setEntityStaticBatchComponent(entityId: entityId)
                                }

                                // Setup animations (skeleton is now available)
                                if sceneDataEntity.hasAnimationComponent == true {
                                    applyDeserializedAnimations(entityId: entityId, entityData: sceneDataEntity)
                                }
                            } else {
                                Logger.logWarning(message: "❌ Mesh failed for \(meshLabel)")
                            }
                            loadTracker.completeLoad()
                        }
                    }
                }
            }

            // Animation setup is now handled inside mesh loading completion handlers
            // (for asset instances and rendering components) to ensure skeleton component is available.
            // For entities without meshes (cameras, lights, empty parents), animations wouldn't apply anyway
            // since they require a skeleton, which comes from mesh loading.
            //
            // Note: For multi-mesh assets, the skeleton is on child entities, not the parent.
            // If sceneDataEntity has hasAnimationComponent but is a multi-mesh parent, the animations
            // should actually be applied to the specific child entity that has the skeleton.

            if sceneDataEntity.hasKineticComponent == true {
                setEntityKinetics(entityId: entityId)

                guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
                    handleError(.noPhysicsComponent)
                    continue
                }

                physicsComponent.mass = sceneDataEntity.mass
            }

            if sceneDataEntity.hasDirLightComponent == true {
                if let light = sceneDataEntity.lightData {
                    let color: simd_float3 = light.color
                    let intensity: Float = light.intensity

                    createDirLight(entityId: entityId)
                    // createDirLight() only activates a light if activeDirectionalLight is nil.
                    // Callers that clear the scene (destroyAllEntities()) right before
                    // deserializing only mark the previous entities for deferred destruction —
                    // the pointer isn't nulled until finalizePendingDestroys() runs on a later
                    // frame — so this can silently see a stale non-nil pointer and skip
                    // activation. A scene file that declares a directional light should always
                    // become the active one when loaded, so force it explicitly.
                    setDirectionalLight(.active(entityId))

                    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                        handleError(.noLightComponent)
                        continue
                    }

                    lightComponent.color = color
                    lightComponent.intensity = intensity
                    lightComponent.usesRadiometricUnits = light.usesRadiometricUnits ?? false
                    scene.get(component: DirectionalLightComponent.self, for: entityId)?.castsShadow = light.castsShadow ?? true

                    guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                        handleError(.noRenderComponent)
                        continue
                    }

                    applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                    applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)

                    if let materialData = sceneDataEntity.materialData {
                        let emmissiveValue: simd_float3 = materialData.emissiveValue
                        updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                    }
                }
            }

            if sceneDataEntity.hasPointLightComponent == true {
                if let light = sceneDataEntity.lightData {
                    let color: simd_float3 = light.color
                    let radius: Float = light.radius
                    let intensity: Float = light.intensity
                    let falloff: Float = light.falloff

                    createPointLight(entityId: entityId)

                    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                        handleError(.noLightComponent)
                        continue
                    }

                    guard let pointlightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
                        handleError(.noPointLightComponent)
                        continue
                    }

                    lightComponent.color = color
                    lightComponent.intensity = intensity
                    lightComponent.usesRadiometricUnits = light.usesRadiometricUnits ?? false
                    pointlightComponent.radius = radius
                    pointlightComponent.range = max(light.range ?? 0.0, 0.0)
                    pointlightComponent.falloff = falloff
                    pointlightComponent.castsShadow = light.castsShadow ?? false

                    guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                        handleError(.noRenderComponent)
                        continue
                    }

                    applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                    applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)

                    if let materialData = sceneDataEntity.materialData {
                        let emmissiveValue: simd_float3 = materialData.emissiveValue
                        updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                    }
                }
            }

            if sceneDataEntity.hasSpotLightComponent == true {
                if let light = sceneDataEntity.lightData {
                    let color: simd_float3 = light.color
                    let radius: Float = light.radius
                    let intensity: Float = light.intensity
                    let falloff: Float = light.falloff
                    let coneAngle: Float = light.coneAngle

                    createSpotLight(entityId: entityId)

                    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                        handleError(.noLightComponent)
                        continue
                    }

                    guard let spotlightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
                        handleError(.noSpotLightComponent)
                        continue
                    }

                    lightComponent.color = color
                    lightComponent.intensity = intensity
                    lightComponent.usesRadiometricUnits = light.usesRadiometricUnits ?? false
                    spotlightComponent.radius = radius
                    spotlightComponent.range = max(light.range ?? 0.0, 0.0)
                    spotlightComponent.falloff = falloff
                    spotlightComponent.coneAngle = coneAngle
                    spotlightComponent.castsShadow = light.castsShadow ?? false

                    guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                        handleError(.noRenderComponent)
                        continue
                    }

                    applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                    applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)

                    if let materialData = sceneDataEntity.materialData {
                        let emmissiveValue: simd_float3 = materialData.emissiveValue
                        updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                    }
                }
            }

            if sceneDataEntity.hasAreaLightComponent == true {
                if let light = sceneDataEntity.lightData {
                    let color: simd_float3 = light.color
                    let intensity: Float = light.intensity
                    let forward = light.forward
                    let right = light.right
                    let up = light.up
                    let bounds = light.bounds
                    let twoSided = light.twoSided

                    createAreaLight(entityId: entityId)

                    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                        handleError(.noLightComponent)
                        continue
                    }

                    guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
                        handleError(.noAreaLightComponent)
                        continue
                    }

                    lightComponent.color = color
                    lightComponent.intensity = intensity
                    lightComponent.usesRadiometricUnits = light.usesRadiometricUnits ?? false
                    areaLightComponent.forward = forward
                    areaLightComponent.right = right
                    areaLightComponent.up = up
                    areaLightComponent.bounds = bounds
                    areaLightComponent.twoSided = twoSided
                    areaLightComponent.range = max(light.range ?? 0.0, 0.0)
                    areaLightComponent.castsShadow = light.castsShadow ?? false

                    guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                        handleError(.noRenderComponent)
                        continue
                    }

                    applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                    applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)

                    if let materialData = sceneDataEntity.materialData {
                        let emmissiveValue: simd_float3 = materialData.emissiveValue
                        updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                    }
                }
            }

            if sceneDataEntity.assetInstance == nil, sceneDataEntity.hasRenderingComponent != true {
                applyDeserializedLocalTransform(entityId: entityId, entityData: sceneDataEntity)
                applyDeserializedRenderProperties(entityId: entityId, entityData: sceneDataEntity)
            }

            if sceneDataEntity.hasCameraComponent == true {
                if let camera = sceneDataEntity.cameraData {
                    let eye = camera.eye
                    let target = camera.target
                    let up = camera.up

                    createGameCamera(entityId: entityId)

                    guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
                        handleError(.noGameCamera)
                        continue
                    }

                    cameraComponent.eye = eye
                    cameraComponent.target = target
                    cameraComponent.up = up

                    cameraLookAt(entityId: entityId, eye: eye, target: target, up: up)
                }
            }

            // LOD Component
            if sceneDataEntity.hasLODComponent == true {
                if let lodData = sceneDataEntity.lodData {
                    switch meshLoadingMode {
                    case .sync:
                        // Synchronous LOD loading not yet implemented
                        Logger.logWarning(message: "[SceneSerializer] Synchronous LOD loading not supported, skipping LOD for '\(sceneDataEntity.name)'")
                    case .asyncDefault:
                        // Register LOD component first
                        setEntityLodComponent(entityId: entityId)

                        // Track completion
                        let lodLoadCountLock = NSLock()
                        var loadedCount = 0
                        let totalLevels = lodData.lodLevels.count

                        // Load each LOD level using the granular API
                        for (index, lodLevelData) in lodData.lodLevels.enumerated() {
                            let url = lodLevelData.url
                            let filename = resourceNameForLoading(from: url)
                            let ext = url.pathExtension
                            let maxDistance = lodLevelData.maxDistance

                            loadTracker.registerLoad()
                            addLODLevel(
                                entityId: entityId,
                                lodIndex: index,
                                fileName: filename,
                                withExtension: ext,
                                maxDistance: maxDistance
                            ) { success in
                                if success {
                                    var finishedAllLevels = false
                                    lodLoadCountLock.lock()
                                    loadedCount += 1
                                    finishedAllLevels = loadedCount == totalLevels
                                    lodLoadCountLock.unlock()

                                    // When all levels are loaded, restore LOD settings.
                                    if finishedAllLevels {
                                        Logger.log(message: "✅ LOD loaded for '\(sceneDataEntity.name)' with \(totalLevels) levels")
                                        withWorldMutationGate {
                                            if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
                                                lodComponent.currentLOD = lodData.currentLOD
                                                lodComponent.fadeTransition = lodData.fadeTransition
                                                lodComponent.transitionDuration = lodData.transitionDuration
                                            }
                                        }
                                    }
                                } else {
                                    Logger.logWarning(message: "⚠️ Failed to load LOD level \(index) for '\(sceneDataEntity.name)'")
                                }
                                loadTracker.completeLoad()
                            }
                        }
                    }
                }
            }

            // Static Batch Component is now restored inside mesh loading completion handlers
            // (moved there to ensure RenderComponent exists before adding StaticBatchComponent)

            // Geometry Streaming Component
            if sceneDataEntity.hasStreamingComponent == true {
                if let streamingData = sceneDataEntity.streamingData {
                    // Register streaming component
                    registerComponent(entityId: entityId, componentType: StreamingComponent.self)

                    if let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) {
                        streamingComponent.streamingRadius = streamingData.streamingRadius
                        streamingComponent.unloadRadius = streamingData.unloadRadius
                        streamingComponent.priority = streamingData.priority
                        streamingComponent.assetFilename = streamingData.assetFilename
                        streamingComponent.assetExtension = streamingData.assetExtension
                        streamingComponent.assetName = streamingData.assetName
                        streamingComponent.state = MeshStreamingState.unloaded

                        Logger.log(message: "✅ Streaming component restored for '\(sceneDataEntity.name)'")
                    } else {
                        Logger.logWarning(message: "⚠️ Failed to restore streaming component for '\(sceneDataEntity.name)'")
                    }
                }
            }

            // custom components
            if let customComponents = sceneDataEntity.customComponents {
                for (typeName, jsonData) in customComponents {
                    if let deserializeFunc = customComponentDecoderMap[typeName] {
                        deserializeFunc(entityId, jsonData)
                    }
                }
            }
        }

        // secon pass: rebuild hierarchy
        for sceneDataEntity in sceneData.entities {
            guard let childId = uuidToEntityMap[sceneDataEntity.uuid],
                  let parentUUID = sceneDataEntity.parentUUID,
                  let parentId = uuidToEntityMap[parentUUID]
            else {
                continue
            }

            setParent(childId: childId, parentId: parentId)
        }
    }

    // Allow completion once all registrations are known and async work is finished.
    loadTracker.finishRegistration()
}

// MARK: - Scene Loading

private let untoldSceneFileExtension = "untoldscene"

private func normalizedUntoldSceneBaseName(_ sceneName: String) -> String? {
    let trimmedName = sceneName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedName.isEmpty == false else {
        return nil
    }

    let sceneURL = URL(fileURLWithPath: trimmedName)
    let fileExtension = sceneURL.pathExtension.lowercased()
    guard fileExtension.isEmpty || fileExtension == untoldSceneFileExtension else {
        return nil
    }

    return sceneURL.deletingPathExtension().lastPathComponent
}

public func loadUntoldScene(
    named sceneName: String,
    meshLoadingMode: MeshLoadingMode = .asyncDefault,
    completion: ((Bool) -> Void)? = nil
) {
    guard let sceneBaseName = normalizedUntoldSceneBaseName(sceneName) else {
        Logger.log(message: "❌ loadUntoldScene(named:) only accepts .\(untoldSceneFileExtension) scene files or names without an extension. Received: \(sceneName)")
        completion?(false)
        return
    }

    guard let gameDataURL = assetBasePath else {
        Logger.log(message: "❌ assetBasePath is not configured. Call setupAssetPaths() first.")
        completion?(false)
        return
    }

    let preferredSceneURL = gameDataURL
        .appendingPathComponent("Scenes", isDirectory: true)
        .appendingPathComponent(sceneBaseName)
        .appendingPathExtension(untoldSceneFileExtension)

    let sceneURL: URL?
    if FileManager.default.fileExists(atPath: preferredSceneURL.path) {
        sceneURL = preferredSceneURL
    } else {
        // SwiftPM test resources can be flattened by `.process("Resources")`; fall back
        // through the shared resolver after preserving the BuildSystem `Scenes/` priority.
        sceneURL = LoadingSystem.shared.resourceURL(forResource: sceneBaseName, withExtension: untoldSceneFileExtension)
    }

    guard let sceneURL else {
        Logger.log(message: "❌ Scene file not found: \(sceneBaseName).\(untoldSceneFileExtension)")
        completion?(false)
        return
    }

    do {
        let data = try Data(contentsOf: sceneURL)
        let sceneData = try JSONDecoder().decode(SceneData.self, from: data)

        assetBasePath = gameDataURL

        Logger.log(message: "📄 Loading Untold scene: \(sceneURL.lastPathComponent)")

        deserializeScene(sceneData: sceneData, meshLoadingMode: meshLoadingMode) {
            Logger.log(message: "✅ Finished loading scene: \(sceneURL.lastPathComponent)")
            completion?(true)
        }
    } catch {
        Logger.log(message: "❌ Failed to load scene \(sceneURL.lastPathComponent): \(error.localizedDescription)")
        completion?(false)
    }
}

/// Notification posted when asset instance has finished loading and overrides have been applied
public extension Notification.Name {
    static let assetInstanceDidLoad = Notification.Name("assetInstanceDidLoad")
}

/// Apply overrides to derived asset nodes after import completes
private func applyAssetInstanceOverrides(entityId: EntityID, overrides: [AssetOverrideData]) {
    // Build nodePath -> derived entity map
    var nodePathMap: [String: EntityID] = [:]

    for childId in derivedAssetNodeIds(rootEntityId: entityId) {
        if let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) {
            nodePathMap[derivedComp.nodePath] = childId
        }
    }

    Logger.log(message: "[SceneSerializer] Applying \(overrides.count) overrides to asset instance (found \(nodePathMap.count) derived nodes)")

    var appliedCount = 0
    var failedCount = 0

    for override in overrides {
        guard let derivedEntityId = nodePathMap[override.nodePath] else {
            Logger.logWarning(message: "[SceneSerializer] Override nodePath '\(override.nodePath)' not found in asset instance")
            failedCount += 1
            continue
        }

        // Apply transform override
        if let transform = override.transform {
            if let position = transform.position {
                translateTo(entityId: derivedEntityId, position: position)
            }
            if let scale = transform.scale {
                scaleTo(entityId: derivedEntityId, scale: scale)
            }
            if let axisRotations = transform.axisOfRotations {
                applyAxisRotations(entityId: derivedEntityId, axis: axisRotations)
            }
        }

        // Apply material override
        if let material = override.material {
            if hasComponent(entityId: derivedEntityId, componentType: RenderComponent.self) {
                updateMaterialColor(entityId: derivedEntityId, color: colorFromSimd(material.baseColorValue))
                updateMaterialRoughness(entityId: derivedEntityId, roughness: material.roughnessValue)
                updateMaterialMetallic(entityId: derivedEntityId, metallic: material.metallicValue)
                updateMaterialEmmisive(entityId: derivedEntityId, emmissive: material.emissiveValue)
                if let opacity = material.opacity {
                    updateMaterialOpacity(entityId: derivedEntityId, opacity: opacity)
                }
                if let alphaCutoff = material.alphaCutoff {
                    updateMaterialAlphaCutoff(entityId: derivedEntityId, cutoff: alphaCutoff)
                }
                if let alphaModeRawValue = material.alphaMode,
                   let alphaMode = MaterialAlphaMode(rawValue: alphaModeRawValue)
                {
                    updateMaterialAlphaMode(entityId: derivedEntityId, mode: alphaMode)
                }

                if let baseColorURL = material.baseColorURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .baseColor, path: baseColorURL)
                }
                if let roughnessURL = material.roughnessURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .roughness, path: roughnessURL)
                }
                if let metallicURL = material.metallicURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .metallic, path: metallicURL)
                }
                if let normalURL = material.normalURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .normal, path: normalURL)
                }

                if let stScale = material.stScale {
                    updateMaterialSTScale(entityId: derivedEntityId, stScale: stScale)
                }

                if let baseColorWrapModeRawValue = material.baseColorWrapMode,
                   let wrapMode = WrapMode(rawValue: baseColorWrapModeRawValue)
                {
                    updateTextureSampler(entityId: derivedEntityId, textureType: .baseColor, wrapMode: wrapMode)
                }

                if let roughnessWrapModeRawValue = material.roughnessWrapMode,
                   let wrapMode = WrapMode(rawValue: roughnessWrapModeRawValue)
                {
                    updateTextureSampler(entityId: derivedEntityId, textureType: .roughness, wrapMode: wrapMode)
                }

                if let metallicWrapModeRawValue = material.metallicWrapMode,
                   let wrapMode = WrapMode(rawValue: metallicWrapModeRawValue)
                {
                    updateTextureSampler(entityId: derivedEntityId, textureType: .metallic, wrapMode: wrapMode)
                }

                if let normalWrapModeRawValue = material.normalWrapMode,
                   let wrapMode = WrapMode(rawValue: normalWrapModeRawValue)
                {
                    updateTextureSampler(entityId: derivedEntityId, textureType: .normal, wrapMode: wrapMode)
                }
            }
        }

        // Apply visibility override (if supported in the future)
        if let visibility = override.visibility {
            if let renderComp = scene.get(component: RenderComponent.self, for: derivedEntityId) {
                renderComp.isVisible = visibility
            }
        }
        if let pickParticipation = override.pickParticipation {
            setEntityPickParticipation(entityId: derivedEntityId, enabled: pickParticipation)
        }
        if let pickHitRepresentationMode = override.pickHitRepresentationMode,
           let mode = PickHitRepresentationMode(rawValue: pickHitRepresentationMode)
        {
            setEntityPickHitRepresentationMode(entityId: derivedEntityId, mode: mode)
        }

        // Apply explicit static-batching override for this derived node.
        if let hasStaticBatch = override.hasStaticBatchComponent {
            if hasStaticBatch {
                // Per-node override should not recursively retag descendants.
                setEntityStaticBatch(entityId: derivedEntityId)
            } else {
                // Remove only from this derived node; don't recursively affect sibling branches.
                removeEntityStaticBatch(entityId: derivedEntityId)
            }
        }

        // apply entity name override
        if let entityName = override.name {
            setEntityName(entityId: derivedEntityId, name: entityName)
        }

        appliedCount += 1
    }

    if failedCount > 0 {
        Logger.logWarning(message: "[SceneSerializer] Failed to apply \(failedCount) overrides (nodePath not found)")
    }
    if appliedCount > 0 {
        Logger.log(message: "[SceneSerializer] Successfully applied \(appliedCount) overrides")
    }

    // Post notification to inform UI that asset instance is fully loaded
    NotificationCenter.default.post(name: .assetInstanceDidLoad, object: entityId)
}
