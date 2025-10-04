//
//  ContentView.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import MetalKit
import simd
import SwiftUI
import UntoldEngine


struct ContentView : View {
    
    init () {
        // Wired stuff. The assets / resources that process in the swift package get copy to a module that has to be
        // reference manually. Bundle.main or Bundle.module cant found the bundle. So I had to specify manually
        LoadingSystem.shared.resourceURLFn = { resourceName, extensionName, subPath in
            if let bundleURL = Bundle.main.url(forResource: "UntoldEngine_SwiftUIDemo", withExtension: "bundle") {
                let url = bundleURL.appendingPathComponent("Contents/Resources/" + resourceName + "." + extensionName)
                if FileManager.default.fileExists(atPath: url.path) {
                    return url
                }
            }
            
            // Fallback to the default function
            return getResourceURL(resourceName: resourceName, ext: extensionName, subName: subPath)
        }
    }
    
    var body: some View {
        SceneBuilderView()
        //TestView()
    }
}

// Scene Builder style to create a scene with hierarchy
struct SceneBuilderView: View {
    @State var playerAngle: Float = 0
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    var rootID: EntityID = createEntity()
    
    var renderer: UntoldRenderer?
    
    init() {
        self.renderer = UntoldRenderer.create()
    }
    
    /// This function demonstrates **declarative scene setup** (similar to SwiftUI).
    /// Instead of imperatively creating entities and then configuring them step by step,
    /// we describe the *final scene structure* using nested `MeshNode` definitions.
    ///
    /// - `UntoldView(renderer:)` acts as the root of the scene, similar to a SwiftUI `View`.
    /// - `MeshNode(resource:entityID:)` declares a mesh (in this case, the player model).
    /// - Child nodes are nested inside parent nodes. For example:
    ///     - The `ball.usdc` mesh is declared *inside* the player node, making it a child.
    /// - Modifiers like `.materialData`, `.translateBy`, and `.rotateTo` are applied
    ///   directly on each node to configure its look and transform:
    ///     - `.materialData` sets textures and surface properties (roughness, base color).
    ///     - `.translateBy` positions an entity relative to its parent.
    ///     - `.rotateTo` sets orientation around an axis.
    ///
    /// The end result:
    /// A player entity (`redplayer.usdc`) with custom textures and roughness,
    /// rotated in the scene, and a ball entity (`ball.usdc`) as its child, translated
    /// slightly forward with its own material data.
    ///
    /// This declarative style is more concise and intuitive than the imperative version,
    /// but may feel unusual if you’ve only worked with APIs like Unity/SceneKit where
    /// you must `createEntity()`, `setParent()`, and `updateMaterial()` manually.
    
    var body: some View {
        // Root container for our 3D scene, similar to a SwiftUI View hierarchy.
        UntoldView( renderer: renderer ) {
            // Create the player mesh from a USD file, assigning it a root entity ID.
            MeshNode( resource: "redplayer.usdc", entityID: rootID ) {
                // Declare a ball mesh as a child of the player node.
                MeshNode(resource: "ball.usdc")
                    // Apply textures to the ball:
                    // - Base color texture (diffuse map)
                    // - Normal map (surface detail)
                    .materialData(
                        baseColorResource: "Ball Texture_Diffuse.jpg",
                        normalResource: "Ball_Normal_Map.png"
                    )
                    // Move the ball slightly forward in the scene (Z axis).
                    .translateBy(x: 0, y: 0, z: 1)
            }
            // Apply material properties to the player mesh:
            // - Roughness controls shininess (0 = mirror, 1 = matte).
            // - Base color texture gives the player's uniform/appearance.
            .materialData(
                roughness: 0.5,
                baseColorResource: "soccer-player-1.png"
            )
            // Rotate the player to face forward along the Y axis.
            .rotateTo(angle: 0, axis: [.y])
        }
        .onReceive(timer) { _ in
            playerAngle += 1
            rotateTo(entityId: rootID, pitch: 0, yaw: playerAngle, roll: 0)
        }
    }
}


// Standard style to create a scene with hierarchy
struct TestView : View
{
    @State var playerAngle: Float = 0
    @State var player = createEntity()
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        SceneView().onInit {
            setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdc", flip: false)
            updateMaterialRoughness(entityId: player, roughness: 0.5)
            updateMaterialTexture(entityId: player, textureType: .baseColor, path: LoadingSystem.shared.resourceURL(forResource: "soccer-player-1", withExtension: "png")!)
            rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))

            let ball = createEntity()
            setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdc", flip: false)
            updateMaterialTexture(entityId: ball, textureType: .baseColor, path: LoadingSystem.shared.resourceURL(forResource: "Ball Texture_Diffuse", withExtension:"jpg")! )
            updateMaterialTexture(entityId: ball, textureType: .normal, path: LoadingSystem.shared.resourceURL( forResource: "Ball_Normal_Map", withExtension:"png")! )
            translateBy(entityId: ball, position: simd_float3(0, 0, 1))
            
            setParent(childId: ball, parentId: player)
        }
        .onReceive(timer) { _ in
            playerAngle += 1
            rotateTo(entityId: player, pitch: 0, yaw: playerAngle, roll: 0)
        }
    }
}
