//
//  Components.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import MetalKit
import simd

// IMPORTANT:
// When adding a new Component Type in this file, register its cleanup handler
// in RegistrationSystem.registerComponentCleanupHandlers().

public class LocalTransformComponent: Component {
    public var position: simd_float3 = .zero
    public var rotation: simd_quatf = .init()
    public var scale: simd_float3 = .one

    public var space: simd_float4x4 = .identity

    public var boundingBox: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

    public var rotationX: Float = 0
    public var rotationY: Float = 0
    public var rotationZ: Float = 0

    public required init() {}
}

public class WorldTransformComponent: Component {
    public var space: simd_float4x4 = .identity

    public required init() {}
}

public class RenderComponent: Component {
    public var mesh: [Mesh]
    var assetURL: URL = .init(fileURLWithPath: "")
    var assetName: String = ""
    public var isVisible: Bool = true // Visibility flag for bulk loading

    public required init() {
        mesh = []
    }

    func cleanUp() {
        for index in 0 ..< mesh.count {
            mesh[index].cleanUp()
        }

        mesh.removeAll()
    }

    deinit {
        cleanUp()
    }
}

public enum PickHitRepresentationMode: Int, Codable, Sendable, CaseIterable {
    case none
    case bounds
    case mesh
}

public class PickInteractionComponent: Component {
    public var participatesInPicking: Bool = true
    public var hitRepresentationMode: PickHitRepresentationMode = .mesh

    public required init() {}
}

public class GaussianComponent: Component {
    var splatData: MTLBuffer?
    var gaussianSortedIndices: MTLBuffer?
    public var spaceUniform: [MTLBuffer?] = Array(repeating: nil, count: totalPerMeshUniformBuffers())
    var splatCount: UInt = 0

    public required init() {}
}

public class PhysicsComponents: Component {
    var mass: Float = 1.0
    var centerOfMass: simd_float3 = .zero
    var velocity: simd_float3 = .zero
    var angularVelocity: simd_float3 = .zero
    var acceleration: simd_float3 = .zero
    var angularAcceleration: simd_float3 = .zero
    var inertiaTensorType: InertiaTensorType = .spherical
    var momentOfInertiaTensor: simd_float3x3 = .init(diagonal: simd_float3(1.0, 1.0, 1.0))
    var inverseMomentOfInertiaTensor: simd_float3x3 = .init(diagonal: simd_float3(1.0, 1.0, 1.0))
    var linearDragCoefficients: simd_float2 = .zero
    var angularDragCoefficients: simd_float2 = .zero
    var pause: Bool = false
    var inertiaTensorComputed: Bool = false

    public required init() {}
}

public class KineticComponent: Component {
    var forces: [simd_float3] = []
    var moments: [simd_float3] = []

    var gravityScale: Float = 0.0

    public required init() {}

    public func addForce(_ force: simd_float3) {
        forces.append(force)
    }

    public func clearForces() {
        forces.removeAll()
    }

    public func addMoment(_ moment: simd_float3) {
        moments.append(moment)
    }

    public func clearMoments() {
        moments.removeAll()
    }
}

public class SkeletonComponent: Component {
    var skeleton: Skeleton!

    public required init() {}

    func cleanUp() {
        skeleton = nil
    }
}

public class AnimationComponent: Component {
    var animationClips: [String: AnimationClip] = [:]
    var currentAnimation: AnimationClip?
    public var animationsFilenames: [URL] = []
    var pause: Bool = false
    var playbackSpeed: Float = 1.0
    var currentTime: Float = 0.0
    public required init() {}

    func cleanUp() {
        animationClips.removeAll()
        currentAnimation?.cleanUp()
        currentAnimation = nil
    }

    func getAllAnimationClips() -> [String] {
        Array(animationClips.keys)
    }

    func removeAnimationClip(animationClip: String) {
        animationClips.removeValue(forKey: animationClip)
    }
}

public enum LightType: String, CaseIterable {
    case directional
    case point
    case area
    case spotlight
}

public class LightTexture {
    public var directional: MTLTexture?
    public var point: MTLTexture?
    public var spot: MTLTexture?
    public var area: MTLTexture?
}

public class LightComponent: Component {
    public var texture: LightTexture = .init()
    public var lightType: LightType?

    public var color: simd_float3 = .one
    public var intensity: Float = 1.0

    public required init() {}
}

public class DirectionalLightComponent: Component {
    public required init() {}
}

public class PointLightComponent: Component {
    public var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // (constant, linear, quadratic)->x,y,z
    public var radius: Float = 1.0
    public var falloff: Float = 0.5

    public required init() {}
}

public class SpotLightComponent: Component {
    public var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0)
    public var radius: Float = 1.0
    public var innerCone: Float = 5.0
    public var outerCone: Float = 10.0
    public var direction: simd_float3 = .init(0, -1, 0)
    public var falloff: Float = 0.5
    public var coneAngle: Float = 30.0

    public required init() {}
}

public class AreaLightComponent: Component {
    var bounds: simd_float2 = .init(1.0, 1.0)
    var forward: simd_float3 = .zero
    var right: simd_float3 = .zero
    var up: simd_float3 = .zero
    var twoSided: Bool = false

    public required init() {}
}

public class ScenegraphComponent: Component {
    var parent: EntityID = .invalid
    var level: Int = 0 // level 0 means no parent
    var children: [EntityID] = []

    public required init() {}
}

public class CameraComponent: Component {
    public var viewSpace = simd_float4x4.init(1.0)
    public var xAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var yAxis: simd_float3 = .init(0.0, 0.0, 0.0)
    public var zAxis: simd_float3 = .init(0.0, 0.0, 0.0)

    // quaternion
    public var rotation: simd_quatf = .init()
    var localOrientation: simd_float3 = .init(0.0, 0.0, 0.0)
    public var localPosition: simd_float3 = .init(0.0, 0.0, 0.0)
    var orbitTarget: simd_float3 = .init(0.0, 0.0, 0.0)

    var eye: simd_float3 = .zero
    var up: simd_float3 = .zero
    var target: simd_float3 = .zero

    public required init() {}
}

public class SceneCameraComponent: Component {
    public required init() {}
}

public class GizmoComponent: Component {
    public required init() {}
}

// MARK: - Asset Instance Components

/// Attached to the root entity of an imported USDZ asset instance.
/// Marks this entity as an asset instance root, not a derived node.
public class AssetInstanceComponent: Component {
    public var assetURL: URL
    public var assetName: String
    public var importMode: String // "preserveHierarchy" | "combineMeshes"
    public var rootPrimPath: String?

    public required init() {
        assetURL = URL(fileURLWithPath: "")
        assetName = ""
        importMode = "preserveHierarchy"
        rootPrimPath = nil
    }

    public init(assetURL: URL, assetName: String, importMode: String = "preserveHierarchy", rootPrimPath: String? = nil) {
        self.assetURL = assetURL
        self.assetName = assetName
        self.importMode = importMode
        self.rootPrimPath = rootPrimPath
    }
}

/// Attached to entities automatically created by USDZ importer (derived nodes).
/// These entities are NOT authored and should NOT be serialized as separate entities.
public class DerivedAssetNodeComponent: Component {
    public var assetRootEntityId: EntityID // Reference to the asset root entity
    public var nodePath: String // Stable path to this node within the asset hierarchy

    public required init() {
        assetRootEntityId = .invalid
        nodePath = ""
    }

    public init(assetRootEntityId: EntityID, nodePath: String) {
        self.assetRootEntityId = assetRootEntityId
        self.nodePath = nodePath
    }
}

// MARK: - LOD Component

/// Residency state for a LOD level's mesh
public enum LODResidencyState {
    case unknown // Not yet checked
    case resident // Mesh is loaded in memory
    case notResident // Mesh not loaded
    case loading // Mesh is being loaded
}

public struct LODLevel {
    public var mesh: [Mesh] // Meshes for this lod
    public var maxDistance: Float // Switch to next LOD beyond this
    public var screenPercentage: Float // Optional: screen-space threshold
    public var url: URL? // URL to the LOD file (for streaming reload)
    public var assetName: String? // Mesh name within the file (for streaming reload)
    public var residencyState: LODResidencyState = .unknown // Streaming state

    public init(mesh: [Mesh], maxDistance: Float, screenPercentage: Float = 0.0, url: URL? = nil, assetName: String? = nil) {
        self.mesh = mesh
        self.maxDistance = maxDistance
        self.screenPercentage = screenPercentage
        self.url = url
        // Auto-extract assetName from mesh if not provided
        self.assetName = assetName ?? mesh.first?.assetName
        residencyState = mesh.isEmpty ? .notResident : .resident
    }
}

public class LODComponent: Component {
    public var lodLevels: [LODLevel] = [] // Sorted by distance (LOD0 first)
    public var currentLOD: Int = 0 // Active LOD index (what's actually rendering)
    public var desiredLOD: Int = 0 // What LOD we want based on distance
    public var fadeTransition: Bool = false // Enable cross-fade
    public var transitionDuration: Float = 0.3 // Fade time in seconds
    public var transitionProgress: Float = 0.0 // Current fade (0-1)
    public var previousLOD: Int? // For blending
    public var forcedLOD: Int? // Manual override (-1 = auto)

    /// True if currentLOD != desiredLOD due to missing mesh
    public var isUsingFallback: Bool = false

    /// Mesh asset identifier for batching (material hash + LOD)
    public var activeMeshAssetID: String = ""

    public required init() {}

    /// Check if the desired LOD level has a resident mesh
    public func isLODResident(_ lodIndex: Int) -> Bool {
        guard lodIndex >= 0, lodIndex < lodLevels.count else { return false }
        let level = lodLevels[lodIndex]
        return level.residencyState == .resident && !level.mesh.isEmpty
    }

    /// Find the best available fallback LOD (coarser than desired)
    public func findFallbackLOD(from desiredIndex: Int) -> Int? {
        // Try coarser LODs first (higher index = lower detail)
        for i in (desiredIndex + 1) ..< lodLevels.count {
            if isLODResident(i) {
                return i
            }
        }
        // Then try finer LODs (lower index = higher detail)
        for i in (0 ..< desiredIndex).reversed() {
            if isLODResident(i) {
                return i
            }
        }
        return nil
    }
}

// MARK: Static Batching Component

public class StaticBatchComponent: Component {
    public var isStatic: Bool = true // Object doesn't move
    public var batchGroupId: UUID? // Assigned during batching
    public var canBatch: Bool = true // User can disable batching per object

    public required init() {}
}

// MARK: Tile Streaming

/// Asset-level lifecycle state of a manifest tile stub.
/// Describes the parse/setup progress of the tile's geometry data.
///   unloaded → parsing → parsed → unloading → unloaded
///   Any state → failed (on error) → unloaded (after retry backoff)
public enum TileAssetState {
    case unloaded   // stub registered, tile file not parsed yet
    case parsing    // setEntityMeshAsync in progress for this tile
    case parsed     // tile parsed; child mesh stubs registered and streaming
    case failed     // last parse/upload attempt failed — retry after backoff
    case unloading  // tile being torn down; child entities being destroyed
}

/// Visual residency state of a tile's GPU geometry.
/// Derived from the ratio of OCC sub-mesh stubs that have completed GPU upload.
/// Eager tiles (no OCC stubs) jump directly to .complete when parsed.
public enum TileVisualState {
    case empty      // no GPU geometry resident
    case partial    // some OCC stubs uploaded (< 50 %)
    case usable     // majority of OCC geometry uploaded (≥ 50 %)
    case complete   // all OCC stubs fully GPU-resident
}

/// Attached to every tile stub entity created by loadTiledScene().
/// Carries the metadata the streaming bootstrap needs to trigger a full
/// tile parse (setEntityMeshAsync) when the camera enters streaming range,
/// and to tear down the tile when the camera leaves.
public class TileComponent: Component {
    /// Resolved URL to the tile's USDC/USDZ file.
    public var tileURL: URL = URL(fileURLWithPath: "")

    /// File size in bytes (from manifest). Used by the pre-parse memory budget gate.
    public var fileSizeBytes: Int = 0

    /// Distance at which the tile begins loading.
    public var streamingRadius: Float = 80.0

    /// Distance beyond which the tile is torn down.
    public var unloadRadius: Float = 120.0

    /// Load priority (higher = loads first when multiple tiles are in range).
    public var priority: Int = 10

    /// Human-readable tile identifier from the manifest (e.g. "tile_3_2").
    public var tileId: String = ""

    /// Asset-level lifecycle state driven by the streaming bootstrap.
    public var state: TileAssetState = .unloaded

    // MARK: - Streaming Radii

    /// Distance at which this tile begins loading in the background (prefetch zone).
    /// Set to 0 to auto-compute as the midpoint between `streamingRadius` and
    /// `unloadRadius`, guaranteeing the tile is fully parsed before the camera
    /// physically enters the visual display zone (`streamingRadius`).
    /// Set explicitly (> 0) to override; must be ≤ `unloadRadius`.
    public var prefetchRadius: Float = 0

    /// Effective prefetch radius, resolving 0 (auto) to the midpoint formula.
    public var effectivePrefetchRadius: Float {
        if prefetchRadius > 0 { return prefetchRadius }
        return streamingRadius + (unloadRadius - streamingRadius) * 0.5
    }

    // MARK: - Unload Grace Period

    /// CFAbsoluteTime at which this tile first exceeded its `unloadRadius`.
    /// Reset to 0 when the camera returns inside `unloadRadius` or the tile unloads.
    /// The streaming system waits `GeometryStreamingSystem.unloadGracePeriod` seconds
    /// from this timestamp before actually tearing the tile down, preventing rapid
    /// load/unload oscillation at tile boundaries.
    /// Both `.parsed` and `.parsing` tiles honour the grace period: the window lets
    /// an in-flight parse complete naturally rather than being cancelled and immediately
    /// re-dispatched, preventing tight load-cancel cycles at the boundary.
    public var pendingUnloadSince: CFAbsoluteTime = 0

    // MARK: - Visual Readiness (OCC sub-mesh tracking)

    /// Total number of OCC (out-of-core) streaming stubs created during tile parse.
    /// 0 for eager tiles — those are visually complete as soon as the parse finishes.
    public var totalOCCStubs: Int = 0

    /// Number of OCC stubs that have completed GPU upload and are now renderable.
    public var uploadedOCCStubs: Int = 0

    /// Computed visual residency state based on OCC upload progress.
    public var visualState: TileVisualState {
        guard state == .parsed else { return .empty }
        if totalOCCStubs == 0 { return .complete }
        switch uploadedOCCStubs {
        case 0: return .empty
        case let n where n >= totalOCCStubs: return .complete
        case let n where Float(n) / Float(totalOCCStubs) >= 0.5: return .usable
        default: return .partial
        }
    }

    // MARK: - Failure / Retry

    /// Number of consecutive parse failures (reset to 0 on successful load).
    public var failureCount: Int = 0

    /// CFAbsoluteTime of the most recent failure. Used to compute retry eligibility.
    public var lastFailureTime: Double = 0

    /// Exponential backoff delay before the next retry attempt (5 s, 10 s, 20 s … max 60 s).
    public var retryDelaySeconds: Double {
        min(pow(2.0, Double(max(failureCount - 1, 0))) * 5.0, 60.0)
    }

    /// Task handle for the in-flight setEntityMeshAsync call.
    var loadTask: Task<Void, Never>?

    public required init() {}
}

// MARK: Geometry Streaming

/// State of an entity's streamed mesh
public enum MeshStreamingState: String {
    case unloaded // No mesh data loaded
    case loading // Async load in progress
    case loaded // Mesh is fully loaded
    case unloading // Being unloaded
}

/// Component that marks an entity for geometry streaming
public class StreamingComponent: Component {
    /// Distance from camera at which mesh starts loading
    public var streamingRadius: Float = 100.0

    /// Distance from camera beyond which mesh unloads
    public var unloadRadius: Float = 150.0

    /// Higher priority entities load first (default: 0)
    public var priority: Int = 0

    /// Filename of the asset (without extension)
    public var assetFilename: String = ""

    /// File extension (e.g., "usdz")
    public var assetExtension: String = ""

    /// Optional: specific mesh name within the asset
    public var assetName: String?

    /// Current streaming state
    public var state: MeshStreamingState = .unloaded

    /// Frame when entity was last visible (for LRU eviction)
    public var lastVisibleFrame: Int = 0

    /// Task handle for cancellation
    var loadTask: Task<Void, Never>?

    public required init() {}

    /// Convenience initializer
    public convenience init(
        filename: String,
        withExtension ext: String,
        streamingRadius: Float = 100.0,
        unloadRadius: Float = 150.0,
        priority: Int = 0
    ) {
        self.init()
        assetFilename = filename
        assetExtension = ext
        self.streamingRadius = streamingRadius
        self.unloadRadius = unloadRadius
        self.priority = priority
    }
}

// MARK: - USC Scripting Component

public class ScriptComponent: Component, Codable {
    // New multi-script storage
    public var scripts: [USCScript] = []
    public var scriptFilePaths: [String]? = nil

    public required init() {}

    /// Backward-compatible coding keys
    enum CodingKeys: String, CodingKey {
        case scripts
        case scriptFilePaths
        // Legacy single-script fields supported for decoding
        case script
        case scriptFilePath
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode the new multi-script fields
        try container.encode(scripts, forKey: .scripts)
        try container.encodeIfPresent(scriptFilePaths, forKey: .scriptFilePaths)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try new array-based decoding first
        let decodedScripts = try container.decodeIfPresent([USCScript].self, forKey: .scripts)
        let decodedPaths = try container.decodeIfPresent([String].self, forKey: .scriptFilePaths)

        if let decodedScripts {
            scripts = decodedScripts
            scriptFilePaths = decodedPaths
            return
        }

        // Fallback to legacy single-script decoding
        let legacyScript = try container.decodeIfPresent(USCScript.self, forKey: .script)
        let legacyPath = try container.decodeIfPresent(String.self, forKey: .scriptFilePath)

        if let legacyScript {
            scripts = [legacyScript]
        } else {
            scripts = []
        }
        if let legacyPath {
            scriptFilePaths = [legacyPath]
        } else {
            scriptFilePaths = nil
        }
    }
}
