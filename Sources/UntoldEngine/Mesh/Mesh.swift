
import Foundation
import MetalKit
import simd

struct Mesh {
    let metalKitMesh: MTKMesh
    var submeshes: [SubMesh] = []
    var modelMDLMesh: MDLMesh
    var localSpace: simd_float4x4
    var name: String
    var minBox: simd_float3
    var maxBox: simd_float3
    var width: Float
    var height: Float
    var depth: Float
    var flipCoord: Bool = false
    var skin: Skin?

    init(modelIOMesh: MDLMesh, vertexDescriptor: MDLVertexDescriptor, textureLoader: MTKTextureLoader, device: MTLDevice, flip: Bool) {
        modelMDLMesh = modelIOMesh

        // Transform to adjust orientation
        let blenderTransform = matrix4x4Rotation(
            radians: -.pi / 2.0, axis: simd_float3(1.0, 0.0, 0.0)
        )

        if flip == true {
            modelIOMesh.parent?.transform?.matrix = simd_mul(
                blenderTransform, modelIOMesh.parent?.transform?.matrix ?? .identity
            )
            flipCoord = true
        }

        // Set local transform matrix and name
        localSpace = modelIOMesh.parent?.transform?.matrix ?? .identity
        name = modelIOMesh.parent?.name ?? "Unnamed"

        // Set bounding box dimensions
        let boundingBox = modelIOMesh.boundingBox
        minBox = boundingBox.minBounds
        maxBox = boundingBox.maxBounds
        width = maxBox.x - minBox.x
        height = maxBox.y - minBox.y
        depth = maxBox.z - minBox.z

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

        // Create MetalKit mesh
        do {
            metalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
            assert(metalKitMesh.submeshes.count == modelIOMesh.submeshes?.count)
        } catch {
            fatalError("Failed to create MTKMesh: \(error.localizedDescription)")
        }

        // Initialize submeshes
        submeshes = (0 ..< metalKitMesh.submeshes.count).compactMap { index in
            guard let mdlSubmesh = modelIOMesh.submeshes?.object(at: index) as? MDLSubmesh else { return nil }
            return SubMesh(modelIOSubmesh: mdlSubmesh, metalKitSubmesh: metalKitMesh.submeshes[index], textureLoader: textureLoader)
        }
    }

    // Load meshes from a file URL
    static func loadMeshes(
        url: URL,
        vertexDescriptor: MDLVertexDescriptor,
        device: MTLDevice,
        flip: Bool
    ) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        let textureLoader = MTKTextureLoader(device: device)

        return asset.childObjects(of: MDLObject.self).flatMap {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
        }
    }

    // Recursively find and create Mesh objects from ModelIO hierarchy
    static func makeMeshes(
        object: MDLObject,
        vertexDescriptor: MDLVertexDescriptor,
        textureLoader: MTKTextureLoader,
        device: MTLDevice,
        flip: Bool
    ) -> [Mesh] {
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
}
