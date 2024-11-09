
//
//  FuncUtils.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/24/23.
//

import CoreGraphics
import Foundation
import MetalKit

enum LoadHDRError: Error {
    case urlCreationFailed(String)
    case imageSourceCreationFailed
    case cgImageCreationFailed
    case colorSpaceCreationFailed
    case bitmapContextCreationFailed
    case textureCreationFailed
}

public func hasComponent<T>(entity: EntityDesc, componentType: T.Type) -> Bool {
    let componentId = getComponentId(for: componentType)

    return entity.mask.test(componentId)
}

public func getResourceURL(forResource resourceName: String, withExtension ext: String) -> URL? {
    // First, check Bundle.module for the resource
    if let url = Bundle.module.url(forResource: resourceName, withExtension: ext) {
        return url
    }

    // If not found in Bundle.module, check Bundle.main
    return Bundle.main.url(forResource: resourceName, withExtension: ext)
}

public func loadTexture(
    device: MTLDevice,
    textureName: String
) throws -> MTLTexture {
    /// Load texture data with optimal parameters for sampling

    let textureLoader = MTKTextureLoader(device: device)

    let textureLoaderOptions = [
        MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
    ]

    var url: URL?

    if let imageURL = Bundle.main.url(forResource: textureName, withExtension: nil) {
        // Use imageURL here
        url = imageURL
    }

    return try textureLoader.newTexture(URL: url!, options: textureLoaderOptions)
}

public func loadImage(_ textureName: String, from directory: URL? = nil) throws -> URL {
    if let directory = directory {
        let fileURL = directory.appendingPathComponent(textureName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            throw LoadHDRError.urlCreationFailed(textureName)
        }
    }

    guard let url = Bundle.module.url(forResource: textureName, withExtension: nil) else {
        throw LoadHDRError.urlCreationFailed(textureName)
    }

    return url
}

public func loadHDR(_ textureName: String, from directory: URL? = nil) throws -> MTLTexture? {
    let url = try loadImage(textureName, from: directory)

    let cfURLString = url.path as CFString
    guard
        let cfURL = CFURLCreateWithFileSystemPath(
            kCFAllocatorDefault, cfURLString, CFURLPathStyle.cfurlposixPathStyle, false
        )
    else {
        throw LoadHDRError.imageSourceCreationFailed
    }

    guard let cgImageSource = CGImageSourceCreateWithURL(cfURL, nil) else {
        throw LoadHDRError.imageSourceCreationFailed
    }
    guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
        throw LoadHDRError.cgImageCreationFailed
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else {
        throw LoadHDRError.colorSpaceCreationFailed
    }
    let bitmapInfo =
        CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGImageByteOrderInfo.order16Little.rawValue
    guard
        let bitmapContext = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.width * 2 * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        )
    else {
        throw LoadHDRError.bitmapContextCreationFailed
    }

    bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .rgba16Float
    descriptor.width = cgImage.width
    descriptor.height = cgImage.height
    descriptor.depth = 1
    descriptor.usage = .shaderRead
    descriptor.resourceOptions = .storageModeShared
    descriptor.sampleCount = 1
    descriptor.textureType = .type2D
    descriptor.mipmapLevelCount = Int(
        1 + floorf(log2f(fmaxf(Float(cgImage.width), Float(cgImage.height)))))

    guard let texture = renderInfo.device.makeTexture(descriptor: descriptor) else {
        throw LoadHDRError.textureCreationFailed
    }

    texture.replace(
        region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height), mipmapLevel: 0,
        withBytes: bitmapContext.data!, bytesPerRow: cgImage.width * 2 * 4
    )

    return texture
}

// public func readBuffer<T>(from metalBuffer: MTLBuffer, dataType: T.Type) -> [T] {
//    let count = metalBuffer.length / MemoryLayout<T>.size
//    let pointer = metalBuffer.contents().bindMemory(to: T.self, capacity: count)
//    return Array(UnsafeBufferPointer(start: pointer, count: count))
// }

public func readBuffer(from metalBuffer: MTLBuffer, count: Int) -> [PointLight] {
    let pointer = metalBuffer.contents().bindMemory(to: PointLight.self, capacity: count)
    return Array(UnsafeBufferPointer(start: pointer, count: count))
}

public func readArrayOfStructsFromFile<T: Codable>(filePath: URL) -> [T]? {
    do {
        let jsonData = try Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        let dataArray = try decoder.decode([T].self, from: jsonData)
        return dataArray
    } catch {
        print("Error reading file: \(error.localizedDescription)")
        return nil
    }
}

public func readArrayOfStructsFromFile<T: Codable>(filePath: String, directoryURL: URL) -> [T]? {
    let fileURL = directoryURL.appendingPathComponent(filePath)

    do {
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        let dataArray = try decoder.decode([T].self, from: jsonData)
        return dataArray
    } catch {
        print("Error reading file: \(error.localizedDescription)")
        return nil
    }
}

public func basicFollow(_ entityId: EntityID, _ offset: simd_float3, _: Float) {
    if gameMode == false {
        return
    }
    // get the transform for the entity
    guard let t = scene.get(component: Transform.self, for: entityId) else {
        return
    }

    let position = simd_float3(
        t.localSpace.columns.3.x,
        t.localSpace.columns.3.y,
        t.localSpace.columns.3.z
    )

    // update camera position based on target position
    camera.localPosition = position + offset
    camera.updateViewMatrix()
}

public func getKeyFromValue(forValue value: EntityID, in dictionary: [String: EntityID]) -> String? {
    return dictionary.first { $0.value == value }?.key
}

func updateTexture(
    mesh: Mesh, forSubMeshAtIndex subMeshIndex: Int, textureType: TextureType,
    withTextureURL url: URL, textureLoader: MTKTextureLoader
) -> Mesh {
    guard subMeshIndex < mesh.submeshes.count else {
        print("SubMesh index is out of range.")
        return mesh // Return the original mesh unchanged if the index is out of range
    }

    var updatedSubMeshes = mesh.submeshes
    var subMesh = updatedSubMeshes[subMeshIndex]

    if let material = subMesh.material {
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: textureType == .baseColor, // Assuming only base color textures are sRGB
        ]

        do {
            let newTexture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
            var updatedMaterial = material

            switch textureType {
            case .baseColor:
                updatedMaterial.baseColor = newTexture
                updatedMaterial.baseColorURL = url
            case .roughness:
                updatedMaterial.roughness = newTexture
                updatedMaterial.roughnessURL = url
            case .metallic:
                updatedMaterial.metallic = newTexture
                updatedMaterial.metallicURL = url
            case .normal:
                updatedMaterial.normal = newTexture
                updatedMaterial.normalURL = url
            }

            subMesh.material = updatedMaterial // Update the subMesh's material
            updatedSubMeshes[subMeshIndex] = subMesh // Update the local copy of submeshes array

            print("\(textureType) texture updated successfully.")
        } catch {
            print("Failed to load texture: \(error)")
        }
    }

    // Construct and return a new Mesh instance with the updated submeshes
    return Mesh(metalKitMesh: mesh.metalKitMesh, submeshes: updatedSubMeshes)
}

// public func makeTexture(from url:URL, textureLoader: MTKTextureLoader) -> MTLTexture {
//
//    var newTexture: MTLTexture?
//
//    let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
//        .textureUsage: MTLTextureUsage.shaderRead.rawValue,
//        .textureStorageMode: MTLStorageMode.private.rawValue
//    ]
//
//    if let texture = try? textureLoader.newTexture(URL: url, options: textureLoaderOptions) {
//        newTexture = texture
//    }
//
//    guard let texture = newTexture else {
//        // Load a default texture or handle the error appropriately
//        handleError(.textureMissing)
//        fatalError("Texture data for material property not found. Attempted to load: \(url)")
//    }
//
//
//    return texture
// }

public func hasTextureCoordinates(mesh: MDLMesh) -> Bool {
    // Access the vertex descriptor of the mesh
    let vertexDescriptor = mesh.vertexDescriptor

    // Iterate through the attributes in the vertex descriptor
    for attribute in vertexDescriptor.attributes {
        if let vertexAttribute = attribute as? MDLVertexAttribute {
            if vertexAttribute.name == MDLVertexAttributeTextureCoordinate {
                return true
            }
        }
    }

    handleError(.textureCoordsMissing, mesh.name)
    // Return false if no texture coordinate attribute was found
    return false
}
