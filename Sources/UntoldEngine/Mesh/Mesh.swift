//
//  Mesh.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit
import MetalPerformanceShaders
@preconcurrency import ModelIO
import simd

private extension simd_float3 {
    func isApproximately(_ other: simd_float3, epsilon: Float = 0.01) -> Bool {
        simd_distance(self, other) < epsilon
    }
}

private extension simd_float4x4 {
    func isApproximatelyEqual(to other: simd_float4x4, epsilon: Float = 0.0001) -> Bool {
        let delta0 = simd_length(columns.0 - other.columns.0)
        let delta1 = simd_length(columns.1 - other.columns.1)
        let delta2 = simd_length(columns.2 - other.columns.2)
        let delta3 = simd_length(columns.3 - other.columns.3)

        return delta0 < epsilon && delta1 < epsilon && delta2 < epsilon && delta3 < epsilon
    }
}

public enum CoordinateSystemConversion: Sendable {
    case autoDetect // Check USD up-axis and convert only if needed
    case forceZUpToYUp // Always apply Z-up to Y-up conversion
    case none // Use transforms as-is from USD
}

public struct Mesh {
    public let metalKitMesh: MTKMesh
    public var submeshes: [SubMesh] = []
    public var localSpace: simd_float4x4 = .identity
    public var worldSpace: simd_float4x4 = .identity
    var assetName: String
    var boundingBox: (min: simd_float3, max: simd_float3)
    var skin: Skin?
    var featureEdgeIndexBuffer: MTLBuffer?
    var featureEdgeIndexCount: Int = 0
    var featureEdgeIndexType: MTLIndexType = .uint32

    public var name: String {
        assetName
    }

    public var localBounds: (min: simd_float3, max: simd_float3) {
        boundingBox
    }

    /// Create a Mesh from an in-memory MDLMesh (used by the native .untold upload path).
    ///
    /// `makeMesh(from: RuntimeMeshPrimitive)` builds an in-memory MDLMesh from decoded
    /// vertex/index data, then calls this init to create the MTKMesh GPU buffers.
    /// localSpace and worldSpace are overwritten by the caller from primitive data.
    init?(modelIOMesh: MDLMesh, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip _: Bool) {
        localSpace = modelIOMesh.transform?.matrix ?? .identity
        worldSpace = localSpace
        assetName = modelIOMesh.parent?.name ?? modelIOMesh.name
        boundingBox = (min: modelIOMesh.boundingBox.minBounds, max: modelIOMesh.boundingBox.maxBounds)

        if hasTextureCoordinates(mesh: modelIOMesh) {
            modelIOMesh.addOrthTanBasis(
                forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                normalAttributeNamed: MDLVertexAttributeNormal,
                tangentAttributeNamed: MDLVertexAttributeTangent
            )
        }
        modelIOMesh.vertexDescriptor = vertexDescriptor

        var localMetalKitMesh: MTKMesh
        do {
            localMetalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
        } catch {
            handleError(.meshCreationFailed, error.localizedDescription, assetName)
            return nil
        }
        metalKitMesh = localMetalKitMesh

        submeshes = modelIOMesh.submeshes?.enumerated().compactMap { index, element in
            guard let mdlSubmesh = element as? MDLSubmesh else { return nil }
            guard index < localMetalKitMesh.submeshes.count else { return nil }
            return SubMesh(
                modelIOSubmesh: mdlSubmesh,
                metalKitSubmesh: localMetalKitMesh.submeshes[index],
                textureLoader: textureLoader
            )
        } ?? []
    }

    mutating func cleanUp() {
        submeshes.removeAll()
        skin?.cleanUp()
        skin = nil
        featureEdgeIndexBuffer = nil
        featureEdgeIndexCount = 0
    }

    /// Returns a copy of this mesh. Uniform data is written per-draw via setVertexBytes,
    /// so no per-mesh buffer allocation is needed.
    func copyWithNewUniformBuffers() -> Mesh {
        self
    }

    /// Convert an in-memory MDLObject (procedural geometry, not file-loaded) into engine Mesh objects.
    /// Used by BasicPrimitives to turn MDLMesh shapes into renderable Mesh instances.
    static func makeMeshes(object: MDLObject, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip: Bool) -> [Mesh] {
        var meshes: [Mesh] = []
        if let mdlMesh = object as? MDLMesh,
           let mesh = Mesh(modelIOMesh: mdlMesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
        {
            meshes.append(mesh)
        }
        if object.conforms(to: MDLObjectContainerComponent.self) {
            let children = object.children.objects
            for i in 0 ..< children.count {
                meshes.append(contentsOf: makeMeshes(object: children[i], vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip))
            }
        }
        return meshes
    }

    static func computeMeshBoundingBox(for meshes: [Mesh]) -> (min: simd_float3, max: simd_float3) {
        guard meshes.isEmpty == false else {
            return (min: .zero, max: .zero)
        }

        // Start with infinity bounds to ensure proper min/max comparisons
        var combinedMin = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var combinedMax = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        for mesh in meshes {
            let meshMin = mesh.boundingBox.min
            let meshMax = mesh.boundingBox.max
            let corners: [simd_float3] = [
                simd_float3(meshMin.x, meshMin.y, meshMin.z),
                simd_float3(meshMin.x, meshMin.y, meshMax.z),
                simd_float3(meshMin.x, meshMax.y, meshMin.z),
                simd_float3(meshMin.x, meshMax.y, meshMax.z),
                simd_float3(meshMax.x, meshMin.y, meshMin.z),
                simd_float3(meshMax.x, meshMin.y, meshMax.z),
                simd_float3(meshMax.x, meshMax.y, meshMin.z),
                simd_float3(meshMax.x, meshMax.y, meshMax.z),
            ]

            var transformedMin = simd_float3(Float.infinity, Float.infinity, Float.infinity)
            var transformedMax = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

            for corner in corners {
                let transformed = simd_mul(mesh.localSpace, simd_float4(corner.x, corner.y, corner.z, 1.0))
                let transformedPoint = simd_float3(transformed.x, transformed.y, transformed.z)
                transformedMin = simd_min(transformedMin, transformedPoint)
                transformedMax = simd_max(transformedMax, transformedPoint)
            }

            combinedMin = simd_min(combinedMin, transformedMin)
            combinedMax = simd_max(combinedMax, transformedMax)
        }

        return (min: combinedMin, max: combinedMax)
    }

    /// Helper to create one fallback mesh
    static func makeDefaultMesh() -> [Mesh] {
        BasicPrimitives.createSphere()
    }

    /// Build one engine `Mesh` from a source-agnostic runtime primitive.
    ///
    /// This path avoids ModelIO file parsing entirely. The cooked/intermediate
    /// primitive payload is decoded into the engine's expanded attribute layout
    /// (position / normal / uv / tangent as separate buffers), wrapped in an
    /// in-memory MDLMesh, and then passed through the existing MTKMesh creation
    /// path so the rest of the renderer remains unchanged.
    static func makeMesh(from primitive: RuntimeMeshPrimitive, device: MTLDevice) -> Mesh? {
        guard primitive.vertexLayout == .pbrStaticV1 else {
            handleError(.fileTypeNotSupported, primitive.name)
            return nil
        }

        do {
            let decodedVertices = try decodeRuntimeVertices(from: primitive.vertexData, expectedCount: primitive.vertexCount)
            let allocator = MTKMeshBufferAllocator(device: device)

            let positionBuffer = allocator.newBuffer(
                MemoryLayout<simd_float4>.stride * decodedVertices.count,
                type: .vertex
            )
            let normalBuffer = allocator.newBuffer(
                MemoryLayout<simd_float4>.stride * decodedVertices.count,
                type: .vertex
            )
            let uvBuffer = allocator.newBuffer(
                MemoryLayout<simd_float2>.stride * decodedVertices.count,
                type: .vertex
            )
            let tangentBuffer = allocator.newBuffer(
                MemoryLayout<simd_float4>.stride * decodedVertices.count,
                type: .vertex
            )
            let jointIndexBuffer = allocator.newBuffer(
                MemoryLayout<simd_ushort4>.stride * decodedVertices.count,
                type: .vertex
            )
            let jointWeightBuffer = allocator.newBuffer(
                MemoryLayout<simd_float4>.stride * decodedVertices.count,
                type: .vertex
            )

            let positions = positionBuffer.map().bytes.bindMemory(to: simd_float4.self, capacity: decodedVertices.count)
            let normals = normalBuffer.map().bytes.bindMemory(to: simd_float4.self, capacity: decodedVertices.count)
            let uvs = uvBuffer.map().bytes.bindMemory(to: simd_float2.self, capacity: decodedVertices.count)
            let tangents = tangentBuffer.map().bytes.bindMemory(to: simd_float4.self, capacity: decodedVertices.count)
            let jointIndices = jointIndexBuffer.map().bytes.bindMemory(to: simd_ushort4.self, capacity: decodedVertices.count)
            let jointWeights = jointWeightBuffer.map().bytes.bindMemory(to: simd_float4.self, capacity: decodedVertices.count)
            let runtimeJointIndices = primitive.skin?.jointIndexData.withUnsafeBytes {
                $0.bindMemory(to: simd_ushort4.self)
            }
            let runtimeJointWeights = primitive.skin?.jointWeightData.withUnsafeBytes {
                $0.bindMemory(to: simd_float4.self)
            }

            for (index, vertex) in decodedVertices.enumerated() {
                positions[index] = simd_float4(vertex.position.x, vertex.position.y, vertex.position.z, 1.0)

                let normal = UntoldVertexPacking.unpackNormal(vertex.normalPacked)
                normals[index] = simd_float4(normal.x, normal.y, normal.z, 0.0)

                let tangent = UntoldVertexPacking.unpackTangent(vertex.tangentPacked)
                tangents[index] = simd_float4(tangent.vector.x, tangent.vector.y, tangent.vector.z, tangent.handedness)

                uvs[index] = simd_float2(
                    Float(Float16(bitPattern: vertex.uv0.x)),
                    Float(Float16(bitPattern: vertex.uv0.y))
                )

                if let runtimeJointIndices, index < runtimeJointIndices.count,
                   let runtimeJointWeights, index < runtimeJointWeights.count
                {
                    jointIndices[index] = runtimeJointIndices[index]
                    jointWeights[index] = runtimeJointWeights[index]
                } else {
                    // Non-skinned runtime assets still need these streams because the engine's
                    // shared model vertex descriptor declares them. Keep them zeroed so the
                    // shader's `hasArmature == false` path remains valid.
                    jointIndices[index] = simd_ushort4(0, 0, 0, 0)
                    jointWeights[index] = simd_float4(0, 0, 0, 0)
                }
            }

            let indexBuffer = allocator.newBuffer(primitive.indexData.count, type: .index)
            _ = primitive.indexData.withUnsafeBytes { rawBuffer in
                memcpy(indexBuffer.map().bytes, rawBuffer.baseAddress!, primitive.indexData.count)
            }

            let mdlSubmesh = MDLSubmesh(
                indexBuffer: indexBuffer,
                indexCount: primitive.indexCount,
                indexType: primitive.indexFormat == .uint16 ? .uInt16 : .uInt32,
                geometryType: .triangles,
                material: nil
            )

            let mdlMesh = MDLMesh(
                vertexBuffers: [
                    positionBuffer,
                    normalBuffer,
                    uvBuffer,
                    tangentBuffer,
                    jointIndexBuffer,
                    jointWeightBuffer,
                ],
                vertexCount: primitive.vertexCount,
                descriptor: vertexDescriptor.model,
                submeshes: [mdlSubmesh]
            )
            mdlMesh.name = primitive.name
            mdlMesh.transform = MDLTransform(matrix: primitive.localTransform)

            let textureLoader = TextureLoader(device: device)
            guard var mesh = Mesh(
                modelIOMesh: mdlMesh,
                vertexDescriptor: vertexDescriptor.model,
                textureLoader: textureLoader,
                device: device,
                flip: true
            ) else {
                return nil
            }

            mesh.localSpace = primitive.localTransform
            mesh.worldSpace = primitive.worldTransform
            mesh.boundingBox = (min: primitive.localBounds.min, max: primitive.localBounds.max)
            mesh.assetName = primitive.name
            if primitive.edgeIndexCount > 0, !primitive.edgeIndexData.isEmpty {
                mesh.featureEdgeIndexBuffer = device.makeBuffer(
                    bytes: [UInt8](primitive.edgeIndexData),
                    length: primitive.edgeIndexData.count,
                    options: .storageModeShared
                )
                mesh.featureEdgeIndexBuffer?.label = "Feature Edge Index Buffer"
                mesh.featureEdgeIndexCount = primitive.edgeIndexCount
                mesh.featureEdgeIndexType = primitive.indexFormat == .uint16 ? .uint16 : .uint32
            }

            if let runtimeMaterial = primitive.material, !mesh.submeshes.isEmpty {
                var submesh = mesh.submeshes[0]
                submesh.material = Material(runtimeMaterial: runtimeMaterial, device: device)
                mesh.submeshes[0] = submesh
            }

            return mesh
        } catch {
            handleError(.meshCreationFailed, error.localizedDescription, primitive.name)
            return nil
        }
    }

    private static func decodeRuntimeVertices(from data: Data, expectedCount: Int) throws -> [UntoldPBRStaticVertexV1] {
        let reader = UntoldBinaryReader(data: data)
        var vertices: [UntoldPBRStaticVertexV1] = []
        vertices.reserveCapacity(expectedCount)
        for _ in 0 ..< expectedCount {
            try vertices.append(UntoldPBRStaticVertexV1.decode(from: reader))
        }
        return vertices
    }
}

public struct SubMesh {
    public let metalKitSubmesh: MTKSubmesh
    public var material: Material?

    init(metalKitSubmesh: MTKSubmesh) {
        self.metalKitSubmesh = metalKitSubmesh
    }

    init(modelIOSubmesh: MDLSubmesh, metalKitSubmesh: MTKSubmesh, textureLoader: TextureLoader) {
        self.metalKitSubmesh = metalKitSubmesh

        // Fallback to an empty material if none is provided
        if let mdlMaterial = modelIOSubmesh.material {
            material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        } else {
            material = nil
        }
    }
}

public enum WrapMode: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case clampToEdge
    case `repeat`

    public var id: Int {
        rawValue
    }

    public var description: String {
        switch self {
        case .clampToEdge: return "Clamp to Edge"
        case .repeat: return "Repeat"
        }
    }
}

public enum MaterialAlphaMode: Int32, CaseIterable, Identifiable, CustomStringConvertible {
    case opaque = 0
    case mask = 1
    case blend = 2

    public var id: Int32 {
        rawValue
    }

    public var description: String {
        switch self {
        case .opaque: return "Opaque"
        case .mask: return "Mask"
        case .blend: return "Blend"
        }
    }
}

public struct TextureDescriptor {
    public var texture: MTLTexture?
    public var sampler: MTLSamplerState?
    public var wrapMode: WrapMode = .clampToEdge
}

private func clamp01(_ value: Float) -> Float {
    max(0.0, min(1.0, value))
}

private func normalizedMaterialPropertyName(_ name: String) -> String {
    String(name.lowercased().filter { $0.isLetter || $0.isNumber })
}

private func materialPropertyScalar(_ property: MDLMaterialProperty?) -> Float? {
    guard let property else { return nil }

    switch property.type {
    case .float:
        return property.floatValue
    case .float2:
        return property.float2Value.x
    case .float3:
        return property.float3Value.x
    case .float4:
        return property.float4Value.x
    case .color:
        return Float(property.color?.alpha ?? 1.0)
    case .string:
        guard let value = property.stringValue else { return nil }
        return Float(value.trimmingCharacters(in: .whitespacesAndNewlines))
    default:
        return nil
    }
}

private func materialPropertyString(_ property: MDLMaterialProperty?) -> String? {
    guard let property else { return nil }

    switch property.type {
    case .string:
        return property.stringValue?.lowercased()
    case .float, .float2, .float3, .float4, .color:
        if let scalar = materialPropertyScalar(property) {
            return String(scalar)
        }
        return nil
    default:
        return nil
    }
}

private func rgbFromCGColor(_ color: CGColor) -> simd_float3 {
    guard let components = color.components else {
        return simd_float3(1.0, 1.0, 1.0)
    }

    switch components.count {
    case 0:
        return simd_float3(1.0, 1.0, 1.0)
    case 1:
        let v = Float(components[0])
        return simd_float3(v, v, v)
    case 2:
        let v = Float(components[0])
        return simd_float3(v, v, v)
    default:
        return simd_float3(Float(components[0]), Float(components[1]), Float(components[2]))
    }
}

private func decodeBaseColorFactor(_ property: MDLMaterialProperty?) -> (value: simd_float4, hasExplicitAlpha: Bool)? {
    guard let property else { return nil }

    switch property.type {
    case .color:
        guard let cgColor = property.color else { return nil }
        let rgb = rgbFromCGColor(cgColor)
        return (simd_float4(rgb.x, rgb.y, rgb.z, Float(cgColor.alpha)), true)
    case .float4:
        let v = property.float4Value
        return (simd_float4(v.x, v.y, v.z, v.w), true)
    case .float3:
        let v = property.float3Value
        return (simd_float4(v.x, v.y, v.z, 1.0), false)
    case .float2:
        let v = property.float2Value
        return (simd_float4(v.x, v.y, 0.0, 1.0), false)
    case .float:
        let v = property.floatValue
        return (simd_float4(v, v, v, 1.0), false)
    default:
        return nil
    }
}

private func decodeAlphaModeFromMaterialMetadata(_ mdlMaterial: MDLMaterial) -> MaterialAlphaMode? {
    for index in 0 ..< mdlMaterial.count {
        guard let property = mdlMaterial[index] else { continue }
        let key = normalizedMaterialPropertyName(property.name)
        let likelyAlphaModeProperty = key.contains("alphamode")
            || key.contains("opacitymode")
            || key.contains("transparencymode")
            || key.contains("blendmode")

        guard likelyAlphaModeProperty else { continue }

        if let stringValue = materialPropertyString(property)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if stringValue.contains("blend") || stringValue.contains("transparent") {
                return .blend
            }
            if stringValue.contains("mask") || stringValue.contains("cutout") || stringValue.contains("clip") {
                return .mask
            }
            if stringValue.contains("opaque") || stringValue.contains("none") {
                return .opaque
            }
        }

        if let scalarValue = materialPropertyScalar(property) {
            if scalarValue < 0.5 { return .opaque }
            if scalarValue < 1.5 { return .mask }
            return .blend
        }
    }
    return nil
}

private func decodeAlphaCutoffFromMaterialMetadata(_ mdlMaterial: MDLMaterial) -> Float? {
    for index in 0 ..< mdlMaterial.count {
        guard let property = mdlMaterial[index] else { continue }
        let key = normalizedMaterialPropertyName(property.name)
        let likelyCutoffProperty = key.contains("alphacutoff")
            || key.contains("alphathreshold")
            || key.contains("maskcutoff")
            || key.contains("maskthreshold")
            || key.contains("opacitycutoff")
            || key.contains("opacitythreshold")

        guard likelyCutoffProperty else { continue }
        if let scalarValue = materialPropertyScalar(property) {
            return clamp01(scalarValue)
        }
    }
    return nil
}

private func textureFormatHasAlpha(_ pixelFormat: MTLPixelFormat) -> Bool {
    switch pixelFormat {
    case .a8Unorm,
         .rgba8Unorm,
         .rgba8Unorm_srgb,
         .bgra8Unorm,
         .bgra8Unorm_srgb,
         .rgba16Unorm,
         .rgba16Float,
         .rgba32Float,
         .rgb10a2Unorm,
         .bgra10_xr,
         .bgra10_xr_srgb,
         .bgr10a2Unorm:
        return true
    default:
        return false
    }
}

private func textureLikelyHasAlphaChannel(_ texture: MTLTexture?) -> Bool {
    guard let texture else { return false }
    return textureFormatHasAlpha(texture.pixelFormat)
}

/// Enable per-operation cache logging in `TextureLoader`.
///
/// When `true` every GPU texture load — hit or miss — emits a `[TextureCache]` log line
/// with the cache key, key source, MDLTexture object identity, texture name, and map type.
/// Set this flag before loading assets to diagnose cache-key collisions.
///
/// **This flag is temporary and intended for diagnostic use only.**
/// Turn it off in production builds — logging one line per submesh texture per upload
/// can be very noisy for large scenes.
public nonisolated(unsafe) var textureCacheLoggingEnabled: Bool = false

/// Tracks whether a texture slot is at full or capped resolution
public enum TextureStreamingLevel: Equatable {
    case full // Native source resolution (nil cap — no downsampling)
    case capped // Downsampled to medium tier (e.g. maxTextureDimension = 1024 px)
    case minimum // Downsampled to minimum tier (e.g. minimumTextureDimension = 256 px)
}

public struct Material {
    public var baseColor: TextureDescriptor
    public var roughness: TextureDescriptor
    public var metallic: TextureDescriptor
    public var normal: TextureDescriptor
    public var emissive: TextureDescriptor
    public var height: TextureDescriptor = .init()

    // Texture URLs
    public var baseColorURL: URL?
    public var roughnessURL: URL?
    public var metallicURL: URL?
    public var normalURL: URL?
    public var emissiveURL: URL?
    public var heightURL: URL?

    // Store MDLTexture references for embedded textures (USDZ)
    // These allow us to re-export or extract texture data later
    public var baseColorMDLTexture: MDLTexture?
    public var roughnessMDLTexture: MDLTexture?
    public var metallicMDLTexture: MDLTexture?
    public var normalMDLTexture: MDLTexture?
    public var emissiveMDLTexture: MDLTexture?
    public var heightMDLTexture: MDLTexture?

    // Original texture dimensions before any loader-time capping.
    // Used by runtime texture streaming to know the true source resolution.
    public var baseColorSourceDimensions: simd_int2?
    public var roughnessSourceDimensions: simd_int2?
    public var metallicSourceDimensions: simd_int2?
    public var normalSourceDimensions: simd_int2?
    public var emissiveSourceDimensions: simd_int2?
    public var heightSourceDimensions: simd_int2?

    // Texture streaming level tracking (for progressive streaming)
    public var baseColorStreamingLevel: TextureStreamingLevel = .full
    public var roughnessStreamingLevel: TextureStreamingLevel = .full
    public var metallicStreamingLevel: TextureStreamingLevel = .full
    public var normalStreamingLevel: TextureStreamingLevel = .full
    public var emissiveStreamingLevel: TextureStreamingLevel = .full
    public var heightStreamingLevel: TextureStreamingLevel = .full

    // Default values
    public var baseColorValue: simd_float4 = .init(1.0, 1.0, 1.0, 1.0)
    public var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    public var emissiveValue: simd_float3 = .zero
    public var roughnessValue: Float = 1.0
    public var metallicValue: Float = 0.0
    public var roughnessChannel: UntoldTextureChannel = .r
    public var metallicChannel: UntoldTextureChannel = .r

    // Disney material properties
    public var specular: Float = 0.0
    public var specularTint: Float = 0.0
    public var subsurface: Float = 0.0
    public var anisotropic: Float = 0.0
    public var sheen: Float = 0.0
    public var sheenTint: Float = 0.0
    public var clearCoat: Float = 0.0
    public var clearCoatGloss: Float = 0.0
    public var ior: Float = 1.5
    public var emit: Bool = false
    public var interactWithLight: Bool = true
    public var alphaMode: MaterialAlphaMode = .opaque
    public var alphaCutoff: Float = 0.5

    /// Parallax Occlusion Mapping height parameters. `heightScale` is the total ray-march
    /// depth in UV-normalized units — named after Blender's Displacement node "Scale" input,
    /// but NOT unit-equivalent: Blender's Scale is a world-space distance, this is a
    /// UV-space fraction. A raw Scale value carried through from Blender needs retuning, not
    /// a straight copy (see the exporter's `ExportedMaterial.height_scale` docstring).
    /// `heightMidlevel` matches Blender's "Midlevel" input. See
    /// docs/proposals/HeightMapParallaxOcclusionMapping.md.
    public var heightScale: Float = 0.05
    public var heightMidlevel: Float = 0.5
    /// Contrast-stretch applied to the raw height sample before `heightMidlevel`:
    /// `(raw - heightRemapMin) / (heightRemapMax - heightRemapMin)`, saturated to [0,1].
    /// Identity by default (0,1). Many real-world displacement maps (e.g. Substance/Poliigon
    /// exports) only use a narrow slice of the full [0,1] range — POM has almost no local
    /// contrast to work with unless that slice is stretched back out first.
    public var heightRemapMin: Float = 0.0
    public var heightRemapMax: Float = 1.0
    public var heightEnabled: Bool = true

    /// Texture presence flags
    public var hasNormalMap: Bool {
        normal.texture != nil
    }

    public var hasBaseMap: Bool {
        baseColor.texture != nil
    }

    public var hasRoughMap: Bool {
        roughness.texture != nil
    }

    public var hasMetalMap: Bool {
        metallic.texture != nil
    }

    public var hasEmissiveMap: Bool {
        emissive.texture != nil
    }

    public var hasHeightMap: Bool {
        height.texture != nil
    }

    public var hasTransparency: Bool {
        alphaMode == .blend
    }

    public var stScale: Float = 1.0

    @available(*, deprecated, message: "Material name is no longer used for initialization.")
    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader, name: String) {
        _ = name
        self.init(mdlMaterial: mdlMaterial, textureLoader: textureLoader)
    }

    init(runtimeMaterial: RuntimeMaterialSource, device: MTLDevice) {
        let textureLoader = MTKTextureLoader(device: device)
        let nativeLoader = NativeTextureLoader(device: device)
        let fileManager = FileManager.default

        func loadRuntimeTexture(_ label: String, reference: RuntimeTextureReference?, isSRGB: Bool) -> MTLTexture? {
            guard let reference, let url = reference.sourceURL else { return nil }
            let fileExists = fileManager.fileExists(atPath: url.path)
            Logger.log(
                message: "[UntoldTexture] \(label) '\(runtimeMaterial.name ?? "<unnamed material>")' -> \(url.path) | exists=\(fileExists)",
                category: LogCategory.textureLoading.rawValue
            )

            // ASTC textures stored in the engine-native .utex container bypass
            // MTKTextureLoader entirely and are uploaded directly to the GPU.
            if reference.textureFormat.isNativeContainer {
                return nativeLoader?.loadTexture(
                    from: url,
                    label: "\(runtimeMaterial.name ?? "material")_\(label.lowercased())"
                )
            }

            let options: [MTKTextureLoader.Option: Any] = [
                .textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .SRGB: NSNumber(value: isSRGB),
                .generateMipmaps: NSNumber(value: true),
            ]

            // Grayscale PNGs produce an r8Unorm Metal texture.  The shader samples it as
            // RGBA where G=B=0, making the mesh appear solid red.  Detect and expand to
            // RGBA via Core Graphics before handing off to MTKTextureLoader.
            if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
               cgImage.colorSpace?.model == .monochrome
            {
                let w = cgImage.width, h = cgImage.height
                let colorSpace = isSRGB
                    ? (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
                    : CGColorSpaceCreateDeviceRGB()
                if let ctx = CGContext(
                    data: nil, width: w, height: h,
                    bitsPerComponent: 8, bytesPerRow: w * 4,
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue).rawValue
                ) {
                    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
                    if let rgbaImage = ctx.makeImage(),
                       let texture = try? textureLoader.newTexture(cgImage: rgbaImage, options: options)
                    {
                        Logger.log(
                            message: "[UntoldTexture] Expanded grayscale \(label.lowercased()) to RGBA '\(runtimeMaterial.name ?? "<unnamed material>")' \(texture.width)x\(texture.height)",
                            category: LogCategory.textureLoading.rawValue
                        )
                        return texture
                    }
                }
            }

            do {
                let texture = try textureLoader.newTexture(URL: url, options: options)
                Logger.log(
                    message: "[UntoldTexture] Loaded \(label.lowercased()) texture '\(runtimeMaterial.name ?? "<unnamed material>")' \(texture.width)x\(texture.height)",
                    category: LogCategory.textureLoading.rawValue
                )
                return texture
            } catch {
                handleError(.textureFailedLoading, "\(label) \(error.localizedDescription)", runtimeMaterial.name ?? "<unnamed material>")
                return nil
            }
        }

        let baseTexture = loadRuntimeTexture("Base color", reference: runtimeMaterial.baseColorTexture, isSRGB: runtimeMaterial.baseColorTexture?.isSRGB ?? true)
        let normalTexture = loadRuntimeTexture("Normal", reference: runtimeMaterial.normalTexture, isSRGB: false)
        let metallicTexture = loadRuntimeTexture("Metallic", reference: runtimeMaterial.metallicTexture, isSRGB: false)
        let roughnessTexture = loadRuntimeTexture("Roughness", reference: runtimeMaterial.roughnessTexture, isSRGB: false)
        let emissiveTexture = loadRuntimeTexture("Emissive", reference: runtimeMaterial.emissiveTexture, isSRGB: runtimeMaterial.emissiveTexture?.isSRGB ?? true)
        let heightTexture = loadRuntimeTexture("Height", reference: runtimeMaterial.heightTexture, isSRGB: false)

        baseColor = createTextureDescriptor(device: device, texture: baseTexture, wrapMode: .repeat)
        roughness = createTextureDescriptor(device: device, texture: roughnessTexture, wrapMode: .repeat)
        metallic = createTextureDescriptor(device: device, texture: metallicTexture, wrapMode: .repeat)
        normal = createTextureDescriptor(device: device, texture: normalTexture, wrapMode: .repeat)
        emissive = createTextureDescriptor(device: device, texture: emissiveTexture, wrapMode: .repeat)
        height = createTextureDescriptor(device: device, texture: heightTexture, wrapMode: .repeat)

        baseColorURL = runtimeMaterial.baseColorTexture?.sourceURL
        normalURL = runtimeMaterial.normalTexture?.sourceURL
        roughnessURL = runtimeMaterial.roughnessTexture?.sourceURL
        metallicURL = runtimeMaterial.metallicTexture?.sourceURL
        emissiveURL = runtimeMaterial.emissiveTexture?.sourceURL
        heightURL = runtimeMaterial.heightTexture?.sourceURL

        baseColorSourceDimensions = runtimeMaterial.baseColorTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }
        normalSourceDimensions = runtimeMaterial.normalTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }
        roughnessSourceDimensions = runtimeMaterial.roughnessTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }
        metallicSourceDimensions = runtimeMaterial.metallicTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }
        emissiveSourceDimensions = runtimeMaterial.emissiveTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }
        heightSourceDimensions = runtimeMaterial.heightTexture.flatMap { tex in
            guard let width = tex.width, let height = tex.height else { return nil }
            return simd_int2(Int32(width), Int32(height))
        }

        baseColorValue = runtimeMaterial.baseColorFactor
        emissiveValue = runtimeMaterial.emissiveFactor
        roughnessValue = runtimeMaterial.roughnessFactor
        metallicValue = runtimeMaterial.metallicFactor
        roughnessChannel = runtimeMaterial.roughnessTextureChannel
        metallicChannel = runtimeMaterial.metallicTextureChannel
        alphaCutoff = runtimeMaterial.alphaCutoff
        heightScale = runtimeMaterial.heightScale
        heightMidlevel = runtimeMaterial.heightMidlevel
        heightRemapMin = runtimeMaterial.heightRemapMin
        heightRemapMax = runtimeMaterial.heightRemapMax

        let alphaModeBits = runtimeMaterial.flags & 0b11
        alphaMode = MaterialAlphaMode(rawValue: Int32(alphaModeBits)) ?? .opaque
    }

    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader) {
        let baseColorProperty = mdlMaterial.property(with: .baseColor)
        var baseColorDims: simd_int2?
        var roughnessDims: simd_int2?
        var metallicDims: simd_int2?
        var normalDims: simd_int2?
        var emissiveDims: simd_int2?
        var heightDims: simd_int2?

        // Load textures and set URLs
        let baseColorTex = textureLoader.loadTexture(
            from: baseColorProperty,
            isSRGB: true,
            outputURL: &baseColorURL,
            outputMDLTexture: &baseColorMDLTexture,
            outputSourceDimensions: &baseColorDims,
            mapType: "Basecolor map"
        )
        baseColor = createTextureDescriptor(device: renderInfo.device, texture: baseColorTex, wrapMode: .repeat)

        let normalTex = textureLoader.loadTexture(
            from: mdlMaterial.property(with: .tangentSpaceNormal),
            isSRGB: false,
            outputURL: &normalURL,
            outputMDLTexture: &normalMDLTexture,
            outputSourceDimensions: &normalDims,
            mapType: "Normal map"
        )
        normal = createTextureDescriptor(device: renderInfo.device, texture: normalTex, wrapMode: .repeat)

        let roughnessTex = textureLoader.loadTexture(
            from: mdlMaterial.property(with: .roughness),
            isSRGB: false,
            outputURL: &roughnessURL,
            outputMDLTexture: &roughnessMDLTexture,
            outputSourceDimensions: &roughnessDims,
            mapType: "Roughness map"
        )
        roughness = createTextureDescriptor(device: renderInfo.device, texture: roughnessTex, wrapMode: .repeat)

        let metallicTex = textureLoader.loadTexture(
            from: mdlMaterial.property(with: .metallic),
            isSRGB: false,
            outputURL: &metallicURL,
            outputMDLTexture: &metallicMDLTexture,
            outputSourceDimensions: &metallicDims,
            mapType: "Metallic map"
        )
        metallic = createTextureDescriptor(device: renderInfo.device, texture: metallicTex, wrapMode: .repeat)

        let emissiveTex = textureLoader.loadTexture(
            from: mdlMaterial.property(with: .emission),
            isSRGB: true,
            outputURL: &emissiveURL,
            outputMDLTexture: &emissiveMDLTexture,
            outputSourceDimensions: &emissiveDims,
            mapType: "Emissive map"
        )
        emissive = createTextureDescriptor(device: renderInfo.device, texture: emissiveTex, wrapMode: .repeat)

        let heightTex = textureLoader.loadTexture(
            from: mdlMaterial.property(with: .displacement),
            isSRGB: false,
            outputURL: &heightURL,
            outputMDLTexture: &heightMDLTexture,
            outputSourceDimensions: &heightDims,
            mapType: "Height map"
        )
        height = createTextureDescriptor(device: renderInfo.device, texture: heightTex, wrapMode: .repeat)
        if let displacementScale = mdlMaterial.property(with: .displacementScale)?.floatValue {
            heightScale = displacementScale
        }

        baseColorSourceDimensions = baseColorDims
        normalSourceDimensions = normalDims
        roughnessSourceDimensions = roughnessDims
        metallicSourceDimensions = metallicDims
        emissiveSourceDimensions = emissiveDims
        heightSourceDimensions = heightDims

        /// Set texture streaming levels based on whether textures were dimension-capped.
        func isCapped(_ texture: MTLTexture?, _ sourceDims: simd_int2?) -> Bool {
            guard let texture, let sourceDims else { return false }
            return texture.width < Int(sourceDims.x) || texture.height < Int(sourceDims.y)
        }

        if isCapped(baseColorTex, baseColorSourceDimensions) {
            baseColorStreamingLevel = .capped
        }
        if isCapped(normalTex, normalSourceDimensions) {
            normalStreamingLevel = .capped
        }
        if isCapped(roughnessTex, roughnessSourceDimensions) {
            roughnessStreamingLevel = .capped
        }
        if isCapped(metallicTex, metallicSourceDimensions) {
            metallicStreamingLevel = .capped
        }
        if isCapped(emissiveTex, emissiveSourceDimensions) {
            emissiveStreamingLevel = .capped
        }
        if isCapped(heightTex, heightSourceDimensions) {
            heightStreamingLevel = .capped
        }

        var baseColorHasExplicitAlpha = false
        if let decodedBase = decodeBaseColorFactor(baseColorProperty) {
            baseColorValue = decodedBase.value
            baseColorHasExplicitAlpha = decodedBase.hasExplicitAlpha
        }
        roughnessValue = mdlMaterial.property(with: .roughness)?.floatValue ?? roughnessValue
        metallicValue = mdlMaterial.property(with: .metallic)?.floatValue ?? metallicValue

        // Opacity scalar modulates base alpha when provided by source material metadata.
        let opacityScalar = materialPropertyScalar(mdlMaterial.property(with: .opacity))
        if let opacityScalar {
            baseColorValue.w = clamp01(baseColorValue.w * opacityScalar)
        }

        // Import alpha metadata first; if unavailable, infer from common fallback signals.
        let explicitAlphaMode = decodeAlphaModeFromMaterialMetadata(mdlMaterial)
        let explicitAlphaCutoff = decodeAlphaCutoffFromMaterialMetadata(mdlMaterial)

        if let explicitAlphaMode {
            alphaMode = explicitAlphaMode
            if let explicitAlphaCutoff {
                alphaCutoff = explicitAlphaCutoff
            }
        } else {
            let hasAlphaFactor = baseColorHasExplicitAlpha && baseColorValue.w < 0.999
            let opacityBelowOne = (opacityScalar ?? 1.0) < 0.999

            if hasAlphaFactor || opacityBelowOne {
                alphaMode = .blend
            } else if textureLikelyHasAlphaChannel(baseColor.texture) {
                alphaMode = .mask
                alphaCutoff = explicitAlphaCutoff ?? 0.5
            } else {
                alphaMode = .opaque
            }
        }

        // if textures exist, the roughnessValue and MetallicValue act as modulators
        if roughness.texture != nil {
            roughnessValue = 1.0
        }

        if metallic.texture != nil {
            metallicValue = 1.0
        }

        // Load remaining Disney properties
        specular = mdlMaterial.property(with: .specular)?.floatValue ?? 0.0
        specularTint = mdlMaterial.property(with: .specularTint)?.floatValue ?? 0.0
        subsurface = mdlMaterial.property(with: .subsurface)?.floatValue ?? 0.0
        anisotropic = mdlMaterial.property(with: .anisotropicRotation)?.floatValue ?? 0.0
        sheenTint = mdlMaterial.property(with: .sheenTint)?.floatValue ?? 0.0
        clearCoat = mdlMaterial.property(with: .clearcoat)?.floatValue ?? 0.0
        ior = mdlMaterial.property(with: .materialIndexOfRefraction)?.floatValue ?? 1.5
    }
}

final class TextureLoader {
    /// Initial texture cap applied during material import.
    ///
    /// This value is intentionally aligned with `TextureStreamingSystem.platformDefaultMinimumTextureDimension`
    /// so that all entities start at the streaming system's minimum tier. The streaming system then
    /// only ever upgrades textures (toward medium or full) as the camera approaches — it never
    /// issues an immediate downgrade on freshly-loaded entities. Keeping bootstrap = minimum tier
    /// avoids the visual artifact where a far entity loads at a higher resolution and is then
    /// immediately degraded by the streaming system before the user moves the camera.
    static let defaultMaxTextureDimension: Int = {
        #if os(visionOS)
            192 // matches TextureStreamingSystem.platformDefaultMinimumTextureDimension on visionOS
        #else
            256 // matches TextureStreamingSystem.platformDefaultMinimumTextureDimension on macOS/iOS
        #endif
    }()

    let device: MTLDevice
    private let mtkLoader: MTKTextureLoader
    private var textureCache: [TextureCacheKey: MTLTexture] = [:]
    private var sourceDimensionsCache: [TextureCacheKey: simd_int2] = [:]

    /// Serializes all cache reads and writes when the same TextureLoader instance
    /// is shared across concurrent entity uploads (OOC path).
    private let stateLock = NSLock()

    /// Tracks unique textures loaded (not cache hits) for summary logging
    private var loadedTextureCount: Int = 0
    private var loadedTextureBytes: Int = 0

    private struct TextureCacheKey: Hashable {
        let id: String
        let isSRGB: Bool
    }

    /// Command queue for GPU downsampling operations
    private let downsampleCommandQueue: MTLCommandQueue?

    /// Maximum texture dimension (width or height). Textures larger than this
    /// are GPU-downsampled at load time. Set to 0 to disable.
    var maxTextureDimension: Int = TextureLoader.defaultMaxTextureDimension

    /// Tracks bytes saved by dimension capping for summary logging
    private var savedBytesByCapping: Int = 0

    init(device: MTLDevice) {
        self.device = device
        mtkLoader = MTKTextureLoader(device: device)
        downsampleCommandQueue = device.makeCommandQueue()
    }

    /// Downsample a texture if it exceeds maxTextureDimension, preserving aspect ratio.
    /// Returns the original texture if within limits or if downsampling fails.
    private func downsampleIfNeeded(_ texture: MTLTexture) -> MTLTexture {
        guard maxTextureDimension > 0 else { return texture }
        let maxDim = maxTextureDimension
        guard texture.width > maxDim || texture.height > maxDim else { return texture }

        let aspect = Float(texture.width) / Float(texture.height)
        let targetWidth: Int
        let targetHeight: Int
        if texture.width >= texture.height {
            targetWidth = maxDim
            targetHeight = max(1, Int(Float(maxDim) / aspect))
        } else {
            targetHeight = maxDim
            targetWidth = max(1, Int(Float(maxDim) * aspect))
        }

        let mipCount = Int(log2(Float(max(targetWidth, targetHeight)))) + 1
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: texture.pixelFormat.mpsWritableFormat,
            width: targetWidth,
            height: targetHeight,
            mipmapped: true
        )
        desc.mipmapLevelCount = mipCount
        desc.usage = [.shaderRead, .shaderWrite, .pixelFormatView]
        desc.storageMode = .private

        guard let target = device.makeTexture(descriptor: desc),
              let commandBuffer = downsampleCommandQueue?.makeCommandBuffer()
        else { return texture }

        // MPS reads sRGB source textures through the texture unit, which auto-decodes
        // sRGB → linear before filtering, and writes raw (already-linear) bytes to the
        // destination. Metal also disallows a writable sRGB destination, so target was
        // allocated in the linear sibling format (mpsWritableFormat).
        //
        // target's bytes are therefore genuinely linear, not sRGB-encoded — do NOT view
        // it back as the source's sRGB format. Doing so previously caused the material
        // shader's hardware sRGB decode to run a second time on already-linear data,
        // silently darkening/shifting every base color texture capped at import time
        // (see TextureStreamingSystem.downsampleTexture for the same fix on the
        // streaming-tier resample path). Returning target in its natural linear format
        // is correct as-is.
        let scale = MPSImageBilinearScale(device: device)
        scale.encode(commandBuffer: commandBuffer, sourceTexture: texture, destinationTexture: target)

        if let blit = commandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: target)
            blit.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return target
    }

    /// Log a summary of all textures loaded by this loader instance
    func logSummary() {
        _ = loadedTextureCount
        _ = loadedTextureBytes
        _ = savedBytesByCapping
    }

    @discardableResult
    private func cacheAndRecordTexture(
        loadedTexture texture: MTLTexture,
        sourceTexture fullTexture: MTLTexture,
        cacheKey: TextureCacheKey,
        isSRGB: Bool,
        nameForLog: String,
        outputSourceDimensions: inout simd_int2?
    ) -> MTLTexture {
        let sourceDims = simd_int2(Int32(fullTexture.width), Int32(fullTexture.height))
        outputSourceDimensions = sourceDims
        sourceDimensionsCache[cacheKey] = sourceDims
        _ = nameForLog

        let wasDownsampled = texture.width < fullTexture.width || texture.height < fullTexture.height
        if wasDownsampled {
            savedBytesByCapping += fullTexture.allocatedSize - texture.allocatedSize
        }
        loadedTextureCount += 1
        loadedTextureBytes += texture.allocatedSize

        // A downsampled texture already carries the correct linear pixel format from
        // downsampleIfNeeded — its bytes are genuinely linear (see the comment there).
        // Only a texture returned at full resolution (never resampled) needs the sRGB
        // view reconciliation, and it's a no-op there since the loader-assigned format
        // already matches.
        let texView = wasDownsampled ? texture : textureViewMatchingSRGB(texture, wantSRGB: isSRGB)
        textureCache[cacheKey] = texView
        return texView
    }

    private func textureViewMatchingSRGB(_ tex: MTLTexture, wantSRGB: Bool) -> MTLTexture {
        let pairs: [MTLPixelFormat: (linear: MTLPixelFormat, srgb: MTLPixelFormat)] = [
            .rgba8Unorm: (.rgba8Unorm, .rgba8Unorm_srgb),
            .rgba8Unorm_srgb: (.rgba8Unorm, .rgba8Unorm_srgb),
            .bgra8Unorm: (.bgra8Unorm, .bgra8Unorm_srgb),
            .bgra8Unorm_srgb: (.bgra8Unorm, .bgra8Unorm_srgb),
        ]

        guard let pair = pairs[tex.pixelFormat] else { return tex }
        let target = wantSRGB ? pair.srgb : pair.linear
        if tex.pixelFormat == target { return tex }
        return tex.makeTextureView(pixelFormat: target) ?? tex
    }

    /// Parse a ModelIO USDZ bracket-notation string into a USDZ file URL and the
    /// inner texture path within the package.
    ///
    /// ModelIO returns embedded texture paths in the form:
    ///   `"file:///path/to/scene.usdz[0/texture_base_color.png]"`
    ///
    /// This method extracts the host-file URL (`file:///path/to/scene.usdz`) and the
    /// inner path (`0/texture_base_color.png`). Returns `nil` if the string is not in
    /// bracket-notation format, has an empty inner path, or the host URL is not a file URL.
    ///
    /// Exposed as `internal` so it can be unit-tested from `UntoldEngineTests`.
    static func parseUSDZBracketPath(from str: String) -> (usdzURL: URL, innerPath: String)? {
        guard let openBracket = str.lastIndex(of: "["),
              let closeBracket = str.lastIndex(of: "]"),
              openBracket < closeBracket
        else { return nil }

        let usdzPathStr = String(str[str.startIndex ..< openBracket])
        let innerPath = String(str[str.index(after: openBracket) ..< closeBracket])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")

        guard !innerPath.isEmpty,
              let usdzURL = URL(string: usdzPathStr),
              usdzURL.isFileURL
        else { return nil }

        return (usdzURL, innerPath)
    }

    /// Build a stable identity URL for USDZ-embedded textures.
    ///
    /// **Priority 1 — bracket-notation path:** When `property.stringValue` contains a parseable
    /// bracket-notation path (e.g. `"file:///scene.usdz[0/texture.png]"`), returns
    /// `usdz-embedded://<inner-path>`.  This is the most specific identifier available.
    ///
    /// **Priority 2 — texture name + asset scope:** When no bracket path is found and
    /// `textureName` is non-empty, returns `usdz-embedded://<assetScope>/<textureName>`.
    /// `assetScope` is the USDZ filename (from `assetBasePath`) or "embedded" if unknown.
    /// This is stable across reload cycles and consistent for all entities that load the same
    /// USDZ file, which is required for BatchingSystem.getMaterialHash to group them together.
    ///
    /// Using just `textureName` (without `assetScope`) was the original bug: it produced the
    /// same URL for any two USDZ files that happened to share a texture name, causing cache
    /// poisoning across assets.  Scoping to the USDZ filename eliminates cross-asset collisions
    /// while preserving cross-entity consistency within the same file.
    private func embeddedTextureURL(from property: MDLMaterialProperty, textureName: String = "") -> URL? {
        // Priority 1: bracket-notation path → most specific
        if let propertyString = property.stringValue,
           let parsed = TextureLoader.parseUSDZBracketPath(from: propertyString)
        {
            let encodedPath = parsed.innerPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? parsed.innerPath
            return URL(string: "usdz-embedded://\(encodedPath)")
        }

        // Priority 2: stable name-based URL scoped to the USDZ file.
        // Consistent across all entities from the same USDZ, required for batching.
        guard !textureName.isEmpty else { return nil }
        let scope = (assetBasePath?.lastPathComponent)
            .flatMap { $0.isEmpty ? nil : $0 } ?? "embedded"
        let encodedScope = scope.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? scope
        let encodedName = textureName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? textureName
        return URL(string: "usdz-embedded://\(encodedScope)/\(encodedName)")
    }

    /// Build a unique URL for an MDLTexture keyed by its object pointer.
    ///
    /// Used as the GPU texture cache key when bracket-notation path is absent.
    /// The pointer is stable across GPU-resource eviction/reload cycles.
    ///
    /// Two MDLTexture objects with the SAME pointer are physically the same texture
    /// object and should share a GPU texture — this key correctly deduplicates them.
    /// Two MDLTexture objects with DIFFERENT pointers are different textures — this key
    /// correctly gives them independent cache entries even if they carry the same name.
    private static func objectIdentityURL(for mdlTex: MDLTexture) -> URL {
        URL(string: "mdl-obj-\(UInt(bitPattern: ObjectIdentifier(mdlTex)))")!
    }

    func loadTexture(from property: MDLMaterialProperty?,
                     isSRGB: Bool,
                     outputURL: inout URL?,
                     outputMDLTexture: inout MDLTexture?,
                     outputSourceDimensions: inout simd_int2?,
                     mapType: String) -> MTLTexture?
    {
        guard let property else { return nil }
        stateLock.lock()
        defer { stateLock.unlock() }

        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: isSRGB,
            .generateMipmaps: true,
            .origin: MTKTextureLoader.Origin.topLeft, // matches MDL byte layout
        ]

        // 1) Prefer the sampler path (works for USDZ-embedded textures)
        if let sampler = property.textureSamplerValue,
           let mdlTex = sampler.texture
        {
            let textureName = mdlTex.name.isEmpty ? "embedded_\(mapType.replacingOccurrences(of: " ", with: "_"))" : mdlTex.name

            // Determine whether a bracket-notation path is available for this texture.
            // Bracket paths (e.g. "usdz-embedded://0/floor_albedo.png") are unique per
            // physical embedded file and are safe to use as both a cache key and a stable URL.
            //
            // When bracket notation is absent, `embeddedTextureURL` falls back to a
            // name-scoped URL (Priority 2: "usdz-embedded://GameData/embedded_Basecolor_map").
            // That URL is appropriate for `outputURL` / BatchingSystem.getMaterialHash (cross-
            // entity consistency), but is UNSAFE as a GPU texture cache key: two genuinely
            // different materials whose MDLTextures both lack names (or share the same name)
            // produce the same string and collide in the cache, causing the second entity to
            // receive the first entity's GPU texture.
            //
            // Fix: split cache key from stable URL.
            // - cacheKeyURL uses object identity (mdl-obj-<ptr>) when no bracket path is found.
            //   Two MDLTexture objects with different pointers never collide, regardless of name.
            //   Two references to the SAME MDLTexture object (genuinely shared texture) share
            //   the same pointer → correctly share the cached GPU texture.
            // - uniqueURL (stored in outputURL) keeps the stable name-based or bracket URL so
            //   BatchingSystem.getMaterialHash continues to group shared materials correctly.
            let hasBracketPath: Bool = {
                guard let str = property.stringValue else { return false }
                return TextureLoader.parseUSDZBracketPath(from: str) != nil
            }()

            // stableURL: used for outputURL / material hashing (stable, cross-entity consistent).
            let stableURL = embeddedTextureURL(from: property, textureName: textureName)

            // cacheKeyURL: used exclusively as the GPU texture cache key.
            // Bracket path when available (unique per file); object identity otherwise.
            let cacheKeyURL: URL = hasBracketPath
                ? (stableURL ?? TextureLoader.objectIdentityURL(for: mdlTex))
                : TextureLoader.objectIdentityURL(for: mdlTex)

            // uniqueURL stored in outputURL / baseColorURL etc.
            //
            // When a bracket path is available it is unique per embedded file and safe for
            // both caching and batch-material hashing — use it directly.
            //
            // When bracket notation is absent, the name-based stableURL collapses every
            // unnamed texture from the same USDZ to the same string
            // (e.g. "usdz-embedded://scene.usdz/embedded_Basecolor_map").
            // BatchingSystem.normalizeTextureURL then strips the asset-scope host, leaving
            // "usdz-embedded://embedded_Basecolor_map" for ALL entities, so they all hash
            // to the same BatchBuildKey and are grouped into one batch whose representative
            // material is only the first entity's GPU texture — showing the wrong texture
            // on every other entity.
            //
            // Fix: mirror cacheKeyURL — use object identity when no bracket path is found.
            // Same MDLTexture pointer ↔ same physical texture ↔ share GPU cache + batch.
            // Different pointers ↔ different textures ↔ separate batch groups.
            let uniqueURL: URL = hasBracketPath
                ? (stableURL ?? TextureLoader.objectIdentityURL(for: mdlTex))
                : TextureLoader.objectIdentityURL(for: mdlTex)

            let cacheKey = TextureCacheKey(id: cacheKeyURL.absoluteString, isSRGB: isSRGB)

            // Diagnostic logging [temporary] — controlled by textureCacheLoggingEnabled.
            // Set `textureCacheLoggingEnabled = true` before loading to trace cache hits/misses.
            if textureCacheLoggingEnabled {
                let keySource: String
                if hasBracketPath {
                    keySource = "bracket"
                } else if mdlTex.name.isEmpty {
                    keySource = "obj-identity(unnamed)"
                } else {
                    keySource = "obj-identity(named-no-bracket)"
                }
                let isHit = textureCache[cacheKey] != nil
                Logger.log(
                    message: "[TextureCache] \(isHit ? "HIT " : "MISS") key=\(cacheKeyURL.absoluteString) source=\(keySource) mdlTex=0x\(String(UInt(bitPattern: ObjectIdentifier(mdlTex)), radix: 16)) name='\(textureName)' map=\(mapType) isSRGB=\(isSRGB)",
                    category: LogCategory.textureLoading.rawValue
                )
            }

            if let cached = textureCache[cacheKey] {
                outputURL = uniqueURL
                outputMDLTexture = mdlTex
                outputSourceDimensions = sourceDimensionsCache[cacheKey]
                return cached
            }

            do {
                let fullTex = try mtkLoader.newTexture(texture: mdlTex, options: options)
                let tex = downsampleIfNeeded(fullTex)

                outputURL = uniqueURL
                outputMDLTexture = mdlTex

                return cacheAndRecordTexture(
                    loadedTexture: tex,
                    sourceTexture: fullTex,
                    cacheKey: cacheKey,
                    isSRGB: isSRGB,
                    nameForLog: textureName,
                    outputSourceDimensions: &outputSourceDimensions
                )
            } catch let initialError {
                // mtkLoader.newTexture(texture:) failed — this happens when loadTextures() was
                // skipped for large assets and the MDLTexture has no pixel data yet.
                // Ask the MDLTexture to lazily fetch its own data from the USDZ package and retry.
                // This loads only this one texture, not the entire asset.
                Logger.log(
                    message: "[TextureLoad] MDL path failed for '\(textureName)' — retrying with lazy hydration (\(initialError.localizedDescription))",
                    category: LogCategory.textureLoading.rawValue
                )
                if mdlTex.texelDataWithTopLeftOrigin(atMipLevel: 0, create: true) != nil,
                   let retryTex = try? mtkLoader.newTexture(texture: mdlTex, options: options)
                {
                    let tex = downsampleIfNeeded(retryTex)
                    outputURL = uniqueURL
                    outputMDLTexture = mdlTex
                    return cacheAndRecordTexture(
                        loadedTexture: tex,
                        sourceTexture: retryTex,
                        cacheKey: cacheKey,
                        isSRGB: isSRGB,
                        nameForLog: textureName,
                        outputSourceDimensions: &outputSourceDimensions
                    )
                }
                Logger.log(
                    message: "[TextureLoad] Lazy hydration also failed for '\(textureName)' — falling through to URL paths",
                    category: LogCategory.textureLoading.rawValue
                )
                handleError(.textureFailedLoading)
            }
        }

        // URL (absolute or resolved by USD/MDL)
        if let url = property.urlValue {
            let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
            if let cached = textureCache[cacheKey] {
                outputURL = url
                outputSourceDimensions = sourceDimensionsCache[cacheKey]
                return cached
            }
            if let fullTex = try? mtkLoader.newTexture(URL: url, options: options) {
                let tex = downsampleIfNeeded(fullTex)
                outputURL = url
                return cacheAndRecordTexture(
                    loadedTexture: tex,
                    sourceTexture: fullTex,
                    cacheKey: cacheKey,
                    isSRGB: isSRGB,
                    nameForLog: url.lastPathComponent,
                    outputSourceDimensions: &outputSourceDimensions
                )
            }
        }

        // String (relative) -> try to resolve against the model's base path if you keep it
        if let str = property.stringValue, !str.isEmpty {
            // 0) USDZ embedded texture: "file:///path/to.usdz[0/texture.png]"
            //    sampler.texture was nil (loadTextures() was skipped) so path 1 never fired.
            //    Build a package URL (slash-separated) and try MTKTextureLoader directly.
            if let parsed = TextureLoader.parseUSDZBracketPath(from: str) {
                let packageURL = parsed.usdzURL.appendingPathComponent(parsed.innerPath)
                let cacheKey = TextureCacheKey(id: packageURL.absoluteString, isSRGB: isSRGB)
                if let cached = textureCache[cacheKey] {
                    outputURL = packageURL
                    outputSourceDimensions = sourceDimensionsCache[cacheKey]
                    return cached
                }
                if let fullTex = try? mtkLoader.newTexture(URL: packageURL, options: options) {
                    let tex = downsampleIfNeeded(fullTex)
                    outputURL = packageURL
                    return cacheAndRecordTexture(
                        loadedTexture: tex,
                        sourceTexture: fullTex,
                        cacheKey: cacheKey,
                        isSRGB: isSRGB,
                        nameForLog: parsed.innerPath,
                        outputSourceDimensions: &outputSourceDimensions
                    )
                }
                Logger.log(
                    message: "[TextureLoad] USDZ package URL failed for '\(parsed.innerPath)' — falling through to remaining paths",
                    category: LogCategory.textureLoading.rawValue
                )
            }

            // 1) Try as-is (absolute or already-resolved)
            if let url = URL(string: str), url.isFileURL {
                let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
                if let cached = textureCache[cacheKey] {
                    outputURL = url
                    outputSourceDimensions = sourceDimensionsCache[cacheKey]
                    return cached
                }
                if let fullTex = try? mtkLoader.newTexture(URL: url, options: options) {
                    let tex = downsampleIfNeeded(fullTex)
                    outputURL = url
                    return cacheAndRecordTexture(
                        loadedTexture: tex,
                        sourceTexture: fullTex,
                        cacheKey: cacheKey,
                        isSRGB: isSRGB,
                        nameForLog: url.lastPathComponent,
                        outputSourceDimensions: &outputSourceDimensions
                    )
                }
            }
            // 2) Try against known asset base
            if let base = assetBasePath {
                let candidate = base.appendingPathComponent(str)
                let cacheKey = TextureCacheKey(id: candidate.standardizedFileURL.path, isSRGB: isSRGB)
                if let cached = textureCache[cacheKey] {
                    outputURL = candidate
                    outputSourceDimensions = sourceDimensionsCache[cacheKey]
                    return cached
                }
                if FileManager.default.fileExists(atPath: candidate.path),
                   let fullTex = try? mtkLoader.newTexture(URL: candidate, options: options)
                {
                    let tex = downsampleIfNeeded(fullTex)
                    outputURL = candidate
                    return cacheAndRecordTexture(
                        loadedTexture: tex,
                        sourceTexture: fullTex,
                        cacheKey: cacheKey,
                        isSRGB: isSRGB,
                        nameForLog: candidate.lastPathComponent,
                        outputSourceDimensions: &outputSourceDimensions
                    )
                }
            }
            // 3) Try resources bundle lookup by filename
            let name = URL(fileURLWithPath: str).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: str).pathExtension
            if let url = getResourceURL(resourceName: name, ext: ext.isEmpty ? "png" : ext, subName: nil),
               let fullTex = try? mtkLoader.newTexture(URL: url, options: options)
            {
                let tex = downsampleIfNeeded(fullTex)
                let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
                outputURL = url
                return cacheAndRecordTexture(
                    loadedTexture: tex,
                    sourceTexture: fullTex,
                    cacheKey: cacheKey,
                    isSRGB: isSRGB,
                    nameForLog: url.lastPathComponent,
                    outputSourceDimensions: &outputSourceDimensions
                )
            }
        }

        return nil
    }

    func loadDefaultColorTexture(color: simd_float4) -> MTLTexture? {
        // Generate a 1x1 texture with a solid color
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm_srgb
        descriptor.width = 1
        descriptor.height = 1
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let rawData = [UInt8(color.x * 255), UInt8(color.y * 255), UInt8(color.z * 255), UInt8(color.w * 255)]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: rawData, bytesPerRow: 4)
        return texture
    }

    func defaultTexture() -> MTLTexture {
        let size = 64
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: size, height: size, mipmapped: true)
        desc.usage = [.shaderRead]
        guard let tex = renderInfo.device.makeTexture(descriptor: desc) else {
            handleError(.textureFailedLoading, "GPU may be out of memory", "default texture")
            fatalError("Critical: Unable to create default texture. Metal device may be unavailable.")
        }

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let isDark = ((x / 8 + y / 8) % 2) == 0
                let c: UInt8 = isDark ? 200 : 50
                let i = (y * size + x) * 4
                pixels[i + 0] = c
                pixels[i + 1] = c
                pixels[i + 2] = c
                pixels[i + 3] = 255
            }
        }
        tex.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: pixels, bytesPerRow: size * 4)
        return tex
    }
}

func createTextureDescriptor(device: MTLDevice,
                             texture: MTLTexture?,
                             wrapMode: WrapMode) -> TextureDescriptor
{
    let sampler = cachedSamplerState(device: device, wrapMode: wrapMode)
    return TextureDescriptor(texture: texture, sampler: sampler, wrapMode: wrapMode)
}

private enum TextureSamplerCache {
    final class State: @unchecked Sendable {
        let lock = NSLock()
        var cache: [WrapMode: MTLSamplerState] = [:]
    }

    static let state = State()
}

private func cachedSamplerState(device: MTLDevice, wrapMode: WrapMode) -> MTLSamplerState? {
    let state = TextureSamplerCache.state
    state.lock.lock()
    defer { state.lock.unlock() }

    if let existing = state.cache[wrapMode] {
        return existing
    }

    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge
    samplerDescriptor.tAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge

    let sampler = device.makeSamplerState(descriptor: samplerDescriptor)
    if let sampler {
        state.cache[wrapMode] = sampler
    }

    return sampler
}
