
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

extension EntityID {
    static let invalid: EntityID = .max
}

var componentCounter = 0
var globalEntityCounter: UInt32 = 0
let MAX_COMPONENTS = 64
let MAX_ENTITIES = 1000

var maxNumPointLights: Int = 100
var maxNumSpotLights: Int = 100
var maxAreaLights: Int = 100
public var scene: Scene = .init()
public var inputSystem = InputSystem()
var shadowSystem: ShadowSystem!

var renderInfo = RenderInfo()

var vertexDescriptor = VertexDescriptors()
var bufferResources = BufferResources()
var tripleBufferResources = TripleBufferResources()
var textureResources = TextureResources()

var entityMeshMap: [EntityID: [Mesh]] = [:] // Holds all meshes loaded

var entityNameMap: [EntityID: String] = [:] // links entity Id to names

var reverseEntityNameMap: [String: EntityID] = [:]

// Timing properties
var timeSinceLastUpdatePreviousTime: TimeInterval!
public var timeSinceLastUpdate: Float!
var firstUpdateCall: Bool = false

var frameCount: Int = 0
var timePassedSinceLastFrame: Float = 0.0

// Frustum info
let far: Float = 500
let near: Float = 0.01
let fov: Float = 65.0

// Shadow max parameters
let shadowMaxWidth: Float = 300.0
let shadowMaxHeight: Float = 300.0

let shadowResolution: simd_int2 = .init(8192, 8192)

var accelStructResources = AccelStructResources()

// pipelines
var gridPipeline = RenderPipeline()
var modelPipeline = RenderPipeline()
var lightPipeline = RenderPipeline()
var compositePipeline = RenderPipeline()
var preCompositePipeline = RenderPipeline()
var shadowPipeline = RenderPipeline()
var debuggerPipeline = RenderPipeline()
var environmentPipeline = RenderPipeline()
var iblPrefilterPipeline = RenderPipeline()
var postProcessPipeline = RenderPipeline()
var lightingPipeline = RenderPipeline()
var geometryPipeline = RenderPipeline()
var lightVisualPipeline = RenderPipeline()
var rayCompositePipeline = RenderPipeline()
var hightlightPipeline = RenderPipeline()
// gizmo
var gizmoPipeline = RenderPipeline()

// Post-process
var tonemappingPipeline = RenderPipeline()
var colorGradingPipeline = RenderPipeline()
var colorCorrectionPipeline = RenderPipeline()
var blurPipeline = RenderPipeline()
var bloomThresholdPipeline = RenderPipeline()
var bloomCompositePipeline = RenderPipeline()
var vignettePipeline = RenderPipeline()
var chromaticAberrationPipeline = RenderPipeline()
var depthOfFieldPipeline = RenderPipeline()
var ssaoPipeline = RenderPipeline()
var ssaoBlurPipeline = RenderPipeline()
var outlinePipeline = RenderPipeline()

var rayTracingPipeline = ComputePipeline()
var rayModelIntersectPipeline = ComputePipeline()
var clearRayTracingPipeline = ComputePipeline()
var frustumCullingPipeline = ComputePipeline()
var reduceScanMarkVisiblePipeline = ComputePipeline()
var reduceScanLocalScanPipeline = ComputePipeline()
var reduceScanBlockScanPipeline = ComputePipeline()
var reduceScanScatterCompactedPipeline = ComputePipeline()

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

enum TextureType: String, CaseIterable, Identifiable {
    case baseColor
    case roughness
    case metallic
    case normal

    var id: Self { self } // Satisfies Identifiable conformance

    var displayName: String {
        switch self {
        case .baseColor: return "Base Color"
        case .roughness: return "Roughness"
        case .metallic: return "Metallic"
        case .normal: return "Normal"
        }
    }
}

var visualDebug: Bool = false

#if os(iOS)
public var gameMode: Bool = true
#else
public var gameMode: Bool = false
#endif

var hotReload: Bool = false

var applyIBL: Bool = true
var renderEnvironment: Bool = false
var ambientIntensity: Float = 1.0

// hightlight
let boundingBoxVertexCount = 24

var envRotationAngle: Float = 0
public var hdrURL: String = "teatro_massimo_2k.hdr"
public var resourceURL: URL?

var currentGlobalTime: Float = 0.0

// Visual Debugger
enum DebugSelection: Int {
    case normalOutput
    case iblOutput
}

var currentDebugSelection: DebugSelection = .normalOutput

// Physics system

enum InertiaTensorType: Int {
    case cubic
    case spherical
    case cylindrical
}

// Editor

public var enableEditor: Bool = true
public var assetBasePath: URL?

var activeEntity: EntityID = .invalid
#if os(macOS)
var editorController: EditorController?
#endif
// Transform Manipulation mode
enum TransformManipulationMode {
    case translate
    case rotate
    case scale
    case lightRotate
    case none
}

enum TransformAxis {
    case x, y, z, none
}

// mtk view color
// Graphite Gray
let mtkBackgroundColor = MTLClearColorMake(40.0 / 255.0, 40.0 / 255.0, 45.0 / 255.0, 1.0)

class ToneMappingParams: ObservableObject {
    static let shared = ToneMappingParams()

    @Published var toneMapOperator: Int = 0
    @Published var gamma: Float = 1.0 // original = 2.2
}

class ColorGradingParams: ObservableObject {
    static let shared = ColorGradingParams()

    @Published var brightness: Float = 0.0
    @Published var contrast: Float = 1.0
    @Published var saturation: Float = 1.0
    @Published var exposure: Float = 0.0
    @Published var temperature: Float = 0.0 // -1.0 to 1.0 (-1.0 bluish, 0.0 neutral, +1.0 warm, yellowish/orange)
    @Published var tint: Float = 0.0 // -1.0 to 1.0 Green (-)/Magenta (+)
    @Published var enabled: Bool = false
}

class ColorCorrectionParams: ObservableObject {
    static let shared = ColorCorrectionParams()

    @Published var lift: simd_float3 = .zero // RGB adjustment for shadows (0 - 2)
    @Published var gamma: simd_float3 = .one // RGB adjustment for midtones (0.5 - 2.5)
    @Published var gain: simd_float3 = .one // RGB adjustment for highlights (0 - 2)
    @Published var enabled: Bool = false
}

class BloomThresholdParams: ObservableObject {
    static let shared = BloomThresholdParams()

    @Published var threshold: Float = 0.5 // 0.0 to 5.0
    @Published var intensity: Float = 0.0 // 0.0 to 2.0
    @Published var enabled: Bool = false
}

class BloomCompositeParams: ObservableObject {
    static let shared = BloomCompositeParams()

    @Published var intensity: Float = 1.0 // 0.0 to 2.0
    @Published var enabled: Bool = false
}

class VignetteParams: ObservableObject {
    static let shared = VignetteParams()

    @Published var intensity: Float = 0.7 // 0.0 to 1.0
    @Published var radius: Float = 0.75 // 0.5 to 1.0
    @Published var softness: Float = 0.45 // 0.0 to 1.0
    @Published var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published var enabled: Bool = false
}

class ChromaticAberrationParams: ObservableObject {
    static let shared = ChromaticAberrationParams()

    @Published var intensity: Float = 0.0 // 0.0 to 0.1
    @Published var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published var enabled: Bool = false
}

class DepthOfFieldParams: ObservableObject {
    static let shared = DepthOfFieldParams()

    @Published var focusDistance: Float = 1.0 // 0.0 to 1.0
    @Published var focusRange: Float = 0.1 // 0.01-0.3
    @Published var maxBlur: Float = 0 // 0.005-0.05
    @Published var enabled: Bool = false
}

class SSAOParams: ObservableObject {
    static let shared = SSAOParams()

    @Published var radius: Float = 0.5 // 0.1 to 2.0 how far to sample
    @Published var bias: Float = 0.025 // 0.01-0.1 avoid self occusion
    @Published var intensity: Float = 0 // 0.5-2.0 Final multiplier
    @Published var enabled: Bool = false
}

class DebugSettings: ObservableObject {
    static let shared = DebugSettings()

    @Published var selectedName: String = ""
    @Published var debugEnabled: Bool = true
}

// Gizmo active
var gizmoActive: Bool = false
var activeHitGizmoEntity: EntityID = .invalid
var parentEntityIdGizmo: EntityID = .invalid

let gizmoDesiredScreenSize: Float = 500.0 // pixels

var spawnDistance: Float = 2.0

let fixedStep: Float = 1.0 / 60.0
var physicsAccumulator: Float = 0

// ssao kernel size
var ssaoKernelSize: Int = 64

// light debug meshes
var spotLightDebugMesh: [Mesh] = []
var pointLightDebugMesh: [Mesh] = []
var areaLightDebugMesh: [Mesh] = []
var dirLightDebugMesh: [Mesh] = []

// Camera defaults
let cameraDefaultEye: simd_float3 = .init(0.0, 1.0, 4.0)
let cameraTargetDefault: simd_float3 = .init(0.0, 0.0, -2.0)
let cameraUpDefault: simd_float3 = .init(0.0, 1.0, 0.0)

// Culling
public struct EntityAABB {
    public var center: simd_float4
    public var halfExtent: simd_float4
    public var index: UInt32
    public var version: UInt32
    public var pad0: UInt32 = 0
    public var pad1: UInt32 = 0
}

struct VisibleEntity { var index: UInt32; var version: UInt32 }
var visibleEntityIds: [EntityID] = []
var tripleVisibleEntities = TripleCPUBuffer<EntityID>(inFlight: 3, initialCapacity: MAX_ENTITIES)
var cullFrameIndex: Int = 0
var needsFinalizeDestroys: Bool = false
var hasPendingDestroys: Bool = false
