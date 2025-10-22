//
//  Mesh.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
import MetalKit
import simd

public struct Mesh {
    public let metalKitMesh: MTKMesh
    public var submeshes: [SubMesh] = []
    public var modelMDLMesh: MDLMesh
    public var localSpace: simd_float4x4 = .identity
    public var worldSpace: simd_float4x4 = .identity
    var assetName: String
    var boundingBox: (min: simd_float3, max: simd_float3)
    var flipCoord: Bool = false
    var skin: Skin?
    public var spaceUniform: MTLBuffer!

    init(modelIOMesh: MDLMesh, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip: Bool) {
        modelMDLMesh = modelIOMesh

        // Transform to adjust orientation
        let transform = flip ? matrix4x4Rotation(radians: -.pi / 2.0, axis: [1, 0, 0]) : matrix_identity_float4x4
        modelIOMesh.parent?.transform?.matrix = simd_mul(transform, modelIOMesh.parent?.transform?.matrix ?? .identity)

        flipCoord = flip

        // Set local transform matrix and name
        worldSpace = modelIOMesh.parent?.transform?.matrix ?? .identity
        assetName = modelIOMesh.parent?.name ?? "Unnamed"

        // Set bounding box dimensions
        boundingBox = (min: modelIOMesh.boundingBox.minBounds, max: modelIOMesh.boundingBox.maxBounds)

        // Create tangents if the mesh has texture coordinates
        if hasTextureCoordinates(mesh: modelIOMesh) {
            modelIOMesh.addOrthTanBasis(
                forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                normalAttributeNamed: MDLVertexAttributeNormal,
                tangentAttributeNamed: MDLVertexAttributeTangent
            )
        }

        // Apply vertex descriptor for Metal layout compatibility
        modelIOMesh.vertexDescriptor = vertexDescriptor

        // allocate buffer
        spaceUniform = renderInfo.device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared]
        )

        // Create MetalKit mesh
        modelIOMesh.vertexDescriptor = vertexDescriptor
        var localMetalKitMesh: MTKMesh
        do {
            localMetalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
        } catch {
            fatalError("Failed to create MTKMesh: \(error)")
        }
        metalKitMesh = localMetalKitMesh

        // Process submeshes locally before assigning
        let processedSubmeshes: [SubMesh] = modelIOMesh.submeshes?.enumerated().compactMap { index, element in
            guard let mdlSubmesh = element as? MDLSubmesh else { return nil }
            guard index < localMetalKitMesh.submeshes.count else { return nil }
            return SubMesh(
                modelIOSubmesh: mdlSubmesh,
                metalKitSubmesh: localMetalKitMesh.submeshes[index],
                textureLoader: textureLoader,
                name: assetName
            )
        } ?? []

        submeshes = processedSubmeshes
    }

    mutating func cleanUp() {
        spaceUniform = nil
        submeshes.removeAll()
        skin?.cleanUp()
        skin = nil
    }

    // Load meshes from a file URL
    static func loadMeshes(url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice, flip: Bool) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let meshes = asset.childObjects(of: MDLObject.self).flatMap {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
        }

        if !meshes.isEmpty {
            return meshes
        }

        // ---- Fallback path: fabricate a safe default mesh ----

        return makeDefaultMesh()
    }

    static func loadSceneMeshes(url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice) -> [[Mesh]] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let meshGroups: [[Mesh]] = asset.childObjects(of: MDLObject.self).map {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: true)
        }

        // If the scene had no objects (or everything failed), return a single fallback group
        if meshGroups.isEmpty || meshGroups.allSatisfy(\.isEmpty) {
            Logger.logWarning(message: "Scene contained no usable meshes: \(url.lastPathComponent). Returning a single default fallback mesh.")
            return [makeDefaultMesh()]
        }

        return meshGroups
    }

    static func loadMeshWithName(name: String, url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let topLevelObjects = asset.childObjects(of: MDLObject.self)

        for mdlObject in topLevelObjects {
            if mdlObject.name == name {
                var meshGroup: [Mesh] = []

                for child in mdlObject.children.objects {
                    if let mesh = child as? MDLMesh {
                        let meshes = makeMeshes(object: mesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: renderInfo.device, flip: true)
                        meshGroup.append(contentsOf: meshes)
                    }
                }

                return meshGroup
            }
        }

        return []
    }

    // Recursively find and create Mesh objects from ModelIO hierarchy
    static func makeMeshes(object: MDLObject, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip: Bool) -> [Mesh] {
        var meshes = [Mesh]()

        if let mdlMesh = object as? MDLMesh {
            meshes.append(Mesh(modelIOMesh: mdlMesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip))
        }

        if object.conforms(to: MDLObjectContainerComponent.self) {
            for child in object.children.objects {
                meshes.append(contentsOf: makeMeshes(object: child, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip))
            }
        }

        return meshes
    }

    static func computeMeshBoundingBox(for meshes: [Mesh]) -> (min: simd_float3, max: simd_float3) {
        // Start with infinity bounds to ensure proper min/max comparisons
        var combinedMin = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var combinedMax = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        for mesh in meshes {
            let meshMin = mesh.boundingBox.min
            let meshMax = mesh.boundingBox.max

            // Update combined bounds
            combinedMin = simd_float3(
                min(combinedMin.x, meshMin.x),
                min(combinedMin.y, meshMin.y),
                min(combinedMin.z, meshMin.z)
            )
            combinedMax = simd_float3(
                max(combinedMax.x, meshMax.x),
                max(combinedMax.y, meshMax.y),
                max(combinedMax.z, meshMax.z)
            )
        }

        return (min: combinedMin, max: combinedMax)
    }

    // Helper to create one fallback mesh
    static func makeDefaultMesh() -> [Mesh] {
        let textureLoader = TextureLoader(device: renderInfo.device)
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

        let fallbackMDL = MDLMesh(
            sphereWithExtent: [0.5, 0.5, 0.5],
            segments: [32, 16],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )
        fallbackMDL.name = "UntoldEngine_DefaultMesh"
        let fallback = Mesh.makeMeshes(object: fallbackMDL,
                                       vertexDescriptor: vertexDescriptor.model,
                                       textureLoader: textureLoader,
                                       device: renderInfo.device,
                                       flip: true)
        if fallback.isEmpty {
            Logger.logWarning(message: "Default mesh group creation returned empty; check vertex descriptor/material pipeline.")
        }
        return fallback
    }
}

public struct SubMesh {
    public let metalKitSubmesh: MTKSubmesh
    public var material: Material?

    init(metalKitSubmesh: MTKSubmesh) {
        self.metalKitSubmesh = metalKitSubmesh
    }

    init(modelIOSubmesh: MDLSubmesh, metalKitSubmesh: MTKSubmesh, textureLoader: TextureLoader, name: String) {
        self.metalKitSubmesh = metalKitSubmesh

        // Fallback to an empty material if none is provided
        if let mdlMaterial = modelIOSubmesh.material {
            material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader, name: name)
        } else {
            material = nil
        }
    }
}

public enum WrapMode: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case clampToEdge
    case `repeat`

    public var id: Int { rawValue }

    public var description: String {
        switch self {
        case .clampToEdge: return "Clamp to Edge"
        case .repeat: return "Repeat"
        }
    }
}

public struct TextureDescriptor {
    public var texture: MTLTexture?
    public var sampler: MTLSamplerState?
    public var wrapMode: WrapMode = .clampToEdge
}

public struct Material {
    public var baseColor: TextureDescriptor
    public var roughness: TextureDescriptor
    public var metallic: TextureDescriptor
    public var normal: TextureDescriptor

    // Texture URLs
    public var baseColorURL: URL?
    public var roughnessURL: URL?
    public var metallicURL: URL?
    public var normalURL: URL?

    // Default values
    public var baseColorValue: simd_float4 = .init(1.0, 1.0, 1.0, 1.0)
    public var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    public var emissiveValue: simd_float3 = .zero
    public var roughnessValue: Float = 1.0
    public var metallicValue: Float = 0.0

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

    // Texture presence flags
    public var hasNormalMap: Bool { normal.texture != nil }
    public var hasBaseMap: Bool { baseColor.texture != nil }
    public var hasRoughMap: Bool { roughness.texture != nil }
    public var hasMetalMap: Bool { metallic.texture != nil }

    public var stScale: Float = 1.0

    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader, name: String) {
        // Load textures and set URLs
        baseColor = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .baseColor), isSRGB: true, outputURL: &baseColorURL, mapType: "Basecolor map", assetName: name), wrapMode: .repeat)

        normal = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .tangentSpaceNormal), isSRGB: false, outputURL: &normalURL, mapType: "Normal map", assetName: name), wrapMode: .clampToEdge)

        roughness = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .roughness), isSRGB: false, outputURL: &roughnessURL, mapType: "Roughness map", assetName: name), wrapMode: .repeat)

        metallic = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .metallic), isSRGB: false, outputURL: &metallicURL, mapType: "Metallic map", assetName: name), wrapMode: .repeat)

        baseColorValue = mdlMaterial.property(with: .baseColor)?.float4Value ?? baseColorValue
        roughnessValue = mdlMaterial.property(with: .roughness)?.floatValue ?? roughnessValue
        metallicValue = mdlMaterial.property(with: .metallic)?.floatValue ?? metallicValue

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

struct TextureLoader {
    let device: MTLDevice

    fileprivate func textureViewMatchingSRGB(_ tex: MTLTexture, wantSRGB: Bool) -> MTLTexture {
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

    func loadTexture(from property: MDLMaterialProperty?,
                     isSRGB: Bool,
                     outputURL: inout URL?,
                     mapType _: String,
                     assetName _: String) -> MTLTexture?
    {
        guard let property else { return nil }

        let loader = MTKTextureLoader(device: device)

        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: isSRGB,
            .generateMipmaps: true,
            .origin: MTKTextureLoader.Origin.topLeft, // matches MDL byte layout
        ]

        // 1) Prefer the sampler path (works for USDZ-embedded textures)
        if let sampler = property.textureSamplerValue,
           let mdlTex = sampler.texture
        {
            do {
                let tex = try loader.newTexture(texture: mdlTex, options: options)

                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                return texView
            } catch {
                handleError(.textureFailedLoading)
            }
        }

        // URL (absolute or resolved by USD/MDL)
        if let url = property.urlValue {
            if let tex = try? loader.newTexture(URL: url, options: options) {
                outputURL = url
                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                return texView
            }
        }

        // String (relative) -> try to resolve against the model’s base path if you keep it
        if let str = property.stringValue, !str.isEmpty {
            // 1) Try as-is (absolute or already-resolved)
            if let url = URL(string: str), url.isFileURL {
                if let tex = try? loader.newTexture(URL: url, options: options) {
                    outputURL = url
                    let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                    return texView
                }
            }
            // 2) Try against known asset base
            if let base = assetBasePath {
                let candidate = base.appendingPathComponent(str)
                if FileManager.default.fileExists(atPath: candidate.path),
                   let tex = try? loader.newTexture(URL: candidate, options: options)
                {
                    outputURL = candidate
                    let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                    return texView
                }
            }
            // 3) Try resources bundle lookup by filename
            let name = URL(fileURLWithPath: str).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: str).pathExtension
            if let url = getResourceURL(resourceName: name, ext: ext.isEmpty ? "png" : ext, subName: nil),
               let tex = try? loader.newTexture(URL: url, options: options)
            {
                outputURL = url
                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                return texView
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
        let tex = renderInfo.device.makeTexture(descriptor: desc)!

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
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge
    samplerDescriptor.tAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge

    let sampler = device.makeSamplerState(descriptor: samplerDescriptor)

    return TextureDescriptor(texture: texture, sampler: sampler, wrapMode: wrapMode)
}
