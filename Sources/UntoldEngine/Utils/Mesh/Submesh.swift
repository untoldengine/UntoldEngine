import Foundation
import MetalKit
import simd

struct SubMesh {
    
    // MetalKit submesh containing the primitive type, index buffer, and index count
    let metalKitSubmesh: MTKSubmesh
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
        self.material = Material(mdlMaterial: modelIOSubmesh.material!, textureLoader: textureLoader)
    }
}

