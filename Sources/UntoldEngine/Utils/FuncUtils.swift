
//
//  FuncUtils.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/24/23.
//

import CoreGraphics
import Foundation
import MetalKit

enum LoadError: Error {
    case urlCreationFailed(String)
    case imageSourceCreationFailed
    case cgImageCreationFailed
    case colorSpaceCreationFailed
    case bitmapContextCreationFailed
    case textureCreationFailed
}

public func loadTexture(
    device: MTLDevice,
    textureName: String,
    isSRGB: Bool = false,
    withExtension: String
) throws -> MTLTexture {
    /// Load texture data with optimal parameters for sampling

    let textureLoader = MTKTextureLoader(device: device)

    let textureLoaderOptions = [
        MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        MTKTextureLoader.Option.SRGB: NSNumber(value: isSRGB)
    ]


    guard let url = getResourceURL(forResource: textureName, withExtension: withExtension, subResource: nil) else{
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
        throw LoadError.textureCreationFailed
    }

    texture.replace(
        region: MTLRegionMake2D(0, 0, cgImage.width, cgImage.height), mipmapLevel: 0,
        withBytes: bitmapContext.data!, bytesPerRow: cgImage.width * 2 * 4
    )

    return texture
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

    guard let cameraComponent = scene.get(component: CameraComponent.self, for: getMainCamera()) else {
        handleError(.noActiveCamera)
        return
    }

    // update camera position based on target position
    cameraComponent.localPosition = position + offset
    updateCameraViewMatrix(entityId: getMainCamera())
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
            hdrURL = hdrName
            // print("IBL Pre-Filters created successfully")
        }

        specMipMapBlitEncoder.endEncoding()
        specMipMapCommandBuffer.commit()
        specMipMapCommandBuffer.waitUntilCompleted()

    } catch {
        handleError(.iBLCreationFailed)
    }
}

public func textureToCGImage(texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    let bytesPerPixel = 8 // 16-bit float per channel (4  channels: RGBA)
    let alignment = 256
    let unalignedBytesPerRow = width * bytesPerPixel
    let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment // align to 256 bytes
    let dataSize = bytesPerRow * height

    // Allocate memory to store pixel data
    let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
    defer { rawData.deallocate() }

    // Copy texture data into the buffer
    let region = MTLRegionMake2D(0, 0, width, height)
    texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

    // Create a CGImage from the raw pixel data
    let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
    let bitmapInfo: CGBitmapInfo = [
        .floatComponents,
        CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
        CGBitmapInfo(rawValue: CGImageByteOrderInfo.order16Little.rawValue),
    ]

    guard let context = CGContext(
        data: rawData,
        width: width,
        height: height,
        bitsPerComponent: 16, // 16 bits per channel
        bytesPerRow: unalignedBytesPerRow, // Use unaligned row size
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else { return nil }

    return context.makeImage()
}

public func depthTextureToCGImage(texture: MTLTexture) -> CGImage? {
    let width = texture.width
    let height = texture.height
    let bytesPerPixel = 4 // 32-bit float
    let alignment = 256
    let unalignedBytesPerRow = width * bytesPerPixel
    let bytesPerRow = ((unalignedBytesPerRow + alignment - 1) / alignment) * alignment
    let dataSize = bytesPerRow * height

    // Allocate memory to store pixel data
    let rawData = UnsafeMutableRawPointer.allocate(byteCount: dataSize, alignment: 1)
    defer { rawData.deallocate() }

    // Copy texture data into the buffer
    let region = MTLRegionMake2D(0, 0, width, height)
    texture.getBytes(rawData, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

    // Convert depth values to grayscale
    var convertedData = [UInt8](repeating: 0, count: width * height)
    let floatData = rawData.bindMemory(to: Float.self, capacity: width * height)

    for i in 0 ..< width * height {
        let depthValue = floatData[i]
        // Normalize depth values to [0, 255] for visualization
        let normalizedValue = UInt8(min(max(depthValue * 255.0, 0.0), 255.0))
        convertedData[i] = normalizedValue
    }

    // Create a grayscale CGImage for depth texture
    guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
          let context = CGContext(
              data: &convertedData,
              width: width,
              height: height,
              bitsPerComponent: 8, // 8 bits per channel for grayscale
              bytesPerRow: width, // 1 byte per pixel
              space: colorSpace,
              bitmapInfo: CGImageAlphaInfo.none.rawValue
          ) else { return nil }

    return context.makeImage()
}

public func saveCGImageToDisk(_ image: CGImage, fileName: String, directory: URL = FileManager.default.temporaryDirectory) {
    let url = directory.appendingPathComponent(fileName).appendingPathExtension("png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
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

    return (width: x, height: y, depth: z)
}

func quaternionDerivative(q: simd_quatf, omega: simd_float3) -> simd_quatf {
    let omegaQuat = simd_quatf(ix: omega.x, iy: omega.y, iz: omega.z, r: 0.0)
    return 0.5 * q * omegaQuat
}

public func isWASDPressed() -> Bool {
    let isPressed: Bool = inputSystem.keyState.aPressed || inputSystem.keyState.wPressed || inputSystem.keyState.sPressed || inputSystem.keyState.dPressed

    return isPressed
}

func generateEntityName() -> String {
    "Entity_\(globalEntityCounter)"
}

public func getAllGameEntities() -> [EntityID] {
    var entityList: [EntityID] = []
    let entities: [EntityID] = scene.getAllEntities()

    for entityId in entities {
        if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) || hasComponent(entityId: entityId, componentType: GizmoComponent.self){
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
        if hasComponent(entityId: entityId, componentType: GizmoComponent.self){
            continue
        }
        entityList.append(entityId)
    }

    return entityList
}

func getAssetURLString(entityId: EntityID) -> String? {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return nil
    }

    return renderComponent.assetURL.deletingPathExtension().lastPathComponent
}

func updateMaterialTexture(entityId: EntityID, textureType: TextureType, path: URL){

    let filename = path.deletingPathExtension().lastPathComponent
    let withExtension = path.pathExtension
    let folderName = path.deletingLastPathComponent().lastPathComponent
                                                    
    updateMaterialTexture(entityId: entityId, textureType: textureType, textureName: filename, withExtension: withExtension, subResource: folderName)

}

func updateMaterialTexture(entityId: EntityID, textureType: TextureType, textureName: String, withExtension: String, subResource: String){
    
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    guard let material = renderComponent.mesh[0].submeshes[0].material else { return }

    let textureLoader = MTKTextureLoader(device: renderInfo.device)

    let textureLoaderOptions = [
        MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
        MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        MTKTextureLoader.Option.SRGB: NSNumber(value: (textureType == .baseColor))
    ]

    guard let url = getResourceURL(forResource: textureName, withExtension: withExtension, subResource: subResource) else{
        return
    }
    
    do {
        let texture = try textureLoader.newTexture(URL: url, options: textureLoaderOptions)
        var updatedMaterial = material
        
        switch textureType{
            case .baseColor:
                updatedMaterial.baseColor = texture
                updatedMaterial.baseColorURL = url
            case .roughness:
                updatedMaterial.roughness = texture
                updatedMaterial.roughnessURL = url
                updatedMaterial.roughnessValue = 1.0
            case .metallic:
                updatedMaterial.metallic = texture
                updatedMaterial.metallicURL = url
                updatedMaterial.metallicValue = 1.0
            case .normal:
                updatedMaterial.normal = texture
                updatedMaterial.normalURL = url
        }
        
        renderComponent.mesh[0].submeshes[0].material = updatedMaterial
        print("\(textureType) textured updated succesfully.")
    } catch {
        handleError(.textureFailedLoading)
    }
    
}

func getMaterialTextureURL(entityId: EntityID, type: TextureType) -> URL? {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return nil
    }

    let material = renderComponent.mesh.first?.submeshes.first?.material

    switch type {
    case .baseColor: return material?.baseColorURL
    case .roughness: return material?.roughnessURL
    case .metallic: return material?.metallicURL
    case .normal: return material?.normalURL
    }
}

func getMaterialRoughness(entityId: EntityID) -> Float {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return .zero
    }

    guard let material = renderComponent.mesh.first?.submeshes.first?.material else {
        return .zero
    }

    return material.roughnessValue
}

func updateMaterialRoughness(entityId: EntityID, roughness: Float) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    guard var material = renderComponent.mesh[0].submeshes[0].material else { return }

    material.roughnessValue = roughness
    renderComponent.mesh[0].submeshes[0].material = material
}

func getMaterialMetallic(entityId: EntityID) -> Float {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return .zero
    }

    guard let material = renderComponent.mesh.first?.submeshes.first?.material else {
        return .zero
    }

    return material.metallicValue
}

func updateMaterialMetallic(entityId: EntityID, metallic: Float) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    guard var material = renderComponent.mesh[0].submeshes[0].material else { return }

    material.metallicValue = metallic
    renderComponent.mesh[0].submeshes[0].material = material
}

func getMaterialEmmissive(entityId: EntityID) -> simd_float3 {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return .zero
    }

    guard let material = renderComponent.mesh.first?.submeshes.first?.material else {
        return .zero
    }

    return material.emissiveValue
}

func updateMaterialEmmisive(entityId: EntityID, emmissive: simd_float3) {
    guard var renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    guard var material = renderComponent.mesh[0].submeshes[0].material else { return }

    material.emissiveValue = emmissive
    renderComponent.mesh[0].submeshes[0].material = material
}

func makeFloat4Texture(data: [simd_float4],
                       width: Int,
                       height: Int) -> MTLTexture? {
    
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


func computeAxisTranslationGizmo(
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

func computeRotationAngleFromGizmo(
    axis: simd_float3,
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
    let perpDot = prevVec.x * currVec.y - prevVec.y * currVec.x  // 2D cross product
    let dotProd = simd_dot(prevVec, currVec)
    let angle = atan2(perpDot, dotProd)

    return angle * sensitivity // positive = CCW, negative = CW
}

