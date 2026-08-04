//
//  RenderExtensionModelSurface.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd

public typealias RenderModelSurfaceEntityBinding = (
    _ encoder: MTLRenderCommandEncoder,
    _ entityId: EntityID,
    _ resources: RenderResourceAccess
) -> Void

public typealias RenderModelSurfaceArgumentBinding = (
    _ arguments: RenderModelSurfaceArgumentEncoder,
    _ entityId: EntityID,
    _ resources: RenderResourceAccess
) -> Void

@available(*, deprecated, message: "Use RenderExtensionModelSurfaceArgument with drawModelSurfaceEntities(..., bindArguments:) instead.")
public enum RenderExtensionModelSurfaceSlot {
    public static let fragmentBuffer0 = 10
    public static let fragmentBuffer1 = 11
    public static let fragmentBuffer2 = 12
    public static let fragmentBuffer3 = 13

    public static let fragmentTexture0 = 10
    public static let fragmentTexture1 = 11
    public static let fragmentTexture2 = 12
    public static let fragmentTexture3 = 13
}

public enum RenderExtensionModelSurfaceArgument {
    public static let argumentBufferIndex = 10

    public static let texture0 = 0
    public static let texture1 = 1
    public static let texture2 = 2
    public static let texture3 = 3
    public static let texture4 = 4
    public static let texture5 = 5
    public static let texture6 = 6
    public static let texture7 = 7

    public static let sampler0 = 8
    public static let sampler1 = 9
    public static let sampler2 = 10
    public static let sampler3 = 11
    public static let sampler4 = 12
    public static let sampler5 = 13
    public static let sampler6 = 14
    public static let sampler7 = 15

    public static let buffer0 = 16
    public static let buffer1 = 17
    public static let buffer2 = 18
    public static let buffer3 = 19
    public static let buffer4 = 20
    public static let buffer5 = 21
    public static let buffer6 = 22
    public static let buffer7 = 23
    public static let buffer8 = 24
    public static let buffer9 = 25
    public static let buffer10 = 26
    public static let buffer11 = 27
    public static let buffer12 = 28
    public static let buffer13 = 29
    public static let buffer14 = 30
    public static let buffer15 = 31
}

public final class RenderModelSurfaceArgumentEncoder {
    private let device: MTLDevice
    private let argumentEncoder: MTLArgumentEncoder
    private let argumentBuffer: MTLBuffer
    private let resourceUsagesByID: [Int: MTLResourceUsage]
    private var indirectResources: [(resource: any MTLResource, usage: MTLResourceUsage)] = []
    fileprivate var retainedResources: [AnyObject] = []

    fileprivate init?(
        device: MTLDevice,
        argumentEncoder: MTLArgumentEncoder,
        argumentDescriptors: [MTLArgumentDescriptor]
    ) {
        guard let argumentBuffer = device.makeBuffer(
            length: argumentEncoder.encodedLength,
            options: .storageModeShared
        ) else {
            Logger.logWarning(message: "[RenderExtension] Failed to allocate model-surface extension argument buffer")
            return nil
        }

        self.device = device
        self.argumentEncoder = argumentEncoder
        self.argumentBuffer = argumentBuffer
        var resourceUsagesByID: [Int: MTLResourceUsage] = [:]
        for descriptor in argumentDescriptors {
            switch descriptor.dataType {
            case .pointer, .texture:
                resourceUsagesByID[descriptor.index] = Self.resourceUsage(for: descriptor.access)
            default:
                continue
            }
        }
        self.resourceUsagesByID = resourceUsagesByID
        argumentEncoder.setArgumentBuffer(argumentBuffer, offset: 0)
        retainedResources.append(argumentBuffer)
    }

    public func setTexture(_ texture: MTLTexture?, id: Int) {
        guard RenderModelSurfaceArgumentEncoder.isTextureID(id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring model-surface extension texture argument outside 0...7: \(id)")
            return
        }
        argumentEncoder.setTexture(texture, index: id)
        if let texture {
            retainIndirectResource(texture, id: id)
        }
    }

    public func setSampler(_ sampler: MTLSamplerState?, id: Int) {
        guard RenderModelSurfaceArgumentEncoder.isSamplerID(id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring model-surface extension sampler argument outside 8...15: \(id)")
            return
        }
        argumentEncoder.setSamplerState(sampler, index: id)
    }

    public func setBuffer(_ buffer: MTLBuffer?, offset: Int = 0, id: Int) {
        guard RenderModelSurfaceArgumentEncoder.isBufferID(id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring model-surface extension buffer argument outside 16...31: \(id)")
            return
        }
        argumentEncoder.setBuffer(buffer, offset: offset, index: id)
        if let buffer {
            retainIndirectResource(buffer, id: id)
        }
    }

    public func setBytes<T>(_ value: inout T, id: Int) {
        guard RenderModelSurfaceArgumentEncoder.isBufferID(id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring model-surface extension bytes argument outside 16...31: \(id)")
            return
        }

        let length = MemoryLayout<T>.stride
        let buffer = withUnsafeBytes(of: &value) { rawValue in
            device.makeBuffer(bytes: rawValue.baseAddress!, length: length, options: .storageModeShared)
        }
        guard let buffer else {
            Logger.logWarning(message: "[RenderExtension] Failed to allocate model-surface extension bytes argument")
            return
        }

        argumentEncoder.setBuffer(buffer, offset: 0, index: id)
        retainIndirectResource(buffer, id: id)
    }

    fileprivate func bind(to renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setFragmentBuffer(
            argumentBuffer,
            offset: 0,
            index: RenderExtensionModelSurfaceArgument.argumentBufferIndex
        )
        for indirectResource in indirectResources {
            renderEncoder.useResource(
                indirectResource.resource,
                usage: indirectResource.usage,
                stages: .fragment
            )
        }
    }

    private func retainIndirectResource(_ resource: any MTLResource, id: Int) {
        retainedResources.append(resource)
        indirectResources.append((
            resource: resource,
            usage: resourceUsagesByID[id] ?? .read
        ))
    }

    private static func resourceUsage(for access: MTLBindingAccess) -> MTLResourceUsage {
        switch access {
        case .readOnly:
            return .read
        case .writeOnly:
            return .write
        case .readWrite:
            return [.read, .write]
        @unknown default:
            return .read
        }
    }

    private static func isTextureID(_ id: Int) -> Bool {
        (RenderExtensionModelSurfaceArgument.texture0 ... RenderExtensionModelSurfaceArgument.texture7).contains(id)
    }

    private static func isSamplerID(_ id: Int) -> Bool {
        (RenderExtensionModelSurfaceArgument.sampler0 ... RenderExtensionModelSurfaceArgument.sampler7).contains(id)
    }

    private static func isBufferID(_ id: Int) -> Bool {
        (RenderExtensionModelSurfaceArgument.buffer0 ... RenderExtensionModelSurfaceArgument.buffer15).contains(id)
    }
}

public extension RenderPassContext {
    func drawModelSurfaceEntities(
        pipeline pipelineType: RenderPipelineType,
        matching componentTypes: [any Component.Type] = [],
        label: String = "Render Extension Model Surface",
        argumentLayoutID: String? = nil,
        bindEntity: RenderModelSurfaceEntityBinding? = nil,
        bindArguments: RenderModelSurfaceArgumentBinding? = nil
    ) {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[pipelineType],
              pipeline.success,
              let pipelineState = pipeline.pipelineState
        else {
            Logger.logWarning(message: "[RenderExtension] Model surface pipeline '\(pipelineType.rawValue)' is not available")
            return
        }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = getEntityComponent(entityId: camera, componentType: CameraComponent.self)
        else {
            handleError(.noActiveCamera)
            return
        }

        guard let descriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        descriptor.colorAttachments[0].loadAction = .load
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.depthAttachment.loadAction = .load
        descriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = label
        renderEncoder.pushDebugGroup(label)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(pipeline.depthState)

        let requiredComponents = modelSurfaceRequiredComponents(componentTypes)
        let visibleEntities = Set(visibleEntityIds)
        let entities = queryEntities(with: requiredComponents)
        let argumentDescriptors = bindArguments == nil ? [] : modelSurfaceExtensionArgumentDescriptors(
            argumentLayoutID: argumentLayoutID
        )
        let argumentEncoder = bindArguments == nil ? nil : renderInfo.device.makeArgumentEncoder(
            arguments: argumentDescriptors
        )
        var retainedArgumentResources: [AnyObject] = []

        for entityId in entities where visibleEntities.contains(entityId) {
            guard shouldDrawModelSurfaceEntity(entityId) else { continue }

            guard let renderComponent = getEntityComponent(entityId: entityId, componentType: RenderComponent.self),
                  renderComponent.isVisible,
                  let worldTransform = getEntityComponent(entityId: entityId, componentType: WorldTransformComponent.self)
            else {
                continue
            }

            bindEntity?(renderEncoder, entityId, resources)
            if let bindArguments, let argumentEncoder {
                let arguments = RenderModelSurfaceArgumentEncoder(
                    device: renderInfo.device,
                    argumentEncoder: argumentEncoder,
                    argumentDescriptors: argumentDescriptors
                )
                if let arguments {
                    bindArguments(arguments, entityId, resources)
                    arguments.bind(to: renderEncoder)
                    retainedArgumentResources.append(contentsOf: arguments.retainedResources)
                }
            }

            drawModelSurfaceMeshes(
                renderComponent.mesh,
                entityId: entityId,
                worldTransform: worldTransform,
                cameraComponent: cameraComponent,
                renderEncoder: renderEncoder
            )
        }

        withExtendedLifetime(retainedArgumentResources) {}
    }
}

private func modelSurfaceExtensionArgumentDescriptors(argumentLayoutID: String?) -> [MTLArgumentDescriptor] {
    if let argumentLayoutID {
        guard let descriptor = RenderExtensionArgumentBufferRegistry.shared.descriptor(argumentLayoutID) else {
            Logger.logWarning(message: "[RenderExtension] Missing model-surface extension argument layout '\(argumentLayoutID)'; using default layout")
            return defaultModelSurfaceExtensionArgumentDescriptors()
        }
        return modelSurfaceExtensionArgumentDescriptors(from: descriptor)
    }

    return defaultModelSurfaceExtensionArgumentDescriptors()
}

private func defaultModelSurfaceExtensionArgumentDescriptors() -> [MTLArgumentDescriptor] {
    var descriptors: [MTLArgumentDescriptor] = []

    for id in RenderExtensionModelSurfaceArgument.texture0 ... RenderExtensionModelSurfaceArgument.texture7 {
        descriptors.append(modelSurfaceExtensionTextureArgumentDescriptor(
            id: id,
            textureType: .type2D,
            access: .readOnly
        ))
    }

    for id in RenderExtensionModelSurfaceArgument.sampler0 ... RenderExtensionModelSurfaceArgument.sampler7 {
        descriptors.append(modelSurfaceExtensionSamplerArgumentDescriptor(id: id))
    }

    for id in RenderExtensionModelSurfaceArgument.buffer0 ... RenderExtensionModelSurfaceArgument.buffer15 {
        descriptors.append(modelSurfaceExtensionBufferArgumentDescriptor(id: id, access: .readOnly))
    }

    return descriptors
}

private func modelSurfaceExtensionArgumentDescriptors(
    from descriptor: RenderExtensionArgumentBufferDescriptor
) -> [MTLArgumentDescriptor] {
    var texturesByID: [Int: RenderExtensionArgumentTexture] = [:]
    var buffersByID: [Int: RenderExtensionArgumentBuffer] = [:]

    for texture in descriptor.textures {
        guard (RenderExtensionModelSurfaceArgument.texture0 ... RenderExtensionModelSurfaceArgument.texture7).contains(texture.id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring texture argument outside model-surface texture range in layout '\(descriptor.id)': \(texture.id)")
            continue
        }
        texturesByID[texture.id] = texture
    }

    for sampler in descriptor.samplers {
        guard (RenderExtensionModelSurfaceArgument.sampler0 ... RenderExtensionModelSurfaceArgument.sampler7).contains(sampler.id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring sampler argument outside model-surface sampler range in layout '\(descriptor.id)': \(sampler.id)")
            continue
        }
    }

    for buffer in descriptor.buffers {
        guard (RenderExtensionModelSurfaceArgument.buffer0 ... RenderExtensionModelSurfaceArgument.buffer15).contains(buffer.id) else {
            Logger.logWarning(message: "[RenderExtension] Ignoring buffer argument outside model-surface buffer range in layout '\(descriptor.id)': \(buffer.id)")
            continue
        }
        buffersByID[buffer.id] = buffer
    }

    // The shader support header exposes one fixed argument-buffer struct. Keep
    // every ABI member in the encoder even when an extension uses only a subset.
    var result: [MTLArgumentDescriptor] = []
    for id in RenderExtensionModelSurfaceArgument.texture0 ... RenderExtensionModelSurfaceArgument.texture7 {
        let texture = texturesByID[id]
        result.append(modelSurfaceExtensionTextureArgumentDescriptor(
            id: id,
            textureType: texture?.textureType ?? .type2D,
            access: texture?.access ?? .readOnly
        ))
    }

    for id in RenderExtensionModelSurfaceArgument.sampler0 ... RenderExtensionModelSurfaceArgument.sampler7 {
        result.append(modelSurfaceExtensionSamplerArgumentDescriptor(id: id))
    }

    for id in RenderExtensionModelSurfaceArgument.buffer0 ... RenderExtensionModelSurfaceArgument.buffer15 {
        result.append(modelSurfaceExtensionBufferArgumentDescriptor(
            id: id,
            access: buffersByID[id]?.access ?? .readOnly
        ))
    }

    return result
}

private func modelSurfaceExtensionTextureArgumentDescriptor(
    id: Int,
    textureType: MTLTextureType,
    access: MTLBindingAccess
) -> MTLArgumentDescriptor {
    let descriptor = MTLArgumentDescriptor()
    descriptor.dataType = .texture
    descriptor.index = id
    descriptor.textureType = textureType
    descriptor.access = access
    return descriptor
}

private func modelSurfaceExtensionSamplerArgumentDescriptor(id: Int) -> MTLArgumentDescriptor {
    let descriptor = MTLArgumentDescriptor()
    descriptor.dataType = .sampler
    descriptor.index = id
    return descriptor
}

private func modelSurfaceExtensionBufferArgumentDescriptor(
    id: Int,
    access: MTLBindingAccess
) -> MTLArgumentDescriptor {
    let descriptor = MTLArgumentDescriptor()
    descriptor.dataType = .pointer
    descriptor.index = id
    descriptor.access = access
    return descriptor
}

private func modelSurfaceRequiredComponents(
    _ componentTypes: [any Component.Type]
) -> [any Component.Type] {
    var result = componentTypes
    var seen = Set(componentTypes.map { ObjectIdentifier($0) })

    for componentType in [RenderComponent.self, WorldTransformComponent.self] as [any Component.Type] {
        let id = ObjectIdentifier(componentType)
        if seen.insert(id).inserted {
            result.append(componentType)
        }
    }

    return result
}

private func shouldDrawModelSurfaceEntity(_ entityId: EntityID) -> Bool {
    if scene.mask(for: entityId) == nil { return false }
    if shouldHideSceneEntity(entityId: entityId) { return false }
    if BatchingSystem.shared.isEnabled(), BatchingSystem.shared.isBatched(entityId: entityId) { return false }
    if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: LightComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) { return false }
    if hasComponent(entityId: entityId, componentType: CameraComponent.self) { return false }
    return true
}

private func drawModelSurfaceMeshes(
    _ meshes: [Mesh],
    entityId: EntityID,
    worldTransform: WorldTransformComponent,
    cameraComponent: CameraComponent,
    renderEncoder: MTLRenderCommandEncoder
) {
    for mesh in meshes {
        guard mesh.metalKitMesh.vertexBuffers.count > Int(modelPassJointWeightsIndex.rawValue) else {
            continue
        }

        var uniforms = Uniforms()
        let modelMatrix = simd_mul(worldTransform.space, mesh.localSpace)
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
        let normalMatrix = upperModelMatrix.inverse.transpose

        uniforms.modelViewMatrix = modelViewMatrix
        uniforms.normalMatrix = normalMatrix
        uniforms.viewMatrix = viewMatrix
        uniforms.modelMatrix = modelMatrix
        uniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        uniforms.projectionMatrix = renderInfo.perspectiveSpace

        renderEncoder.setVertexBytes(
            &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            index: Int(modelPassUniformIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            index: Int(modelPassFragmentUniformIndex.rawValue)
        )

        renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitivesTracked(
                type: submesh.metalKitSubmesh.primitiveType,
                indexCount: submesh.metalKitSubmesh.indexCount,
                indexType: submesh.metalKitSubmesh.indexType,
                indexBuffer: submesh.metalKitSubmesh.indexBuffer.buffer,
                indexBufferOffset: submesh.metalKitSubmesh.indexBuffer.offset,
                category: .other
            )
        }
    }
}
