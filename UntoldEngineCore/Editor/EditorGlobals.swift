//
//  EditorGlobals.swift
//  UntoldEditor
//
//  Created by Harold Serrano on 1/30/24.
//

import Foundation
import MetalKit
import simd

//EDITOR
var editorVoxelPool=EditorVoxelPool()
var editorBufferResources=EditorBufferResources()
var editorTextureResources=EditorTextureResources()

var planePipeline=RenderPipeline()
var ghostVoxelPipeline=RenderPipeline()
var environmentPipeline=RenderPipeline()
var voxelRayPipeline=ComputePipeline()
var voxelRemoveAllPipeline=ComputePipeline()
var serializePipeline=ComputePipeline()
var voxelBoxIntersectPipeline=ComputePipeline()
var normalPlaneComputePipeline=ComputePipeline()
var intersectionInfo=IntersectionInfo()
var iblPrefilterPipeline=RenderPipeline()




struct Voxel{

    var size:UInt
    var offset:UInt32
}

struct HighLightBox{
    var origin:simd_float3!
    var halfwidth:simd_float3!
}

enum ActiveState {
    case add
    case remove
    case color
    case roughness
    case metallic
    case none
}

enum SelectionMode{
    case single
    case multipleselectionstart
    case multipleselectionmoving
    case extrude
    case none
}

enum KeyCode: UInt16 {
    case A = 0 //add
    case S = 1 //subtract
    case C = 8 //color
    case U = 32 //undo
    case R = 15 //redo
    //case X = 7 //clear
//    case Q = 12
//    case W = 13
    //case E = 14
}

var environmentMesh:MTKMesh!
var voxelAddition:Bool=true
var voxelRemoving:Bool=false
var voxelAction:ActiveState = .add
var selectionMode:SelectionMode = .single

var enableRayVoxelIntersection:Bool=false
var colorSelected:simd_float3=simd_float3(1.0,0.0,0.0)
var previousColorSelected:simd_float3=simd_float3(1.0,0.0,0.0)
var voxelNeighborOrigin:simd_float3=simd_float3(0.0,0.0,0.0)

var voxelNeighborScale:simd_float3=simd_float3(1.0,1.0,1.0)

var roughnessSelected:Float=0.23
var previousRoughnessSelected:Float=0.23

var metallicSelected:Float=0.0
var previousMetallicSelected:Float=0.0



var rayOrigin:simd_float3!
var rayDirection:simd_float3!





var ghostVoxelVertices:[simd_float3]=[simd_float3(1.0,1.0,1.0)*scale,
                                simd_float3(1.0,1.0,-1.0)*scale,
                                simd_float3(-1.0,1.0,-1.0)*scale,
                                simd_float3(-1.0,1.0,1.0)*scale,
                                simd_float3(1.0,-1.0,1.0)*scale,
                                simd_float3(1.0,-1.0,-1.0)*scale,
                                simd_float3(-1.0,-1.0,-1.0)*scale,
                                simd_float3(-1.0,-1.0,1.0)*scale]

var ghostVoxelIndices:[simd_int4]=[simd_int4(0,1,2,3),
                                 simd_int4(1,2,3,0),
                                 simd_int4(4,5,6,7),
                                 simd_int4(5,6,7,4),
                                 simd_int4(3,2,6,7),
                                 simd_int4(2,6,7,3),
                                 simd_int4(0,4,5,1),
                                 simd_int4(1,0,4,5),
                                 simd_int4(0,3,7,4),
                                 simd_int4(4,0,3,7),
                                 simd_int4(1,5,6,2),
                                 simd_int4(2,1,5,6)]

var planeVertices:[simd_float3]=[simd_float3(0.0*planeScale,0.0,0.0*planeScale),
                                 simd_float3(1.0*planeScale,0.0,0.0*planeScale),
                                 simd_float3(1.0*planeScale,0.0,1.0*planeScale),
                                 simd_float3(0.0*planeScale,0.0,1.0*planeScale)]

var planeIndices:[simd_int4]=[simd_int4(0,1,2,3),
                                 simd_int4(1,2,3,0)]



//Undo stack
//var undoStack=[UserOperation]()
//var redoStack=[UserOperation]()

var undoStack=LimitedStack<UserOperation>(maxSize: 20)
var redoStack=LimitedStack<UserOperation>(maxSize: 20)

var firstVoxelSelection:UInt=0
var lastVoxelSelection:UInt=0

//ibl processing
var iblMipmapped:Bool=false
var iblPreFilterProcessing:Bool=false
var iblPreFilterComplete:Bool=false

//plane extrution
var planeToExtrude:simd_float3=simd_float3(-1,-1,-1)
