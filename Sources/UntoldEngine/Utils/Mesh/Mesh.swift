
/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A struct that contains data useful for loading assets.
 */

import Foundation
import MetalKit
import simd

// MARK: - Mesh

// App specific mesh struct containing vertex data describing the mesh and submesh object describing
//   how to draw parts of the mesh
struct Mesh {
    // A MetalKit mesh containing vertex buffers describing the shape of the mesh
    let metalKitMesh: MTKMesh

    var submeshes: [SubMesh]

    var modelMDLMesh: MDLMesh!

    var localSpace: simd_float4x4!

    var minBox: simd_float3 = .init(0.0, 0.0, 0.0)
    var maxBox: simd_float3 = .init(0.0, 0.0, 0.0)

    var width: Float = 1.0
    var height: Float = 1.0
    var depth: Float = 1.0

    var name: String!

    init(metalKitMesh: MTKMesh) {
        self.metalKitMesh = metalKitMesh

        var submeshes = [SubMesh]()
        for metalKitSubMesh in metalKitMesh.submeshes {
            submeshes.append(SubMesh(metalKitSubmesh: metalKitSubMesh))
        }
        self.submeshes = submeshes
    }

    init(metalKitMesh: MTKMesh, submeshes: [SubMesh]? = nil) {
        self.metalKitMesh = metalKitMesh
        if let submeshes = submeshes {
            self.submeshes = submeshes
        } else {
            var computedSubmeshes = [SubMesh]()
            for metalKitSubMesh in metalKitMesh.submeshes {
                computedSubmeshes.append(SubMesh(metalKitSubmesh: metalKitSubMesh))
            }
            self.submeshes = computedSubmeshes
        }
    }

    init(
        modelIOMesh: MDLMesh,
        vertexDescriptor: MDLVertexDescriptor,
        textureLoader: MTKTextureLoader,
        device: MTLDevice
    ) {
        // store the mdlmesh for later use
        modelMDLMesh = modelIOMesh

        var blenderTransform: simd_float4x4 = matrix4x4Rotation(
            radians: -.pi / 2.0, axis: simd_float3(1.0, 0.0, 0.0)
        )

        modelIOMesh.parent?.transform?.matrix = simd_mul(
            blenderTransform, (modelIOMesh.parent?.transform!.matrix)!
        )

        // set local matrix
        localSpace = modelIOMesh.parent?.transform?.matrix

        // set name
        name = modelIOMesh.parent?.name

        // set the min/max bounding box
        let minBounds = vector_float3(Float.infinity, Float.infinity, Float.infinity)
        let maxBounds = vector_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        let boundingBox = modelIOMesh.boundingBox

        minBox.x = min(minBounds.x, boundingBox.minBounds.x)
        minBox.y = min(minBounds.y, boundingBox.minBounds.y)
        minBox.z = min(minBounds.z, boundingBox.minBounds.z)

        maxBox.x = max(maxBounds.x, boundingBox.maxBounds.x)
        maxBox.y = max(maxBounds.y, boundingBox.maxBounds.y)
        maxBox.z = max(maxBounds.z, boundingBox.maxBounds.z)

        // set width, height and depth
        width = maxBox.x - minBox.x
        height = maxBox.y - minBox.y
        depth = maxBox.z - minBox.z

        // Have ModelIO create the tangents from mesh texture coordinates and normals
        if hasTextureCoordinates(mesh: modelIOMesh) {
            modelIOMesh.addOrthTanBasis(
                forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                normalAttributeNamed: MDLVertexAttributeNormal,
                tangentAttributeNamed: MDLVertexAttributeTangent
            )
        }

        // Apply the ModelIO vertex descriptor that the renderer created to match the Metal vertex descriptor.

        // Assigning a new vertex descriptor to a ModelIO mesh performs a re-layout of the vertex
        // vertex data.  In this case, rthe renderer created the ModelIO vertex descriptor so that the
        // layout of the vertices in the ModelIO mesh match the layout of vertices the Metal render
        // pipeline expects as input into its vertex shader

        // Note ModelIO must create tangents and bitangents (as done above) before this relayout occur
        // This is because Model IO's addTangentBasis methods only works with vertex data is all in
        // 32-bit floating-point.  The vertex descriptor applied, changes those floats into 16-bit
        // floats or other types from which ModelIO cannot produce tangents
        modelIOMesh.vertexDescriptor = vertexDescriptor

        // Create the metalKit mesh which will contain the Metal buffer(s) with the mesh's vertex data
        //   and submeshes with info to draw the mesh
        do {
            let metalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
            // There should always be the same number of MetalKit submeshes in the MetalKit mesh as there
            //   are Model IO submeshes in the Model IO mesh
            assert(metalKitMesh.submeshes.count == modelIOMesh.submeshes?.count)
            self.metalKitMesh = metalKitMesh
        } catch {
            fatalError("Failed to create MTKMesh from MDLMesh: \(error.localizedDescription)")
        }

        // Create an array to hold this AAPLMesh object's AAPLSubmesh objects

        var submeshes = [SubMesh]()

        for index in 0 ..< metalKitMesh.submeshes.count {
            if let modelIOSubmesh = modelIOMesh.submeshes?.object(at: index) as? MDLSubmesh {
                let subMesh = SubMesh(
                    modelIOSubmesh: modelIOSubmesh,
                    metalKitSubmesh: metalKitMesh.submeshes[index],
                    textureLoader: textureLoader
                )
                submeshes.append(subMesh)
            }
        }

        self.submeshes = submeshes
    }

    // Constructs an array of meshes from the provided file URL, which indicate the location of a model
    //  file in a format supported by Model I/O, such as OBJ, ABC, or USD.  mdlVertexDescriptor defines
    //  the layout ModelIO will use to arrange the vertex data while the bufferAllocator supplies
    //  allocations of Metal buffers to store vertex and index data
    static func loadMeshes(
        url: URL,
        vertexDescriptor: MDLVertexDescriptor,
        device: MTLDevice
    ) -> [Mesh] {
        // Create a MetalKit mesh buffer allocator so that ModelIO  will load mesh data directly into
        // Metal buffers accessible by the GPU
        let bufferAllocator = MTKMeshBufferAllocator(device: device)

        // Use ModelIO  to load the model file at the URL.  This returns a ModelIO  asset object, which
        // contains a hierarchy of ModelIO objects composing a "scene" described by the model file.
        // This hierarchy may include lights, cameras, but, most importantly, mesh and submesh data
        // that we'll render with Metal
        let asset = MDLAsset(url: url, vertexDescriptor: nil, bufferAllocator: bufferAllocator)

        // Create a MetalKit texture loader to load material textures from files or the asset catalog
        //   into Metal textures
        let textureLoader = MTKTextureLoader(device: device)

        var meshes = [Mesh]()

        // Traverse the ModelIO asset hierarchy to find ModelIO meshes and create app-specific
        // AAPLMesh objects from those ModelIO meshes
        for child in asset.childObjects(of: MDLObject.self) {
            let assetMeshes = makeMeshes(
                object: child, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader,
                device: device
            )
            meshes.append(contentsOf: assetMeshes)
        }

        return meshes
    }

    static func makeMeshes(
        object: MDLObject,
        vertexDescriptor: MDLVertexDescriptor,
        textureLoader: MTKTextureLoader,
        device: MTLDevice
    ) -> [Mesh] {
        var meshes = [Mesh]()

        // If this ModelIO  object is a mesh object (not a camera, light, or something else)...
        // ...create an app-specific Mesh object from it
        if let mesh = object as? MDLMesh {
            let newMesh = Mesh(
                modelIOMesh: mesh,
                vertexDescriptor: vertexDescriptor,
                textureLoader: textureLoader,
                device: device
            )
            meshes.append(newMesh)
        }

        // Recursively traverse the ModelIO  asset hierarchy to find ModelIO  meshes that are children
        // of this ModelIO  object and create app-specific AAPLMesh objects from those ModelIO meshes
        if object.conforms(to: MDLObjectContainerComponent.self) {
            for child in object.children.objects {
                let childMeshes = makeMeshes(
                    object: child, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader,
                    device: device
                )
                meshes.append(contentsOf: childMeshes)
            }
        }

        return meshes
    }
}
