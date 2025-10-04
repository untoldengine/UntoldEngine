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
    
    var body: some View {
        UntoldView( renderer: renderer ) {
            Node3D( entityID: rootID, name: "Pivot" ) {
                MeshNode( resource: "redplayer.usdc" ) {
                    MeshNode(resource: "ball.usdc")
                        .materialData(
                            baseColorResource: "Ball Texture_Diffuse.jpg",
                            normalResource: "Ball_Normal_Map.png"
                        )
                        .translateBy(x: 0, y: 0, z: 1)
                }
                .materialData(
                    roughness: 0.5,
                    baseColorResource: "soccer-player-1.png"
                )
                .rotateTo(angle: 0, axis: [.y])
            }
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
