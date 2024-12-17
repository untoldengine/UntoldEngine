
import Foundation
import MetalKit
import simd

struct Mesh {
    let metalKitMesh: MTKMesh
    var submeshes: [SubMesh] = []
    var modelMDLMesh: MDLMesh
    var localSpace: simd_float4x4
    var name: String
    var boundingBox: (min: simd_float3, max: simd_float3)
    var flipCoord: Bool = false
    var skin: Skin?
    var spaceUniform: MTLBuffer!

    init(modelIOMesh: MDLMesh, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip: Bool) {
        modelMDLMesh = modelIOMesh

        // Transform to adjust orientation
        let transform = flip ? matrix4x4Rotation(radians: -.pi / 2.0, axis: [1, 0, 0]) : matrix_identity_float4x4
        modelIOMesh.parent?.transform?.matrix = simd_mul(transform, modelIOMesh.parent?.transform?.matrix ?? .identity)

        flipCoord = flip

        // Set local transform matrix and name
        localSpace = modelIOMesh.parent?.transform?.matrix ?? .identity
        name = modelIOMesh.parent?.name ?? "Unnamed"

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
        let processedSubmeshes: [SubMesh] = modelIOMesh.submeshes?.compactMap { mdlSubmesh in
            guard let mdlSubmesh = mdlSubmesh as? MDLSubmesh else { return nil }
            return SubMesh(
                modelIOSubmesh: mdlSubmesh,
                metalKitSubmesh: localMetalKitMesh.submeshes.first!, // Use localMetalKitMesh instead of self.metalKitMesh
                textureLoader: textureLoader,
                name: name
            )
        } ?? []

        submeshes = processedSubmeshes
    }

    // Load meshes from a file URL
    static func loadMeshes(url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice, flip: Bool) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        let textureLoader = TextureLoader(device: device)

        return asset.childObjects(of: MDLObject.self).flatMap {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
        }
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
}

struct SubMesh {
    let metalKitSubmesh: MTKSubmesh
    var material: Material?

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

struct Material {
    var baseColor: MTLTexture?
    var roughness: MTLTexture?
    var metallic: MTLTexture?
    var normal: MTLTexture?

    // Texture URLs
    var baseColorURL: URL?
    var roughnessURL: URL?
    var metallicURL: URL?
    var normalURL: URL?

    // Default values
    var baseColorValue: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var roughnessValue: Float = 1.0
    var metallicValue: Float = 0.0

    // Disney material properties
    var specular: Float = 0.0
    var specularTint: Float = 0.0
    var subsurface: Float = 0.0
    var anisotropic: Float = 0.0
    var sheen: Float = 0.0
    var sheenTint: Float = 0.0
    var clearCoat: Float = 0.0
    var clearCoatGloss: Float = 0.0
    var ior: Float = 1.5
    var emit: Bool = false
    var interactWithLight: Bool = true

    // Texture presence flags
    var hasNormalMap: Bool { normal != nil }
    var hasBaseMap: Bool { baseColor != nil }
    var hasRoughMap: Bool { roughness != nil }
    var hasMetalMap: Bool { metallic != nil }

    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader, name: String) {
        // Load textures and set URLs
        baseColor = textureLoader.loadTexture(from: mdlMaterial.property(with: .baseColor), isSRGB: true, outputURL: &baseColorURL, mapType: "Basecolor map", assetName: name)
        normal = textureLoader.loadTexture(from: mdlMaterial.property(with: .tangentSpaceNormal), isSRGB: false, outputURL: &normalURL, mapType: "Normal map", assetName: name)
        roughness = textureLoader.loadTexture(from: mdlMaterial.property(with: .roughness), isSRGB: false, outputURL: &roughnessURL, mapType: "Roughness map", assetName: name)
        metallic = textureLoader.loadTexture(from: mdlMaterial.property(with: .metallic), isSRGB: false, outputURL: &metallicURL, mapType: "Metallic map", assetName: name)

        baseColorValue = mdlMaterial.property(with: .baseColor)?.float4Value ?? baseColorValue
        roughnessValue = mdlMaterial.property(with: .roughness)?.floatValue ?? roughnessValue
        metallicValue = mdlMaterial.property(with: .metallic)?.floatValue ?? metallicValue

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

    func loadTexture(from property: MDLMaterialProperty?, isSRGB: Bool, outputURL: inout URL?, mapType: String, assetName: String) -> MTLTexture? {
        guard let url = property?.urlValue else {
            let errorMessage = "\(mapType) for \(assetName)"
            handleError(.textureMissing, errorMessage)
            return nil
        }
        outputURL = url

        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: isSRGB,
        ]
        let loader = MTKTextureLoader(device: device)

        do {
            let texture = try loader.newTexture(URL: url, options: options)
            return texture
        } catch {
            let errorMessage = "\((property?.urlValue!.absoluteString)!) for \(assetName)"
            handleError(.textureFailedLoading, errorMessage)
            return nil
        }
    }

    func loadDefaultColorTexture(color: simd_float4) -> MTLTexture? {
        // Generate a 1x1 texture with a solid color
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm
        descriptor.width = 1
        descriptor.height = 1
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let rawData = [UInt8(color.x * 255), UInt8(color.y * 255), UInt8(color.z * 255), UInt8(color.w * 255)]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: rawData, bytesPerRow: 4)
        return texture
    }
}
