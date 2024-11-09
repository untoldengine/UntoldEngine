
/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A struct that contains data useful for drawing a submesh.
 */

import MetalKit

struct SubMesh {
    // A MetalKit submesh mesh containing the primitive type, index buffer, and index count
    //   used to draw all or part of its parent AAPLMesh object
    let metalKitSubmesh: MTKSubmesh

    // Material to set in the Metal Render Command Encoder
    //  before drawing the submesh
    var material: Material?

    init(metalKitSubmesh: MTKSubmesh) {
        self.metalKitSubmesh = metalKitSubmesh
    }

    init(
        modelIOSubmesh: MDLSubmesh,
        metalKitSubmesh: MTKSubmesh,
        textureLoader: MTKTextureLoader
    ) {
        self.metalKitSubmesh = metalKitSubmesh

        if let mdlMaterial = modelIOSubmesh.material {
            material = Material(mdlMaterial, textureLoader: textureLoader)
        }
    }
}
