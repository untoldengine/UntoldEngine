
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
    guard let t = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        return
    }

    let position = simd_float3(
        t.space.columns.3.x,
        t.space.columns.3.y,
        t.space.columns.3.z
    )

    // update camera position based on target position
    camera.localPosition = position + offset
    camera.updateViewMatrix()
}

public func getKeyFromValue(forValue value: EntityID, in dictionary: [String: EntityID]) -> String? {
    return dictionary.first { $0.value == value }?.key
}

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

func generateHDR(_ hdrName: String, from directory: URL? = nil) {
    do {
        textureResources.environmentTexture = try loadHDR(hdrName, from: directory)
        textureResources.environmentTexture?.label = "environment texture"

        // If the environment was properly loaded, then mip-map it

        guard let envMipMapCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblMipMapCreationFailed)
            return
        }

        guard
            let envMipMapBlitEncoder: MTLBlitCommandEncoder =
            envMipMapCommandBuffer.makeBlitCommandEncoder()
        else {
            handleError(.iblMipMapBlitCreationFailed)
            return
        }

        envMipMapBlitEncoder.generateMipmaps(for: textureResources.environmentTexture!)

        // add a completion handler here
        envMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) in
        }

        envMipMapBlitEncoder.endEncoding()
        envMipMapCommandBuffer.commit()
        envMipMapCommandBuffer.waitUntilCompleted()

        // execute the ibl pre-filter
        guard
            let iblPreFilterCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblPreFilterCreationFailed)
            return
        }

        executeIBLPreFilterPass(
            uCommandBuffer: iblPreFilterCommandBuffer, textureResources.environmentTexture!
        )

        // add a completion handler here
        iblPreFilterCommandBuffer.addCompletedHandler { (_ commandBuffer) in
        }

        iblPreFilterCommandBuffer.commit()
        iblPreFilterCommandBuffer.waitUntilCompleted()

        // mipmap the specular texture

        guard
            let specMipMapCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblSpecMipMapCreationFailed)
            return
        }

        guard
            let specMipMapBlitEncoder: MTLBlitCommandEncoder =
            specMipMapCommandBuffer.makeBlitCommandEncoder()
        else {
            handleError(.iblSpecMipMapBlitCreationFailed)
            return
        }

        specMipMapBlitEncoder.generateMipmaps(for: textureResources.specularMap!)

        // add a completion handler here
        specMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) in

            iblSuccessful = true
            // print("IBL Pre-Filters created successfully")
        }

        specMipMapBlitEncoder.endEncoding()
        specMipMapCommandBuffer.commit()
        specMipMapCommandBuffer.waitUntilCompleted()

    } catch {
        handleError(.iBLCreationFailed)
    }
}

func updateBoundingBoxBuffer(min: SIMD3<Float>, max: SIMD3<Float>) {
    let vertices: [SIMD4<Float>] = [
        // Bottom face
        SIMD4(min.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, min.z, 1.0),
        SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, max.z, 1.0),
        SIMD4(max.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, max.z, 1.0),
        SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, min.z, 1.0),

        // Top face
        SIMD4(min.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
        SIMD4(max.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
        SIMD4(max.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
        SIMD4(min.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),

        // Vertical edges
        SIMD4(min.x, min.y, min.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),
        SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
        SIMD4(max.x, min.y, max.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
        SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
    ]

    let bufferPointer = bufferResources.boundingBoxBuffer?.contents()
    bufferPointer!.copyMemory(
        from: vertices, byteCount: vertices.count * MemoryLayout<SIMD4<Float>>.stride
    )
}

func isValid(_ vector: SIMD3<Float>) -> Bool {
    return !vector.x.isNaN && !vector.y.isNaN && !vector.z.isNaN
}

func isValid(_ value: Float) -> Bool {
    return !value.isNaN
}

func getEntityName(entityId: EntityID) -> String? {
    return entityDictionary[entityId]
}

public func lerp(start: simd_float3, end: simd_float3, t: Float) -> simd_float3 {
    return start * (1.0 - t) + end * t
}
