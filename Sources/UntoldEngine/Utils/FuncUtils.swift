
//
//  FuncUtils.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CoreGraphics
import Foundation
import MetalKit
import simd
import UniformTypeIdentifiers

enum LoadError: Error {
    case urlCreationFailed(String)
    case imageSourceCreationFailed
    case cgImageCreationFailed
    case colorSpaceCreationFailed
    case bitmapContextCreationFailed
    case textureCreationFailed
}

struct LoadedHDRTextures {
    let visible: MTLTexture
    let iblSource: MTLTexture
}

private enum HDRIBLCalibration {
    static let targetLogAverageLuminance: Float = 0.35
    static let outlierPercentile: Float = 0.999
    static let outlierMultiplier: Float = 4.0
    static let maxFiniteRadiance: Float = 65504.0
    static let maxNormalizedRadiance: Float = 16.0
    static let minExposureScale: Float = 0.01
    static let maxExposureScale: Float = 8.0
}

private func makeHDRTexture(width: Int, height: Int, label: String) throws -> MTLTexture {
    let descriptor = MTLTextureDescriptor()
    descriptor.pixelFormat = .rgba16Float
    descriptor.width = width
    descriptor.height = height
    descriptor.depth = 1
    descriptor.usage = .shaderRead
    descriptor.resourceOptions = .storageModeShared
    descriptor.sampleCount = 1
    descriptor.textureType = .type2D
    descriptor.mipmapLevelCount = Int(
        1 + floorf(log2f(fmaxf(Float(width), Float(height))))
    )

    guard let texture = renderInfo.device.makeTexture(descriptor: descriptor) else {
        throw LoadError.textureCreationFailed
    }
    texture.label = label
    return texture
}

private func sanitizedRadiance(_ value: Float16) -> Float {
    let radiance = Float(value)
    guard radiance.isFinite else { return 0.0 }
    return min(max(radiance, 0.0), HDRIBLCalibration.maxFiniteRadiance)
}

private func luminance(_ color: SIMD3<Float>) -> Float {
    dot(color, SIMD3<Float>(0.2126, 0.7152, 0.0722))
}

private func calibratedIBLHalfData(from halfBits: UnsafeMutablePointer<UInt16>, pixelCount: Int) -> [Float16] {
    let epsilon: Float = 1.0e-4
    var colors: [SIMD3<Float>] = []
    colors.reserveCapacity(pixelCount)
    var luminances: [Float] = []
    luminances.reserveCapacity(pixelCount)
    var logLuminanceSum: Float = 0.0

    for pixel in 0 ..< pixelCount {
        let base = pixel * 4
        let color = SIMD3<Float>(
            sanitizedRadiance(Float16(bitPattern: halfBits[base])),
            sanitizedRadiance(Float16(bitPattern: halfBits[base + 1])),
            sanitizedRadiance(Float16(bitPattern: halfBits[base + 2]))
        )
        let lum = luminance(color)
        colors.append(color)
        luminances.append(lum)
        logLuminanceSum += log(max(lum, epsilon))
    }

    guard pixelCount > 0 else { return [] }

    luminances.sort()
    let percentileIndex = min(
        max(Int(Float(pixelCount - 1) * HDRIBLCalibration.outlierPercentile), 0),
        pixelCount - 1
    )
    let percentileLuminance = max(luminances[percentileIndex], epsilon)
    let logAverage = max(exp(logLuminanceSum / Float(pixelCount)), epsilon)
    let sourceClipLuminance = max(
        percentileLuminance * HDRIBLCalibration.outlierMultiplier,
        logAverage
    )
    let exposureScale = min(
        max(HDRIBLCalibration.targetLogAverageLuminance / logAverage,
            HDRIBLCalibration.minExposureScale),
        HDRIBLCalibration.maxExposureScale
    )

    var calibrated = Array(repeating: Float16(1.0), count: pixelCount * 4)
    for pixel in 0 ..< pixelCount {
        let base = pixel * 4
        var color = colors[pixel]
        let lum = luminance(color)
        if lum > sourceClipLuminance {
            color *= sourceClipLuminance / lum
        }
        color *= exposureScale
        color = min(color, SIMD3<Float>(repeating: HDRIBLCalibration.maxNormalizedRadiance))

        calibrated[base] = Float16(color.x)
        calibrated[base + 1] = Float16(color.y)
        calibrated[base + 2] = Float16(color.z)
        calibrated[base + 3] = Float16(1.0)
    }

    return calibrated
}

public func loadTexture(
    device: MTLDevice,
    textureName: String,
    isSRGB: Bool = false,
    withExtension: String
) throws -> MTLTexture {
    // Load texture data with optimal parameters for sampling

    let textureLoader = MTKTextureLoader(device: device)

    let textureLoaderOptions = [
        MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue),
        MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        MTKTextureLoader.Option.SRGB: NSNumber(value: isSRGB),
    ]

    guard let url = LoadingSystem.shared.resourceURL(forResource: textureName, withExtension: withExtension, subResource: nil) else {
        throw LoadError.textureCreationFailed
    }

    return try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
}

public func loadImage(_ textureName: String, from directory: URL? = nil) throws -> URL {
    if let directory {
        let fileURL = directory.appendingPathComponent(textureName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        } else {
            throw LoadError.urlCreationFailed(textureName)
        }
    }

    guard let url = Bundle.module.url(forResource: textureName, withExtension: nil) else {
        throw LoadError.urlCreationFailed(textureName)
    }

    return url
}

public func loadHDR(_ textureName: String, from directory: URL? = nil) throws -> MTLTexture? {
    try loadHDRTextures(textureName, from: directory).visible
}

func loadHDRTextures(_ textureName: String, from directory: URL? = nil) throws -> LoadedHDRTextures {
    let url = try loadImage(textureName, from: directory)

    let cfURLString = url.path as CFString
    guard
        let cfURL = CFURLCreateWithFileSystemPath(
            kCFAllocatorDefault, cfURLString, CFURLPathStyle.cfurlposixPathStyle, false
        )
    else {
        throw LoadError.imageSourceCreationFailed
    }

    guard let cgImageSource = CGImageSourceCreateWithURL(cfURL, nil) else {
        throw LoadError.imageSourceCreationFailed
    }
    guard let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
        throw LoadError.cgImageCreationFailed
    }

    guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) else {
        throw LoadError.colorSpaceCreationFailed
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
        throw LoadError.bitmapContextCreationFailed
    }

    bitmapContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))

    // Sanitize the half-float pixels. Radiance RGBE can encode values beyond
    // Float16 range (e.g. the sun disk in "puresky" HDRIs decodes to Inf).
    // A single Inf/NaN poisons mip generation and the IBL pre-filter integral,
    // which turns every IBL-lit object black. Inf -> max finite half (65504),
    // NaN and negatives -> 0.
    let componentCount = cgImage.width * cgImage.height * 4
    let halfBits = bitmapContext.data!.bindMemory(to: UInt16.self, capacity: componentCount)
    let maxFiniteHalf: UInt16 = 0x7BFF // 65504.0
    for i in 0 ..< componentCount {
        let bits = halfBits[i]
        if bits & 0x8000 != 0 {
            halfBits[i] = 0 // negative radiance is invalid
        } else if bits & 0x7C00 == 0x7C00 {
            halfBits[i] = (bits & 0x03FF) == 0 ? maxFiniteHalf : 0 // Inf : NaN
        }
    }

    let visibleTexture = try makeHDRTexture(width: cgImage.width, height: cgImage.height, label: "environment texture")
    let iblSourceTexture = try makeHDRTexture(width: cgImage.width, height: cgImage.height, label: "IBL calibrated environment texture")
    let calibratedData = calibratedIBLHalfData(from: halfBits, pixelCount: cgImage.width * cgImage.height)

    visibleTexture.replace(
        region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height), mipmapLevel: 0,
        withBytes: bitmapContext.data!, bytesPerRow: cgImage.width * 2 * 4
    )

    calibratedData.withUnsafeBytes { bytes in
        iblSourceTexture.replace(
            region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height), mipmapLevel: 0,
            withBytes: bytes.baseAddress!, bytesPerRow: cgImage.width * 2 * 4
        )
    }

    return LoadedHDRTextures(visible: visibleTexture, iblSource: iblSourceTexture)
}

public func readArrayOfStructsFromFile<T: Codable>(filePath: URL) -> [T]? {
    do {
        let jsonData = try Data(contentsOf: filePath)
        let decoder = JSONDecoder()
        return try decoder.decode([T].self, from: jsonData)
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
        return try decoder.decode([T].self, from: jsonData)
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
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        return
    }

    let position = localTransformComponent.position

    guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
        handleError(.noActiveCamera)
        return
    }

    // update camera position based on target position
    cameraComponent.localPosition = position + offset
    updateCameraViewMatrix(entityId: camera)
}

public func getKeyFromValue(forValue value: EntityID, in dictionary: [String: EntityID]) -> String? {
    dictionary.first { $0.value == value }?.key
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

public func generateHDR(_ hdrName: String, from directory: URL? = nil) {
    do {
        let hdrTextures = try loadHDRTextures(hdrName, from: directory)
        textureResources.environmentTexture = hdrTextures.visible
        textureResources.iblEnvironmentTexture = hdrTextures.iblSource

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
        envMipMapBlitEncoder.generateMipmaps(for: textureResources.iblEnvironmentTexture!)

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
            uCommandBuffer: iblPreFilterCommandBuffer, textureResources.iblEnvironmentTexture!
        )

        // add a completion handler here
        iblPreFilterCommandBuffer.addCompletedHandler { (_ commandBuffer) in
        }

        iblPreFilterCommandBuffer.commit()
        iblPreFilterCommandBuffer.waitUntilCompleted()

        iblSuccessful = true
        hdrURL = hdrName

    } catch {
        handleError(.iBLCreationFailed)
        iblSuccessful = false
        return // Early exit to prevent accessing nil texture
    }
}

public func textureToCGImage(texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    guard width > 0, height > 0 else { return nil }
    guard texture.storageMode != .memoryless else { return nil }

    let region = MTLRegionMake2D(0, 0, width, height)

    func makeRGBA8Image(from rgbaData: UnsafeMutableRawPointer, isSRGB: Bool) -> CGImage? {
        let colorSpace = CGColorSpace(name: isSRGB ? CGColorSpace.sRGB : CGColorSpace.linearSRGB)!
        let bitmapInfo: CGBitmapInfo = [
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.order32Big.rawValue),
        ]
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: rgbaData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        return context.makeImage()
    }

    switch texture.pixelFormat {
    case .rgba16Float:
        let bytesPerPixel = 8 // RGBA16F
        let bytesPerRow = width * bytesPerPixel
        let dataSize = bytesPerRow * height
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        defer { rawData.deallocate() }

        texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let bitmapInfo: CGBitmapInfo = [
            .floatComponents,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue),
        ]

        guard let context = CGContext(
            data: rawData,
            width: width,
            height: height,
            bitsPerComponent: 16,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        return context.makeImage()

    case .rgba8Unorm, .rgba8Unorm_srgb:
        let bytesPerRow = width * 4
        let dataSize = bytesPerRow * height
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        defer { rawData.deallocate() }

        texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        return makeRGBA8Image(from: rawData, isSRGB: texture.pixelFormat == .rgba8Unorm_srgb)

    case .bgra8Unorm, .bgra8Unorm_srgb:
        let bytesPerRow = width * 4
        let pixelCount = width * height
        let dataSize = bytesPerRow * height

        let bgraData = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        defer { bgraData.deallocate() }
        texture.getBytes(bgraData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let rgbaData = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        defer { rgbaData.deallocate() }

        for i in 0 ..< pixelCount {
            let s = i * 4
            rgbaData[s + 0] = bgraData[s + 2] // R
            rgbaData[s + 1] = bgraData[s + 1] // G
            rgbaData[s + 2] = bgraData[s + 0] // B
            rgbaData[s + 3] = bgraData[s + 3] // A
        }

        return makeRGBA8Image(from: UnsafeMutableRawPointer(rgbaData), isSRGB: texture.pixelFormat == .bgra8Unorm_srgb)

    case .r8Unorm:
        let bytesPerRow = width
        let dataSize = bytesPerRow * height
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
        defer { rawData.deallocate() }
        texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let context = CGContext(
            data: rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        return context.makeImage()

    case .r16Float:
        let srcBytesPerRow = width * 2
        let dataSize = srcBytesPerRow * height
        let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 2)
        defer { rawData.deallocate() }
        texture.getBytes(rawData, bytesPerRow: srcBytesPerRow, from: region, mipmapLevel: 0)

        let pixelCount = width * height
        let f16Buffer = rawData.bindMemory(to: Float16.self, capacity: pixelCount)
        let uint8Data = UnsafeMutablePointer<UInt8>.allocate(capacity: pixelCount)
        defer { uint8Data.deallocate() }
        for i in 0 ..< pixelCount {
            let v = Float(f16Buffer[i])
            uint8Data[i] = UInt8(max(0, min(255, Int(v * 255.0))))
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let context = CGContext(
            data: uint8Data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        return context.makeImage()

    default:
        return nil
    }
}

public func depthTextureToCGImage(texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    guard width > 0, height > 0 else { return nil }

    // Depth test snapshots currently use Depth32Float.
    guard texture.pixelFormat == .depth32Float else { return nil }

    let bytesPerPixel = MemoryLayout<Float>.stride
    let unalignedBytesPerRow = width * bytesPerPixel
    let alignedBytesPerRow = ((unalignedBytesPerRow + 255) / 256) * 256
    let bytesPerImage = alignedBytesPerRow * height

    guard let commandQueue = renderInfo.commandQueue,
          let readbackBuffer = renderInfo.device.makeBuffer(length: bytesPerImage, options: .storageModeShared),
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let blitEncoder = commandBuffer.makeBlitCommandEncoder()
    else {
        return nil
    }

    blitEncoder.copy(
        from: texture,
        sourceSlice: 0,
        sourceLevel: 0,
        sourceOrigin: MTLOriginMake(0, 0, 0),
        sourceSize: MTLSizeMake(width, height, 1),
        to: readbackBuffer,
        destinationOffset: 0,
        destinationBytesPerRow: alignedBytesPerRow,
        destinationBytesPerImage: bytesPerImage,
        options: .depthFromDepthStencil
    )
    blitEncoder.endEncoding()

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    // Match the shader debug intent: linearize depth and remap to a useful visible range.
    // Invert the result so near geometry appears bright and far/background appears dark.
    let projectionNear = max(near, 0.0001)
    let projectionFar = max(far, projectionNear + 0.0001)
    let sceneNear = max(projectionNear, 0.1)
    let sceneFar = min(projectionFar, 50.0)
    let sceneRange = max(sceneFar - sceneNear, 0.0001)

    func linearizeDepth(_ depth: Float) -> Float {
        projectionNear * projectionFar / (projectionFar + depth * (projectionNear - projectionFar))
    }

    var grayscaleBytes = [UInt8](repeating: 0, count: width * height)
    let floatsPerRow = alignedBytesPerRow / bytesPerPixel
    let depthFloats = readbackBuffer.contents().bindMemory(to: Float.self, capacity: floatsPerRow * height)

    for y in 0 ..< height {
        let rowStart = y * floatsPerRow
        let outRowStart = y * width
        for x in 0 ..< width {
            let rawDepth = depthFloats[rowStart + x]
            let finiteDepth = rawDepth.isFinite ? rawDepth : 1.0
            let linearDepth = linearizeDepth(finiteDepth)
            let normalizedDepth = max(0.0, min(1.0, (linearDepth - sceneNear) / sceneRange))
            let visualDepth = 1.0 - normalizedDepth
            grayscaleBytes[outRowStart + x] = UInt8(max(0, min(255, Int(visualDepth * 255.0))))
        }
    }

    let colorSpace = CGColorSpaceCreateDeviceGray()
    guard let provider = CGDataProvider(data: Data(grayscaleBytes) as CFData) else { return nil }

    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: width,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )
}

public func saveCGImageToDisk(_ image: CGImage, fileName: String, directory: URL = FileManager.default.temporaryDirectory) {
    let url = directory.appendingPathComponent(fileName).appendingPathExtension("png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("Failed to create image destination")
        return
    }

    CGImageDestinationAddImage(destination, image, nil)

    if CGImageDestinationFinalize(destination) {
        print("Saved image to \(url.path)")
    } else {
        print("Failed to save image")
    }
}

public func updateBoundingBoxBuffer(min: SIMD3<Float>, max: SIMD3<Float>) {
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
    !vector.x.isNaN && !vector.y.isNaN && !vector.z.isNaN
}

func isValid(_ value: Float) -> Bool {
    !value.isNaN
}

public func lerp(start: simd_float3, end: simd_float3, t: Float) -> simd_float3 {
    start * (1.0 - t) + end * t
}

public func getDimension(entityId: EntityID) -> (width: Float, height: Float, depth: Float) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return (width: 0, height: 0, depth: 0)
    }

    let x: Float = abs(localTransformComponent.boundingBox.1.x - localTransformComponent.boundingBox.0.x)
    let y: Float = abs(localTransformComponent.boundingBox.1.y - localTransformComponent.boundingBox.0.y)
    let z: Float = abs(localTransformComponent.boundingBox.1.z - localTransformComponent.boundingBox.0.z)

    return (width: x * localTransformComponent.scale.x, height: y * localTransformComponent.scale.y, depth: z * localTransformComponent.scale.z)
}

func quaternionDerivative(q: simd_quatf, omega: simd_float3) -> simd_quatf {
    let omegaQuat = simd_quatf(ix: omega.x, iy: omega.y, iz: omega.z, r: 0.0)
    return 0.5 * q * omegaQuat
}

public func isWASDPressed() -> Bool {
    InputSystem.shared.keyState.aPressed || InputSystem.shared.keyState.wPressed || InputSystem.shared.keyState.sPressed || InputSystem.shared.keyState.dPressed
}

public func generateEntityName(prefix: String = "Entity") -> String {
    "\(prefix)_\(globalEntityCounter)"
}

public func getAllGameEntities() -> [EntityID] {
    var entityList: [EntityID] = []
    let entities: [EntityID] = scene.getAllEntities()

    for entityId in entities {
        // Skip entities that are pending destroy (mask will be nil)
        guard scene.mask(for: entityId) != nil else { continue }

        if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) || hasComponent(entityId: entityId, componentType: GizmoComponent.self) {
            continue
        }
        entityList.append(entityId)
    }

    return entityList
}

public func getAllGameEntitiesWithMeshes() -> [EntityID] {
    var entityList: [EntityID] = []
    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

    for entityId in entities {
        if hasComponent(entityId: entityId, componentType: GizmoComponent.self) {
            continue
        }
        entityList.append(entityId)
    }

    return entityList
}

public func getAssetURLString(entityId: EntityID) -> String? {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return nil
    }

    return renderComponent.assetURL.deletingPathExtension().lastPathComponent
}

public func getAssetURL(entityId: EntityID) -> URL? {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return nil
    }

    return renderComponent.assetURL
}

public func setEntityCastsShadow(entityId: EntityID, _ castsShadow: Bool) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    renderComponent.castsShadow = castsShadow
    RenderPasses.invalidateShadowEntityCache()
}

public func getEntityCastsShadow(entityId: EntityID) -> Bool {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return false
    }

    return renderComponent.castsShadow
}

func hasMaterialSlot(renderComponent: RenderComponent, meshIndex: Int, submeshIndex: Int) -> Bool {
    guard renderComponent.mesh.indices.contains(meshIndex) else { return false }
    return renderComponent.mesh[meshIndex].submeshes.indices.contains(submeshIndex)
}

func getMaterial(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Material? {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          hasMaterialSlot(renderComponent: renderComponent, meshIndex: meshIndex, submeshIndex: submeshIndex)
    else {
        return nil
    }

    return renderComponent.mesh[meshIndex].submeshes[submeshIndex].material
}

@discardableResult
func updateMaterial(
    entityId: EntityID,
    meshIndex: Int = 0,
    submeshIndex: Int = 0,
    mutate: (inout Material) -> Void
) -> Bool {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
          hasMaterialSlot(renderComponent: renderComponent, meshIndex: meshIndex, submeshIndex: submeshIndex),
          var material = renderComponent.mesh[meshIndex].submeshes[submeshIndex].material
    else {
        return false
    }

    mutate(&material)
    renderComponent.mesh[meshIndex].submeshes[submeshIndex].material = material
    return true
}

public func updateMaterialTexture(
    entityId: EntityID,
    textureType: TextureType,
    path: URL,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    let filename = path.deletingPathExtension().lastPathComponent
    let withExtension = path.pathExtension
    let folderName = path.deletingLastPathComponent().lastPathComponent

    updateMaterialTexture(
        entityId: entityId,
        textureType: textureType,
        textureName: filename,
        withExtension: withExtension,
        subResource: folderName,
        meshIndex: meshIndex,
        submeshIndex: submeshIndex
    )
}

public func removeMaterialTexture(
    entityId: EntityID,
    textureType: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    let didUpdate = updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) { updatedMaterial in
        switch textureType {
        case .baseColor:
            updatedMaterial.baseColor.texture = nil
            updatedMaterial.baseColorURL = nil
        // Keep baseColorMDLTexture for restore functionality
        case .roughness:
            updatedMaterial.roughness.texture = nil
            updatedMaterial.roughnessURL = nil
            // Keep roughnessMDLTexture for restore functionality
            updatedMaterial.roughnessValue = 1.0
        case .metallic:
            updatedMaterial.metallic.texture = nil
            updatedMaterial.metallicURL = nil
            // Keep metallicMDLTexture for restore functionality
            updatedMaterial.metallicValue = 0.0
        case .normal:
            updatedMaterial.normal.texture = nil
            updatedMaterial.normalURL = nil
            // Keep normalMDLTexture for restore functionality
        }
    }

    guard didUpdate else { return }

    print("\(textureType) textured updated succesfully.")
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

func updateMaterialTexture(
    entityId: EntityID,
    textureType: TextureType,
    textureName: String,
    withExtension: String,
    subResource: String,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    let textureLoader = MTKTextureLoader(device: renderInfo.device)

    let textureLoaderOptions = [
        MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue),
        MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        MTKTextureLoader.Option.SRGB: NSNumber(value: textureType == .baseColor),
        MTKTextureLoader.Option.generateMipmaps: true,
    ]

    guard let url = LoadingSystem.shared.resourceURL(forResource: textureName, withExtension: withExtension, subResource: subResource) else {
        return
    }

    do {
        let texture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)

        let didUpdate = updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) { updatedMaterial in
            switch textureType {
            case .baseColor:
                updatedMaterial.baseColor.texture = texture
                updatedMaterial.baseColorURL = url
            // Keep baseColorMDLTexture for restore functionality
            case .roughness:
                updatedMaterial.roughness.texture = texture
                updatedMaterial.roughnessURL = url
                // Keep roughnessMDLTexture for restore functionality
                updatedMaterial.roughnessValue = 1.0
            case .metallic:
                updatedMaterial.metallic.texture = texture
                updatedMaterial.metallicURL = url
                // Keep metallicMDLTexture for restore functionality
                updatedMaterial.metallicValue = 1.0
            case .normal:
                updatedMaterial.normal.texture = texture
                updatedMaterial.normalURL = url
                // Keep normalMDLTexture for restore functionality
            }
        }

        guard didUpdate else { return }

        Logger.log(message: "\(textureType) textured updated succesfully.")
        refreshStaticBatchingForMaterialChange(entityId: entityId)
    } catch {
        handleError(.textureFailedLoading)
    }
}

public func getMaterialTextureURL(
    entityId: EntityID,
    type: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) -> URL? {
    let material = getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)

    switch type {
    case .baseColor: return material?.baseColorURL
    case .roughness: return material?.roughnessURL
    case .metallic: return material?.metallicURL
    case .normal: return material?.normalURL
    }
}

/// Helper to check if a URL represents an embedded USDZ texture
public func isEmbeddedUSDZTexture(_ url: URL?) -> Bool {
    guard let url else { return false }
    return url.scheme == "usdz-embedded"
}

/// Helper to get MDLTexture for embedded textures
public func getMaterialMDLTexture(
    entityId: EntityID,
    type: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) -> MDLTexture? {
    let material = getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)

    switch type {
    case .baseColor: return material?.baseColorMDLTexture
    case .roughness: return material?.roughnessMDLTexture
    case .metallic: return material?.metallicMDLTexture
    case .normal: return material?.normalMDLTexture
    }
}

/// Check if an original embedded texture can be restored
public func canRestoreEmbeddedTexture(
    entityId: EntityID,
    type: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) -> Bool {
    getMaterialMDLTexture(entityId: entityId, type: type, meshIndex: meshIndex, submeshIndex: submeshIndex) != nil
}

/// Helper to match sRGB texture format (same logic as in TextureLoader)
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

/// Restore the original embedded texture from USDZ
public func restoreEmbeddedTexture(
    entityId: EntityID,
    textureType: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    guard var material = getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) else { return }

    // Get the stored MDLTexture for this texture type
    let mdlTexture: MDLTexture?
    switch textureType {
    case .baseColor: mdlTexture = material.baseColorMDLTexture
    case .roughness: mdlTexture = material.roughnessMDLTexture
    case .metallic: mdlTexture = material.metallicMDLTexture
    case .normal: mdlTexture = material.normalMDLTexture
    }

    guard let mdlTex = mdlTexture else {
        Logger.log(message: "No embedded texture to restore for \(textureType)")
        return
    }

    // Reload the texture from MDLTexture
    let textureLoader = MTKTextureLoader(device: renderInfo.device)
    let isSRGB = textureType == .baseColor

    let options: [MTKTextureLoader.Option: Any] = [
        .textureUsage: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue,
        .textureStorageMode: MTLStorageMode.private.rawValue,
        .SRGB: isSRGB,
        .generateMipmaps: true,
        .origin: MTKTextureLoader.Origin.topLeft,
    ]

    do {
        let loadedTexture = try textureLoader.newTexture(texture: mdlTex, options: options)

        // Apply sRGB correction (same as in TextureLoader.loadTexture)
        let texture = textureViewMatchingSRGB(loadedTexture, wantSRGB: isSRGB)

        // Regenerate the pseudo-URL
        let assetName = getAssetURLString(entityId: entityId) ?? "unknown"
        let mapType = textureType.displayName
        let textureName = mdlTex.name.isEmpty ? "embedded_\(mapType.replacingOccurrences(of: " ", with: "_"))" : mdlTex.name
        let pseudoURL = URL(string: "usdz-embedded://\(assetName)/\(textureName)")

        // Update the material with restored texture
        switch textureType {
        case .baseColor:
            material.baseColor.texture = texture
            material.baseColorURL = pseudoURL
        case .roughness:
            material.roughness.texture = texture
            material.roughnessURL = pseudoURL
            material.roughnessValue = 1.0
        case .metallic:
            material.metallic.texture = texture
            material.metallicURL = pseudoURL
            material.metallicValue = 1.0
        case .normal:
            material.normal.texture = texture
            material.normalURL = pseudoURL
        }

        guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0 = material }) else {
            return
        }
        Logger.log(message: "\(textureType) texture restored successfully.")
        refreshStaticBatchingForMaterialChange(entityId: entityId)
    } catch {
        Logger.log(message: "Failed to restore \(textureType) texture: \(error)")
        handleError(.textureFailedLoading)
    }
}

public func getMaterialRoughness(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Float {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.roughnessValue ?? .zero
}

public func updateMaterialRoughness(entityId: EntityID, roughness: Float, meshIndex: Int = 0, submeshIndex: Int = 0) {
    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.roughnessValue = roughness }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

public func getMaterialMetallic(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Float {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.metallicValue ?? .zero
}

public func updateMaterialMetallic(entityId: EntityID, metallic: Float, meshIndex: Int = 0, submeshIndex: Int = 0) {
    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.metallicValue = metallic }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

public func getMaterialEmmissive(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> simd_float3 {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.emissiveValue ?? .zero
}

public func updateMaterialEmmisive(
    entityId: EntityID,
    emmissive: simd_float3,
    recursive: Bool = false,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    if recursive {
        for targetEntityId in entityAndDescendantIds(entityId) {
            updateMaterialEmmisive(
                entityId: targetEntityId,
                emmissive: emmissive,
                recursive: false,
                meshIndex: meshIndex,
                submeshIndex: submeshIndex
            )
        }
        return
    }

    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.emissiveValue = emmissive }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

public func getMaterialAlphaMode(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> MaterialAlphaMode {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.alphaMode ?? .opaque
}

public func updateMaterialAlphaMode(entityId: EntityID, mode: MaterialAlphaMode, meshIndex: Int = 0, submeshIndex: Int = 0) {
    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.alphaMode = mode }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

public func getMaterialAlphaCutoff(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Float {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.alphaCutoff ?? 0.5
}

public func updateMaterialAlphaCutoff(entityId: EntityID, cutoff: Float, meshIndex: Int = 0, submeshIndex: Int = 0) {
    let clampedCutoff = max(0.0, min(1.0, cutoff))
    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.alphaCutoff = clampedCutoff }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

public func getMaterialOpacity(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Float {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.baseColorValue.w ?? 1.0
}

public func updateMaterialOpacity(
    entityId: EntityID,
    opacity: Float,
    applyToAllSubmeshes: Bool = true,
    recursive: Bool = false
) {
    if recursive {
        for targetEntityId in entityAndDescendantIds(entityId) {
            updateMaterialOpacity(
                entityId: targetEntityId,
                opacity: opacity,
                applyToAllSubmeshes: applyToAllSubmeshes,
                recursive: false
            )
        }
        return
    }

    let clampedOpacity = max(0.0, min(1.0, opacity))
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    if applyToAllSubmeshes {
        var didAnyUpdate = false

        for meshIndex in renderComponent.mesh.indices {
            for submeshIndex in renderComponent.mesh[meshIndex].submeshes.indices {
                let didUpdate = updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) { material in
                    material.baseColorValue.w = clampedOpacity
                    if clampedOpacity < 0.999 {
                        material.alphaMode = .blend
                    } else if material.alphaMode == .blend, !material.hasBaseMap {
                        material.alphaMode = .opaque
                    }
                }
                didAnyUpdate = didAnyUpdate || didUpdate
            }
        }

        if didAnyUpdate {
            refreshStaticBatchingForMaterialChange(entityId: entityId)
        }
        return
    }

    updateMaterialOpacity(
        entityId: entityId,
        opacity: clampedOpacity,
        meshIndex: 0,
        submeshIndex: 0
    )
}

public func updateMaterialOpacity(
    entityId: EntityID,
    opacity: Float,
    meshIndex: Int,
    submeshIndex: Int
) {
    let clampedOpacity = max(0.0, min(1.0, opacity))
    guard updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { material in
        material.baseColorValue.w = clampedOpacity
        if clampedOpacity < 0.999 {
            material.alphaMode = .blend
        } else if material.alphaMode == .blend, !material.hasBaseMap {
            material.alphaMode = .opaque
        }
    }) else {
        return
    }
    refreshStaticBatchingForMaterialChange(entityId: entityId)
}

private func entityAndDescendantIds(_ entityId: EntityID) -> [EntityID] {
    var entityIds: [EntityID] = [entityId]
    var visited: Set<EntityID> = [entityId]
    var index = 0

    while index < entityIds.count {
        let currentEntityId = entityIds[index]
        index += 1

        guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: currentEntityId) else {
            continue
        }

        for childId in scenegraphComponent.children where visited.insert(childId).inserted {
            entityIds.append(childId)
        }
    }

    return entityIds
}

func makeFloat4Texture(data: [simd_float4],
                       width: Int,
                       height: Int) -> MTLTexture?
{
    guard data.count == width * height else {
        print("Data size does not match texture dimensions.")
        return nil
    }

    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float,
                                                                     width: width,
                                                                     height: height,
                                                                     mipmapped: false)
    textureDescriptor.usage = [.shaderRead]
    textureDescriptor.storageMode = .shared

    guard let texture = renderInfo.device.makeTexture(descriptor: textureDescriptor) else {
        print("Failed to create texture.")
        return nil
    }

    let bytesPerRow = width * MemoryLayout<simd_float4>.stride
    let region = MTLRegionMake2D(0, 0, width, height)

    texture.replace(region: region,
                    mipmapLevel: 0,
                    withBytes: data,
                    bytesPerRow: bytesPerRow)

    return texture
}

func projectToScreenSpace(
    position: simd_float3,
    viewMatrix: simd_float4x4,
    projectionMatrix: simd_float4x4,
    viewportSize: simd_float2
) -> simd_float3 {
    // Convert position to clip space
    let worldPos = simd_float4(position, 1.0)
    let viewPos = simd_mul(viewMatrix, worldPos)
    let clipPos = simd_mul(projectionMatrix, viewPos)

    // Perform perspective divide to get NDC (Normalized Device Coordinates)
    let ndc = clipPos / clipPos.w

    // Convert from NDC [-1, 1] to screen space [0, viewportSize]
    let screenX = (ndc.x * 0.5 + 0.5) * viewportSize.x
    let screenY = (1.0 - (ndc.y * 0.5 + 0.5)) * viewportSize.y // flip Y for screen coords

    return simd_float3(screenX, screenY, ndc.z)
}

public func computeAxisTranslationGizmo(
    axisWorldDir: simd_float3,
    gizmoWorldPosition: simd_float3,
    mouseDelta: simd_float2,
    viewMatrix: simd_float4x4,
    projectionMatrix: simd_float4x4,
    viewportSize: simd_float2,
    sensitivity: Float = 0.01
) -> Float {
    // Project the gizmo origin and end of axis into screen space
    let screenOrigin = projectToScreenSpace(
        position: gizmoWorldPosition,
        viewMatrix: viewMatrix,
        projectionMatrix: projectionMatrix,
        viewportSize: viewportSize
    )

    let screenAxisEnd = projectToScreenSpace(
        position: gizmoWorldPosition + axisWorldDir,
        viewMatrix: viewMatrix,
        projectionMatrix: projectionMatrix,
        viewportSize: viewportSize
    )

    // Compute the 2D screen direction of the axis
    let screenAxisDir = normalize(simd_float2(screenAxisEnd.x - screenOrigin.x, screenAxisEnd.y - screenOrigin.y))

    // Project the mouse movement onto this direction
    let projectedAmount = dot(mouseDelta, screenAxisDir)

    return projectedAmount * sensitivity
}

public func computeRotationAngleFromGizmo(
    axis _: simd_float3,
    gizmoWorldPosition: simd_float3,
    lastMousePos: simd_float2,
    currentMousePos: simd_float2,
    viewMatrix: simd_float4x4,
    projectionMatrix: simd_float4x4,
    viewportSize: simd_float2,
    sensitivity: Float = 0.01
) -> Float {
    // Project gizmo center to screen space
    let screenOrigin = projectToScreenSpace(
        position: gizmoWorldPosition,
        viewMatrix: viewMatrix,
        projectionMatrix: projectionMatrix,
        viewportSize: viewportSize
    )

    // Convert screen-space mouse positions to vectors relative to gizmo center
    let prevVec = normalize(lastMousePos - simd_float2(screenOrigin.x, screenOrigin.y))
    let currVec = normalize(currentMousePos - simd_float2(screenOrigin.x, screenOrigin.y))

    // Compute signed angle between the vectors
    let perpDot = prevVec.x * currVec.y - prevVec.y * currVec.x // 2D cross product
    let dotProd = simd_dot(prevVec, currVec)
    let angle = atan2(perpDot, dotProd)

    return angle * sensitivity // positive = CCW, negative = CW
}

public func applyWorldSpaceScaleDelta(
    entityId: EntityID,
    worldAxis: simd_float3,
    projectedAmount: Float
) {
    guard let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    // Convert world axis into the object's local space
    let worldToLocal = simd_transpose(transformQuaternionToMatrix3x3(q: localTransform.rotation))
    let localAxisUnnormalized = simd_mul(worldToLocal, worldAxis)
    let localAxis = normalize(localAxisUnnormalized)

    // Determine dominant local axis component (x, y, or z)
    let absLocalAxis = simd_abs(localAxisUnnormalized)
    let dominantIndex: Int
    if absLocalAxis.x > absLocalAxis.y, absLocalAxis.x > absLocalAxis.z {
        dominantIndex = 0
    } else if absLocalAxis.y > absLocalAxis.z {
        dominantIndex = 1
    } else {
        dominantIndex = 2
    }

    // Flip projectedAmount if axis points in negative local direction
    let dominantComponent = localAxisUnnormalized[dominantIndex]
    let signCorrection: Float = dominantComponent < 0 ? -1.0 : 1.0
    let signedProjectedAmount = projectedAmount * signCorrection

    // Apply the corrected scale delta
    var scale = localTransform.scale
    scale += localAxis * signedProjectedAmount

    // Clamp to prevent collapse
    scale = simd_max(scale, simd_float3(repeating: 0.01))

    scaleTo(entityId: entityId, scale: scale)
}

func generateSSAOKernel(sampleCount: Int = 64) -> [SIMD3<Float>] {
    var kernel: [SIMD3<Float>] = []

    ssaoKernelSize = sampleCount

    for i in 0 ..< sampleCount {
        var sample = SIMD3<Float>(
            Float.random(in: -1.0 ... 1.0),
            Float.random(in: -1.0 ... 1.0),
            Float.random(in: 0.0 ... 1.0) // hemisphere (positive z)
        )
        sample = simd_normalize(sample)

        // Scale samples to be more densely packed near the origin
        let scale = Float(i) / Float(sampleCount)
        let scaleBias = mix(0.1, 1.0, scale * scale)
        sample *= scaleBias

        kernel.append(sample)
    }

    return kernel
}

/// Helper function for lerp
func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a * (1.0 - t) + b * t
}

func generateSSAONoiseTexture(device: MTLDevice, size: Int = 4) -> MTLTexture? {
    let noiseSize = size * size
    var noiseData: [SIMD3<Float>] = []

    for _ in 0 ..< noiseSize {
        let noise = SIMD3<Float>(
            Float.random(in: -1.0 ... 1.0),
            Float.random(in: -1.0 ... 1.0),
            0.0 // XY plane only
        )
        noiseData.append(simd_normalize(noise))
    }

    // Create texture descriptor
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .rgba32Float,
        width: size,
        height: size,
        mipmapped: false
    )
    textureDescriptor.usage = [.shaderRead]

    guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
        print("Failed to create SSAO noise texture.")
        return nil
    }

    // Fill texture with noise data (padding to RGBA format)
    var texels = [Float](repeating: 0.0, count: noiseSize * 4)
    for i in 0 ..< noiseSize {
        texels[i * 4 + 0] = noiseData[i].x
        texels[i * 4 + 1] = noiseData[i].y
        texels[i * 4 + 2] = noiseData[i].z
        texels[i * 4 + 3] = 0.0 // unused alpha
    }

    texels.withUnsafeBytes { rawPtr in
        texture.replace(
            region: MTLRegionMake2D(0, 0, size, size),
            mipmapLevel: 0,
            withBytes: rawPtr.baseAddress!,
            bytesPerRow: size * MemoryLayout<Float>.size * 4
        )
    }

    texture.label = "SSAO Noise Texture"

    return texture
}

public func getMaterialSTScale(entityId: EntityID, meshIndex: Int = 0, submeshIndex: Int = 0) -> Float {
    getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex)?.stScale ?? 1.0
}

public func updateMaterialSTScale(entityId: EntityID, stScale: Float, meshIndex: Int = 0, submeshIndex: Int = 0) {
    _ = updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex, mutate: { $0.stScale = stScale })
}

public func getTextureWrapMode(
    entityId: EntityID,
    textureType: TextureType,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) -> WrapMode? {
    guard let material = getMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) else { return nil }

    switch textureType {
    case .baseColor:
        return material.baseColor.wrapMode
    case .normal:
        return material.normal.wrapMode
    case .roughness:
        return material.roughness.wrapMode
    case .metallic:
        return material.metallic.wrapMode
    }
}

public func updateTextureSampler(
    entityId: EntityID,
    textureType: TextureType,
    wrapMode: WrapMode,
    meshIndex: Int = 0,
    submeshIndex: Int = 0
) {
    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge
    samplerDescriptor.tAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge

    let sampler = renderInfo.device.makeSamplerState(descriptor: samplerDescriptor)

    _ = updateMaterial(entityId: entityId, meshIndex: meshIndex, submeshIndex: submeshIndex) { material in
        switch textureType {
        case .baseColor:
            material.baseColor.sampler = sampler
            material.baseColor.wrapMode = wrapMode
        case .normal:
            material.normal.sampler = sampler
            material.normal.wrapMode = wrapMode
        case .roughness:
            material.roughness.sampler = sampler
            material.roughness.wrapMode = wrapMode
        case .metallic:
            material.metallic.sampler = sampler
            material.metallic.wrapMode = wrapMode
        }
    }
}

func getTextureType(from filename: String) -> TextureType? {
    let lowercasedName = filename.lowercased()

    if lowercasedName.contains("basecolor") || lowercasedName.contains("albedo") || lowercasedName.contains("color") {
        return .baseColor
    } else if lowercasedName.contains("roughness") {
        return .roughness
    } else if lowercasedName.contains("metallic") {
        return .metallic
    } else if lowercasedName.contains("normalgx") || lowercasedName.contains("normaldx") || lowercasedName.contains("normal") {
        return .normal
    }

    return nil
}

func loadTextureType(entityId: EntityID, assetName: String, path: URL) {
    if entityId == .invalid {
        return
    }

    guard let textureType = getTextureType(from: assetName) else {
        return
    }
    updateMaterialTexture(entityId: entityId, textureType: textureType, path: path)
}

func align(_ n: Int, to alignment: Int) -> Int {
    (n + alignment - 1) & ~(alignment - 1)
}

public func getAlphaForImmersionMode() -> Float {
    switch renderInfo.immersionStyle {
    case .none, .full, .ar:
        return 1.0
    case .mixed:
        return 0.0
    }
}

/// Generate batches for all static entities
public func generateBatches() {
    BatchingSystem.shared.generateBatches()
}

func refreshStaticBatchingForMaterialChange(entityId: EntityID) {
    guard BatchingSystem.shared.isEnabled(),
          scene.get(component: StaticBatchComponent.self, for: entityId) != nil
    else {
        return
    }
    BatchingSystem.shared.notifyEntityMaterialChanged(entityId: entityId)
}

// Clear all batches

public func clearSceneBatches() {
    BatchingSystem.shared.clearBatches()
}

public func enableBatching(_ enabled: Bool) {
    BatchingSystem.shared.setEnabled(enabled)
}

public func isBatchingEnabled() -> Bool {
    BatchingSystem.shared.isEnabled()
}
