
//
//  Globals.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/17/23.
//

import Foundation
import MetalKit
import simd

// Asset ID
public typealias EntityID = UInt64
public typealias EntityIndex = UInt32
public typealias EntityVersion = UInt32

var componentCounter = 0

let MAX_COMPONENTS = 64
let MAX_ENTITIES = 1000

var maxNumPointLights: Int = 100

public var scene: Scene = .init()
public var camera: Camera!
public var inputSystem = InputSystem()
public var lightingSystem: LightingSystem!
var shadowSystem: ShadowSystem!

var renderInfo = RenderInfo()

var vertexDescriptor = VertexDescriptors()
var bufferResources = BufferResources()
var textureResources = TextureResources()

var entityMeshMap: [EntityID: [Mesh]] = [:] // Holds all meshes loaded

var entityNameMap: [String: EntityID] = [:]
var entityDictionary: [EntityID: String] = [:] //links entity Id to names

// Timing properties
var timeSinceLastUpdatePreviousTime: TimeInterval!
public var timeSinceLastUpdate: Float!
var firstUpdateCall: Bool = false

var frameCount: Int = 0
var timePassedSinceLastFrame: Float = 0.0

// Frustum info
let far: Float = 10000
let near: Float = 0.01
let fov: Float = 65.0

// Shadow max parameters
let shadowMaxWidth: Float = 300.0
let shadowMaxHeight: Float = 300.0

@available(macOS 11.0, *)
var accelStructResources = AccelStructResources()

// pipelines
var gridPipeline = RenderPipeline()
var modelPipeline = RenderPipeline()
var compositePipeline = RenderPipeline()
var preCompositePipeline = RenderPipeline()
var shadowPipeline = RenderPipeline()
var debuggerPipeline = RenderPipeline()
var environmentPipeline = RenderPipeline()
var iblPrefilterPipeline = RenderPipeline()
var postProcessPipeline = RenderPipeline()
var lightingPipeline = RenderPipeline()
var tonemappingPipeline = RenderPipeline()
var geometryPipeline = RenderPipeline()
var rayCompositePipeline = RenderPipeline()

var rayTracingPipeline = ComputePipeline()
var rayModelIntersectPipeline = ComputePipeline()
var clearRayTracingPipeline = ComputePipeline()

// Environment Mesh
var environmentMesh: MTKMesh!

// ibl
var iblSuccessful: Bool = false

// let usdRotation:simd_float4x4=matrix4x4Identity()

let gridVertices: [simd_float3] = [
    simd_float3(1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(-1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(1.0, 1.0, 0.0),
    simd_float3(1.0, -1.0, 0.0),
]

let quadVertices: [simd_float3] = [
    simd_float3(-1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(1.0, -1.0, 0.0),
    simd_float3(1.0, 1.0, 0.0),
]

let quadTexCoords: [simd_float2] = [
    simd_float2(0.0, 0.0),
    simd_float2(0.0, 1.0),
    simd_float2(1.0, 1.0),
    simd_float2(1.0, 0.0),
]

let quadIndices: [UInt16] = [
    0, 1, 3, // First Triangle
    3, 1, 2, // Second Triangle
]

enum TextureType {
    case baseColor
    case roughness
    case metallic
    case normal
}

var visualDebug: Bool = false
public var gameMode: Bool = false
var hotReload: Bool = false

var toneMapOperator: Int = 0

var applyIBL: Bool = true
var renderEnvironment: Bool = false
var ambientIntensity: Float = 0.44

// hightlight
let boundingBoxVertexCount = 24
var selectedModel: Bool = false

var envRotationAngle: Float = 0
public var hdrURL: String = "HDR Light Studio Sample - 07.hdr"
public var resourceURL: URL?

var currentGlobalTime: Float = 0.0
