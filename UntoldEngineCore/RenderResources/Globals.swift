//
//  Globals.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import MetalKit
import simd


var voxelCount:Int=0
let numOfVerticesPerBlock:Int=24
let numOfIndicesPerBlock:Int=36
let sizeOfChunk:Int=32
let sizeOfChunkHalf:Int=sizeOfChunk/2
let maxNumberOfBlocks:Int=sizeOfChunk*sizeOfChunk*sizeOfChunk

//Memory Pool
var vertexMemoryPool:MemoryPoolManager!
var normalMemoryPool:MemoryPoolManager!
var indicesMemoryPool:MemoryPoolManager!
var colorMemoryPool:MemoryPoolManager!
var roughnessMemoryPool:MemoryPoolManager!
var metallicMemoryPool:MemoryPoolManager!

let memoryPoolBlockSize:Int=512

var camera:Camera!
var renderInfo=RenderInfo()
var controller=Controller()

var lightingSystem:LightingSystem!

var coreBufferResources=CoreBufferResources()

var coreTextureResources=CoreTextureResources()

var voxelPool=VoxelsMemoryPool()

//pipelines
var gridPipeline=RenderPipeline()
var voxelPipeline=RenderPipeline()
var compositePipeline=RenderPipeline()
var shadowPipeline=RenderPipeline()
var debuggerPipeline=RenderPipeline()
var postProcessPipeline=RenderPipeline()

//Timing properties
var timeSinceLastUpdatePreviousTime:TimeInterval!;
var timeSinceLastUpdate:TimeInterval!;
var firstUpdateCall:Bool=false;

var frameCount:Int=0;
var timePassedSinceLastFrame:Float=0.0;

let V0:simd_float3=simd_float3(-1.0,-1.0,1.0)
let V1:simd_float3=simd_float3(1.0,-1.0,1.0)
let V2:simd_float3=simd_float3(1.0,1.0,1.0)
let V3:simd_float3=simd_float3(-1.0,1.0,1.0)

let V4:simd_float3=simd_float3(-1.0,-1.0,-1.0)
let V5:simd_float3=simd_float3(1.0,-1.0,-1.0)
let V6:simd_float3=simd_float3(1.0,1.0,-1.0)
let V7:simd_float3=simd_float3(-1.0,1.0,-1.0)

let v0:simd_float3=V0
let v20:simd_float3=V0
let v19:simd_float3=V0


let v1:simd_float3=V1
let v4:simd_float3=V1
let v16:simd_float3=V1

let v2:simd_float3=V2
let v7:simd_float3=V2
let v8:simd_float3=V2

let v3:simd_float3=V3
let v11:simd_float3=V3
let v23:simd_float3=V3

let v15:simd_float3=V4
let v18:simd_float3=V4
let v21:simd_float3=V4

let v5:simd_float3=V5
let v12:simd_float3=V5
let v17:simd_float3=V5

let v6:simd_float3=V6
let v9:simd_float3=V6
let v13:simd_float3=V6

let v10:simd_float3=V7
let v14:simd_float3=V7
let v22:simd_float3=V7

let N0:simd_float3=simd_float3(0,0,1) //front
let N1:simd_float3=simd_float3(1,0,0) //right
let N2:simd_float3=simd_float3(0,1,0) //top
let N3:simd_float3=simd_float3(0,0,-1) //back

let N4:simd_float3=simd_float3(-1,0,0) //left
let N5:simd_float3=simd_float3(0,-1,0) //bottom


var vertices:[simd_float3]=[v0,v1,v2,v3, //front
                            v4,v5,v6,v7, //right
                            v8,v9,v10,v11, //top
                            v12,v13,v14,v15, //back
                            v20,v21,v22,v23, //left
                            v16,v17,v18,v19] //bottom

var normals:[simd_float3]=[N0,N0,N0,N0, //front
                           N1,N1,N1,N1, //right
                           N2,N2,N2,N2, //top
                           N3,N3,N3,N3, //back
                           N4,N4,N4,N4, //left
                           N5,N5,N5,N5]  //bottom

var indices:[UInt16]=[0,1,2,0,2,3, //front
                      4,5,6,4,6,7, //right
                      8,9,10,8,10,11, //top
                      15,14,13,15,13,12, //back
                      20,23,22,20,22,21, //left
                      19,18,17,19,17,16] //bottom face

let gridVertices:[simd_float3]=[simd_float3(1.0,1.0,0.0),
                        simd_float3(-1.0,-1.0,0.0),
                        simd_float3(-1.0,1.0,0.0),
                        simd_float3(-1.0,-1.0,0.0),
                        simd_float3(1.0,1.0,0.0),
                        simd_float3(1.0,-1.0,0.0)]

let quadVertices:[simd_float3]=[simd_float3(-1.0, 1.0, 0.0),
                                simd_float3(-1.0, -1.0, 0.0),
                                simd_float3(1.0, -1.0, 0.0),
                                simd_float3(1.0, 1.0, 0.0)]

let quadTexCoords:[simd_float2]=[simd_float2(0.0, 0.0),
                                 simd_float2(0.0, 1.0),
                                 simd_float2(1.0, 1.0),
                                 simd_float2(1.0, 0.0)]

let quadIndices:[UInt16]=[
    0, 1, 3, // First Triangle
    3, 1, 2  // Second Triangle
]

//var zeroVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: numOfVerticesPerBlock)

//Asset ID
typealias EntityID=UInt64
typealias EntityIndex=UInt32
typealias EntityVersion=UInt32

var s_componentCounter=0

let MAX_COMPONENTS = 64
let MAX_ENTITIES=10


var scene:Scene=Scene()
typealias AssetID=UInt64

struct AssetData{
    var assetId:AssetID!
    var name:String!
    var entityDataSize:Int!
    var indexCount:Int!
    var indexOffset:Int!
    
}

struct VoxelData: Codable{ //codable means it can be encoded and decoded to/from json format
    var guid:UInt
    var rawOrigin:simd_float3=simd_float3(0.0,0.0,0.0)
    var color:simd_float3
    var material:simd_float3
    var scale:Float
}

var assetDataArray:[AssetData]=[]
var entityAssetMap: [EntityID: AssetData] = [:]

var maxNumPointLights:Int=100


var keyState:KeyState=KeyState()

//key codes
let kVK_ANSI_W: UInt16 = 13
let kVK_ANSI_A: UInt16 = 0
let kVK_ANSI_S: UInt16 = 1
let kVK_ANSI_D: UInt16 = 2

let kVK_ANSI_P: UInt16 = 35

var visualDebug:Bool=false
