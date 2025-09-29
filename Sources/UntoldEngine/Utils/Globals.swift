
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
    public static let invalid: EntityID = .max
}

var componentCounter = 0
var globalEntityCounter: UInt32 = 0
let MAX_COMPONENTS = 64
let MAX_ENTITIES = 1000

var maxNumPointLights: Int = 100
var maxNumSpotLights: Int = 100
var maxAreaLights: Int = 100
public var scene: Scene = .init()
var shadowSystem: ShadowSystem!

public var renderInfo = RenderInfo()

public var vertexDescriptor = VertexDescriptors()
public var bufferResources = BufferResources()
var tripleBufferResources = TripleBufferResources()
public var textureResources = TextureResources()

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
public let far: Float = 500
public let near: Float = 0.01
public let fov: Float = 65.0

// Shadow max parameters
let shadowMaxWidth: Float = 300.0
let shadowMaxHeight: Float = 300.0

let shadowResolution: simd_int2 = .init(8192, 8192)

var rayTracingPipeline = ComputePipeline()
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

public let quadIndices: [UInt16] = [
    0, 1, 3, // First Triangle
    3, 1, 2, // Second Triangle
]

public enum TextureType: String, CaseIterable, Identifiable {
    case baseColor
    case roughness
    case metallic
    case normal

    public var id: Self { self } // Satisfies Identifiable conformance

    public var displayName: String {
        switch self {
        case .baseColor: return "Base Color"
        case .roughness: return "Roughness"
        case .metallic: return "Metallic"
        case .normal: return "Normal"
        }
    }
}

// TODO: try to remove this var, because only make sense on the editor side
public var gameMode: Bool = true

public var applyIBL: Bool = true
public var renderEnvironment: Bool = false
public var ambientIntensity: Float = 1.0

// hightlight
public let boundingBoxVertexCount = 24

var envRotationAngle: Float = 0
public var hdrURL: String = "teatro_massimo_2k.hdr"
public var resourceURL: URL?

var currentGlobalTime: Float = 0.0

// Physics system

enum InertiaTensorType: Int {
    case cubic
    case spherical
    case cylindrical
}

public var assetBasePath: URL?

public var activeEntity: EntityID = .invalid

// Transform Manipulation mode
public enum TransformManipulationMode {
    case translate
    case rotate
    case scale
    case lightRotate
    case none
}

public enum TransformAxis {
    case x, y, z, none
}

// mtk view color
// Graphite Gray
let mtkBackgroundColor = MTLClearColorMake(40.0 / 255.0, 40.0 / 255.0, 45.0 / 255.0, 1.0)


let fixedStep: Float = 1.0 / 60.0
var physicsAccumulator: Float = 0

// ssao kernel size
var ssaoKernelSize: Int = 64

// Camera defaults
public let cameraDefaultEye: simd_float3 = .init(0.0, 1.0, 4.0)
public let cameraTargetDefault: simd_float3 = .init(0.0, 0.0, -2.0)
public let cameraUpDefault: simd_float3 = .init(0.0, 1.0, 0.0)

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
public var visibleEntityIds: [EntityID] = []
public var tripleVisibleEntities = TripleCPUBuffer<EntityID>(inFlight: 3, initialCapacity: MAX_ENTITIES)
public var cullFrameIndex: Int = 0
public var needsFinalizeDestroys: Bool = false
var hasPendingDestroys: Bool = false

public class ToneMappingParams: ObservableObject {
    static let shared = ToneMappingParams()

    @Published var toneMapOperator: Int = 0
    @Published var gamma: Float = 1.0 // original = 2.2
}

public class ColorGradingParams: ObservableObject {
    public static let shared = ColorGradingParams()

    @Published public var brightness: Float = 0.0
    @Published public var contrast: Float = 1.0
    @Published public var saturation: Float = 1.0
    @Published public var exposure: Float = 0.0
    @Published public var temperature: Float = 0.0 // -1.0 to 1.0 (-1.0 bluish, 0.0 neutral, +1.0 warm, yellowish/orange)
    @Published public var tint: Float = 0.0 // -1.0 to 1.0 Green (-)/Magenta (+)
    @Published public var enabled: Bool = false
}

public class ColorCorrectionParams: ObservableObject {
    static let shared = ColorCorrectionParams()

    @Published var lift: simd_float3 = .zero // RGB adjustment for shadows (0 - 2)
    @Published var gamma: simd_float3 = .one // RGB adjustment for midtones (0.5 - 2.5)
    @Published var gain: simd_float3 = .one // RGB adjustment for highlights (0 - 2)
    @Published var enabled: Bool = false
}

public class BloomThresholdParams: ObservableObject {
    public static let shared = BloomThresholdParams()

    @Published public var threshold: Float = 0.5 // 0.0 to 5.0
    @Published public var intensity: Float = 0.0 // 0.0 to 2.0
    @Published public var enabled: Bool = false
}

public class BloomCompositeParams: ObservableObject {
    public static let shared = BloomCompositeParams()

    @Published public var intensity: Float = 1.0 // 0.0 to 2.0
    @Published public var enabled: Bool = false
}

public class VignetteParams: ObservableObject {
    public static let shared = VignetteParams()

    @Published public var intensity: Float = 0.7 // 0.0 to 1.0
    @Published public var radius: Float = 0.75 // 0.5 to 1.0
    @Published public var softness: Float = 0.45 // 0.0 to 1.0
    @Published public var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published public var enabled: Bool = false
}

public class ChromaticAberrationParams: ObservableObject {
    public static let shared = ChromaticAberrationParams()

    @Published public var intensity: Float = 0.0 // 0.0 to 0.1
    @Published public var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published public var enabled: Bool = false
}

public class DepthOfFieldParams: ObservableObject {
    public static let shared = DepthOfFieldParams()

    @Published public var focusDistance: Float = 1.0 // 0.0 to 1.0
    @Published public var focusRange: Float = 0.1 // 0.01-0.3
    @Published public var maxBlur: Float = 0 // 0.005-0.05
    @Published public var enabled: Bool = false
}

public class SSAOParams: ObservableObject {
    public static let shared = SSAOParams()

    @Published public var radius: Float = 0.5 // 0.1 to 2.0 how far to sample
    @Published public var bias: Float = 0.025 // 0.01-0.1 avoid self occusion
    @Published public var intensity: Float = 0 // 0.5-2.0 Final multiplier
    @Published public var enabled: Bool = false
}
