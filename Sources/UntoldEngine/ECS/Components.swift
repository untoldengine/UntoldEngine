//
//  Components.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import MetalKit
import simd

// IMPORTANT:
// When adding a new Component Type in this file, register its cleanup handler
// in RegistrationSystem.registerComponentCleanupHandlers().

public class LocalTransformComponent: Component {
    public var position: simd_float3 = .zero
    // simd_quatf() is the zero quaternion, not identity: it rotates every vector
    // to zero, so entities created via registerComponent would silently zero out
    // any math done with their default rotation.
    public var rotation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)
    public var scale: simd_float3 = .one

    public var space: simd_float4x4 = .identity

    public var boundingBox: (min: simd_float3, max: simd_float3) = (min: simd_float3(-1.0, -1.0, -1.0), max: simd_float3(1.0, 1.0, 1.0))

    public var rotationX: Float = 0
    public var rotationY: Float = 0
    public var rotationZ: Float = 0

    /// Set to true when position/rotation/scale is mutated directly (camera, physics,
    /// or any path that bypasses the eager syncWorldTransformAndMarkOctreeDirty path).
    /// traverseSceneGraph skips entities where this is false, eliminating per-frame
    /// matrix recomputation for static tile stubs and other never-moving entities.
    public var transformDirty: Bool = true

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
    public var castsShadow: Bool = true

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

public class EntitySceneChannelsComponent: Component {
    public var channels: SceneChannel = []
    public var usesDefaultChannels: Bool = false

    public required init() {}
}

public class GaussianComponent: Component {
    var encodedSplatData: MTLBuffer?
    var sphericalHarmonicsData: MTLBuffer?
    var sphericalHarmonicsMetadata: GaussianSHMetadata?
    // Written every frame by the cull/depth-key/radix-sort/preprocess passes and read the
    // same frame by the draw pass. With up to maxInFlightCommandBuffers frames overlapping
    // on the GPU, a single shared buffer here lets a newer frame's CPU-side writes clobber
    // data an older in-flight frame's draw is still reading — visible as splat flicker.
    // Slotted per in-flight frame (indexed by renderInfo.currentInFlightFrameSlot), same
    // pattern as spaceUniform below, to keep each frame's data isolated.
    var gaussianSortedIndices: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    var gaussianVisibleIndices: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    var gaussianVisibleCount: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    /// Per-splat conic/radius/color, written once per frame by executeGaussianPreprocess
    /// and read by the draw vertex shader — see GaussianPrecomputedSplat. Same frame-slot
    /// race as the buffers above, so it gets the same treatment.
    var gaussianPrecomputedData: [MTLBuffer?] = Array(repeating: nil, count: maxInFlightCommandBuffers)
    var visibleSplatCountForRendering: UInt = 0
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

/// Per-entity animation control policy.
///
/// Layered animation control (see upstream discussion #801): the global
/// `AnimationSystem.isEnabled` toggle has highest precedence — when it is
/// off, nothing animates regardless of policy. When it is on, each entity
/// resolves its own policy: `.inherit` follows the effective value from the
/// levels above (global today; per-view control when the editor adds it),
/// `.forceOn` always animates, and `.forceOff` never animates.
///
/// `.forceOff` freezes the entity's playback clock without touching its
/// `pause` state, so toggling the policy back restores whatever play/pause
/// state the entity had.
public enum AnimationPolicy: String, CaseIterable, Sendable {
    case inherit
    case forceOn
    case forceOff
}

public class AnimationComponent: Component {
    var animationClips: [String: AnimationClip] = [:]
    var currentAnimation: AnimationClip?
    public var animationsFilenames: [URL] = []
    var pause: Bool = false
    var playbackSpeed: Float = 1.0
    var currentTime: Float = 0.0
    var policy: AnimationPolicy = .inherit

    // Compiled sampling state (see docs/Architecture/animationPoseLayer.md):
    // clips resolved against this entity's skeleton, plus the per-entity
    // sampler cursors and local pose the frame update writes into.
    var compiledClips: [String: CompiledAnimationClip] = [:]
    var sampler = ClipSampler()
    var localPose = PoseBuffer()

    // Displayed-pose history for inertialized transitions: `localPose` holds
    // the pose shown last frame (post-transition offsets), `previousPose`
    // the frame before. The update loop ping-pongs the two buffers so
    // steady-state playback never allocates.
    var previousPose = PoseBuffer()
    var hasSampledPose = false
    var hasPreviousPose = false
    var lastSampleDeltaTime: Float = 0
    var transition = PoseTransition()
    var rootMotion = RootMotionState()
    var footIK = FootIKState()
    var motionMatching = MotionMatchingState()

    public required init() {}

    func cleanUp() {
        animationClips.removeAll()
        currentAnimation?.cleanUp()
        currentAnimation = nil
        compiledClips.removeAll()
        sampler = ClipSampler()
        localPose = PoseBuffer()
        previousPose = PoseBuffer()
        hasSampledPose = false
        hasPreviousPose = false
        lastSampleDeltaTime = 0
        transition = PoseTransition()
        rootMotion = RootMotionState()
        footIK = FootIKState()
        motionMatching = MotionMatchingState()
    }

    func getAllAnimationClips() -> [String] {
        Array(animationClips.keys)
    }

    func removeAnimationClip(animationClip: String) {
        animationClips.removeValue(forKey: animationClip)
        compiledClips.removeValue(forKey: animationClip)
    }

    /// Returns the compiled form of `clip` resolved against `skeleton`,
    /// compiling and caching it on first use.
    func compiledClip(for clip: AnimationClip, skeleton: Skeleton) -> CompiledAnimationClip {
        if let cached = compiledClips[clip.name], cached.jointCount == skeleton.jointPaths.count {
            return cached
        }
        let compiled = CompiledAnimationClip(clip: clip, skeleton: skeleton)
        compiledClips[clip.name] = compiled
        return compiled
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
    /// When true, local-light intensity is radiant power in watts and sun
    /// intensity is irradiance in W/m². False preserves legacy engine units.
    public var usesRadiometricUnits: Bool = false

    public required init() {}
}

public class DirectionalLightComponent: Component {
    public var castsShadow: Bool = true
    public required init() {}
}

public class PointLightComponent: Component {
    public var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // (constant, linear, quadratic)->x,y,z
    /// Physical emitter radius. It does not define the light's influence range.
    public var radius: Float = 1.0
    /// Optional influence cutoff. Zero means no authored cutoff.
    public var range: Float = 0.0
    public var falloff: Float = 0.5
    public var castsShadow: Bool = false

    public required init() {}
}

public class SpotLightComponent: Component {
    public var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0)
    /// Physical emitter radius. It does not define the light's influence range.
    public var radius: Float = 1.0
    /// Optional influence cutoff. Zero means no authored cutoff.
    public var range: Float = 0.0
    public var innerCone: Float = 5.0
    public var outerCone: Float = 10.0
    public var direction: simd_float3 = .init(0, -1, 0)
    public var falloff: Float = 0.5
    public var coneAngle: Float = 30.0
    public var castsShadow: Bool = false

    public required init() {}
}

public class AreaLightComponent: Component {
    public var bounds: simd_float2 = .init(1.0, 1.0)
    var forward: simd_float3 = .zero
    var right: simd_float3 = .zero
    var up: simd_float3 = .zero
    public var twoSided: Bool = false
    public var range: Float = 0.0
    public var castsShadow: Bool = false

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

    // quaternion (identity; simd_quatf() would be the zero quaternion)
    public var rotation: simd_quatf = .init(ix: 0, iy: 0, iz: 0, r: 1)
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

/// Shared by `LODLevel` and `GaussianLODLevel` so `isLODLevelResident`/`findFallbackLODLevel`
/// (`LODSystem.swift`) can implement residency/fallback selection once for both mesh and
/// Gaussian LOD instead of each component re-declaring the same algorithm.
protocol LODResidencyLevel {
    var residencyState: LODResidencyState { get }
    /// Whether this level actually has a usable payload — `residencyState` alone isn't
    /// trusted, mirroring the double-check both components already made before this was shared.
    var isPopulated: Bool { get }
}

/// Shared by `LODLevel` and `GaussianLODLevel` so `selectLODIndex` (`LODSystem.swift`) can pick
/// a distance-based tier once for both mesh and Gaussian LOD instead of each system
/// re-declaring the same threshold/hysteresis algorithm.
protocol LODDistanceLevel {
    var maxDistance: Float { get }
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

extension LODLevel: LODResidencyLevel {
    var isPopulated: Bool {
        !mesh.isEmpty
    }
}

extension LODLevel: LODDistanceLevel {}

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
        isLODLevelResident(lodLevels, lodIndex)
    }

    /// Find the best available fallback LOD (coarser than desired)
    public func findFallbackLOD(from desiredIndex: Int) -> Int? {
        findFallbackLODLevel(lodLevels, from: desiredIndex)
    }
}

// MARK: - Progressive Gaussian LOD Component

/// One pre-baked quality tier for a progressive Gaussian splat asset.
/// LOD0 is expected to be the full-resolution tier; later indices are progressively coarser.
public struct GaussianLODLevel {
    public var buffers: GaussianComponent?
    public var maxDistance: Float
    public var url: URL?
    public var residencyState: LODResidencyState = .unknown
    var loadTask: Task<Void, Never>?
    /// Bake-time mean of this tier's kept splats' squared major-axis extent — see
    /// `estimatedGaussianOverdraw`. Baked into the `.untoldgs` file itself
    /// (`UntoldGSFormat`/`bakeGaussianSplatProgressiveTiers`) and populated automatically by
    /// `loadGaussianLODLevel` once this tier's file is actually read. `nil` only before that —
    /// i.e. this tier hasn't loaded yet — in which case `clampGaussianLODForOverdraw` falls
    /// back to distance-only LOD selection for it.
    public var meanSquaredSplatExtent: Float?

    public init(maxDistance: Float, url: URL? = nil) {
        self.maxDistance = maxDistance
        self.url = url
    }
}

extension GaussianLODLevel: LODResidencyLevel {
    var isPopulated: Bool {
        buffers != nil
    }
}

extension GaussianLODLevel: LODDistanceLevel {}

/// Runtime state for a progressively streamed Gaussian splat prop.
/// The renderer still consumes a normal `GaussianComponent`; this component owns the
/// per-tier residency and `GaussianLODSystem` copies the selected tier onto the live
/// `GaussianComponent`.
public class GaussianLODComponent: Component {
    public var lodLevels: [GaussianLODLevel] = []
    public var currentLOD: Int = -1
    public var desiredLOD: Int = 0
    public var forcedLOD: Int?
    public var isUsingFallback: Bool = false

    /// The LOD index pure distance+hysteresis selection last landed on, before the
    /// overdraw-aware clamp is applied — see `GaussianLODSystem.selectDesiredLOD`. Kept
    /// separate from `desiredLOD` (the final, possibly overdraw-forced-coarser target used for
    /// residency/streaming/`applyLOD`) so an overdraw-forced tier doesn't retroactively bias
    /// the hysteresis anchor `selectLODIndex` uses next frame — otherwise a frame where overdraw
    /// forces LOD 3 would make LOD 3 "the tier we're logically at" for the *next* frame's
    /// distance-only hysteresis math too, even though distance alone would have picked LOD 1.
    var distanceSelectedLOD: Int = 0

    /// Distance to camera the last time this entity's LOD was fully re-evaluated — see
    /// `GaussianLODSystem.update`'s per-entity fast path, which forces a refresh when this
    /// entity (not just the camera) has moved enough to plausibly cross a LOD threshold,
    /// independent of the camera-movement/frame-interval throttle. `nil` forces an evaluation
    /// the first time this entity is seen.
    var lastEvaluatedDistance: Float?

    /// `true` when the caller explicitly supplied a `boundingBoxHalfExtent` (always the case
    /// for the streaming path, optional for the non-streaming path). When `false`,
    /// `loadGaussianLODLevel` auto-populates `LocalTransformComponent.boundingBox` from the
    /// first (coarsest) tier's real splat data once it loads, instead of leaving the entity on
    /// its default placeholder box forever.
    var hasExplicitBoundingBox: Bool = false

    /// Last state GaussianLODSystem's diagnostic log reported for this entity — used only to
    /// dedup consecutive identical log lines (log on change, not every evaluation).
    var lastLoggedDesiredLOD: Int = -2
    var lastLoggedActualLOD: Int = -2

    public required init() {}

    public func isLODResident(_ lodIndex: Int) -> Bool {
        isLODLevelResident(lodLevels, lodIndex)
    }

    public func findFallbackLOD(from desiredIndex: Int) -> Int? {
        findFallbackLODLevel(lodLevels, from: desiredIndex)
    }

    /// Cancels in-flight loads and drops residency for every tier. Does not touch
    /// currentLOD/desiredLOD — callers decide those based on whether this is a
    /// stream-out (reset to coarsest) or full teardown (component removed right after).
    func releaseAllLevelResources() {
        for index in lodLevels.indices {
            lodLevels[index].loadTask?.cancel()
            lodLevels[index].loadTask = nil
            lodLevels[index].buffers = nil
            lodLevels[index].residencyState = .notResident
        }
    }
}

// MARK: Tile LOD Tag Component

/// Lightweight tag placed on the render-descendant mesh entities spawned by
/// GeometryStreamingSystem for per-tile LOD levels and HLODs.  Used by the
/// LOD debug renderer (colorRenderablesByLOD) to colour these meshes the same
/// way entity-level LODComponent meshes are coloured.
///
/// levelIndex follows the lodDebugPalette in RenderPasses:
///   0 = full tile (unused here)   1 = tile LOD1 (green)
///   2 = tile LOD2 (blue)          5 = HLOD (cyan / palette wraps)
public class TileLODTagComponent: Component {
    public var levelIndex: Int = 0
    public required init() {}
    public init(levelIndex: Int) {
        self.levelIndex = levelIndex
    }
}

/// Per-render-descendant dither state used while tile LOD/HLOD/full-tile
/// representations hand off visibility.
public class TileRepresentationFadeComponent: Component {
    /// 0...1 cross-fade progress.
    public var progress: Float = 0
    /// Matches MaterialParametersUniform.lodDither.y.
    /// 1 = incoming representation, 2 = outgoing representation.
    public var mode: Float = 0

    public required init() {}
    public init(progress: Float, mode: Float) {
        self.progress = progress
        self.mode = mode
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
    case unloaded // stub registered, tile file not parsed yet
    case parsing // setEntityMeshAsync in progress for this tile
    case parsed // tile parsed; child mesh stubs registered and streaming
    case failed // last parse/upload attempt failed — retry after backoff
    case unloading // tile being torn down; child entities being destroyed
}

/// Lifecycle state of a tile's coarse HLOD mesh or per-tile LOD level.
public enum HLODAssetState {
    case unloaded // no geometry in flight
    case loading // setEntityMeshAsync in progress
    case loaded // mesh is GPU-resident and rendering
    case unloading // being torn down
}

/// One LOD level for a tile stub.  Levels are stored sorted ascending by
/// switchDistance (smallest = finest = closest to camera).  The streaming
/// system loads the single appropriate level for the current camera distance
/// and unloads all others, so at most one TileLODLevel is active at a time.
public final class TileLODLevel {
    /// Absolute URL to the coarser USDC/USDZ for this LOD level.
    public let url: URL
    /// Camera distance beyond which this LOD is preferred over the next finer level
    /// (or the full tile if this is the finest LOD).
    public let switchDistance: Float
    /// Child entity carrying the RenderComponent for this LOD.  .invalid when not loaded.
    public var entityId: EntityID = .invalid
    /// Lifecycle state — mirrors HLODAssetState.
    public var state: HLODAssetState = .unloaded
    /// Task handle for the in-flight setEntityMeshAsync call.
    var loadTask: Task<Void, Never>?

    public init(url: URL, switchDistance: Float) {
        self.url = url
        self.switchDistance = switchDistance
    }
}

/// Visual residency state of a tile's GPU geometry.
/// Derived from the ratio of OCC sub-mesh stubs that have completed GPU upload.
/// Eager tiles (no OCC stubs) jump directly to .complete when parsed.
public enum TileVisualState {
    case empty // no GPU geometry resident
    case partial // some OCC stubs uploaded (< 50 %)
    case usable // majority of OCC geometry uploaded (≥ 50 %)
    case complete // all OCC stubs fully GPU-resident
}

/// Marker component attached to the root entity of a tiled scene.
/// Every tile stub created from the manifest is parented under the entity
/// that carries this component.  Use it to identify, move, or unload an
/// entire tiled scene as a single logical object.
///
/// - Note: Root-entity transforms are not propagated to streaming/culling
///   bounds in this release.  Keep the root at identity transform.
public class TiledSceneComponent: Component {
    /// Human-readable label derived from the manifest filename.
    public var manifestLabel: String = ""

    /// Original manifest URL used to create this streamed scene.
    public var manifestURL: URL?

    public required init() {}
}

/// Attached to every tile stub entity created by setEntityStreamScene().
/// Carries the metadata the streaming bootstrap needs to trigger a full
/// tile parse (setEntityMeshAsync) when the camera enters streaming range,
/// and to tear down the tile when the camera leaves.
public class TileComponent: Component {
    /// Resolved URL to the tile's USDC/USDZ file.
    public var tileURL: URL = .init(fileURLWithPath: "")

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

    /// Quadtree node identifier from the manifest (e.g. "F02Q100").
    /// Present only in v4 quadtree_floor manifests; nil for v3 uniform-grid tiles.
    /// Used by the hierarchy-aware tile culling gate in GeometryStreamingSystem.
    public var quadtreeNodeId: String?

    /// When true this tile contains interior-only geometry (StructuralInterior,
    /// RoomContents, FineProps).  The streaming system gates loading of these
    /// tiles on the camera being inside the scene's interior_zone.
    public var isInterior: Bool = false

    /// True when this tile came from a floor-aware manifest entry.
    /// The floor-proximity gate must key off this explicit metadata, not a nonzero
    /// Y center, because older uniform-grid manifests can have large padded Y bounds.
    public var hasFloorMetadata: Bool = false

    /// Floor index from the manifest.  0 is a valid ground-floor value when
    /// `hasFloorMetadata` is true.
    /// Used by the floor-proximity gate in GeometryStreamingSystem to skip tiles
    /// whose floor band is vertically distant from the camera.
    public var floorId: Int = 0

    /// Y-axis centre of the tile's world-space AABB.
    /// Stored at registration time so the floor-proximity gate can skip vertically
    /// distant tiles without a repeated LocalTransformComponent lookup per tick.
    public var worldYCenter: Float = 0

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

    /// CFAbsoluteTime at which this tile most recently became `.parsed`.
    /// Used by the streaming system to enforce a minimum resident dwell so a
    /// newly visible full tile cannot be immediately torn down when the camera
    /// hovers near an unload boundary.
    public var parsedResidentSince: CFAbsoluteTime = 0

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

    /// Entity ID of the child mesh entity created for the current load cycle.
    /// Stored so the parse-timeout guard can force-release the AssetLoadingGate
    /// (opened inside setEntityMeshAsync's own Task) without reverse-iterating the
    /// meshEntityToTileEntity map.  Reset to .invalid when the load completes or is
    /// cancelled.
    var meshEntityId: EntityID = .invalid

    /// CFAbsoluteTime at which the current parse was dispatched.
    /// Used by the streaming system to detect hung tile loads (e.g. ModelIO
    /// blocking indefinitely on an unsupported image format) and force them
    /// to .failed so the concurrency slot is freed and retry backoff applies.
    /// Reset to 0 when the tile transitions out of .parsing.
    public var parseStartTime: CFAbsoluteTime = 0

    // MARK: - Per-tile LOD levels

    /// One entry per LOD level parsed from the manifest, sorted ascending by
    /// switchDistance (smallest = finest detail = closest to camera).
    /// LOD levels fill the distance band between the tile's streaming radius
    /// (where full geometry loads) and the HLOD switch distance (where the coarse
    /// proxy takes over).  Only one level is active at a time.
    public var lodLevels: [TileLODLevel] = []

    // MARK: - HLOD (coarse distant mesh)

    /// Resolved URL to the tile's HLOD USDC file.  nil means no HLOD for this tile.
    public var hlodURL: URL?

    /// Camera distance beyond which the HLOD mesh is shown instead of full geometry.
    /// 0 means no HLOD configured.
    public var hlodSwitchDistance: Float = 0

    /// Entity ID of the child entity carrying the HLOD RenderComponent.
    /// nil when HLOD is not loaded.
    public var hlodEntityId: EntityID?

    /// Lifecycle state of the HLOD mesh.
    public var hlodState: HLODAssetState = .unloaded

    /// Task handle for the in-flight HLOD setEntityMeshAsync call.
    var hlodLoadTask: Task<Void, Never>?

    /// Timestamp of the most recent HLOD state transition that materially changed
    /// residency (.loaded or .unloaded). Used to enforce a minimum dwell so HLOD does
    /// not flap at the boundary between far-field and mid-field representation bands.
    public var lastHLODTransitionTime: CFAbsoluteTime = 0

    /// Timestamp of the most recent per-tile LOD residency change. Used alongside the
    /// geometry streaming system's dwell rule to prevent rapid level churn.
    public var lastLODTransitionTime: CFAbsoluteTime = 0

    /// Last LOD level index that was loaded for this tile, or nil when none is active.
    /// Tracks representation churn for diagnostics and dwell logic.
    public var lastLoadedLODIndex: Int?

    /// Partition-cell AABB from the manifest (key: "cell_bounds").
    /// Tighter than the mesh content AABB for spanning tiles whose geometry
    /// overflows the cell boundary.  Used by the debug tile-bounds visualizer
    /// so the drawn box matches the Blender overlay partition cells.
    /// nil for manifests that predate the cell_bounds field and for the shared bucket.
    public var cellBounds: AABB?

    /// True when this entity represents the shared-bucket tile (the monolithic asset
    /// holding world-spanning objects).  The shared bucket is not a partition cell so
    /// it is excluded from the "Tile Bounds" debug overlay.
    public var isSharedBucket: Bool = false

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

/// Kind of asset a StreamingComponent loads/unloads.
///
/// Determines which loader `GeometryStreamingSystem.loadMesh`/`unloadMesh` dispatch to.
/// `.mesh` goes through the existing `.untold`/OCC mesh pipeline; `.gaussianSplat` goes
/// through `setEntityGaussianAsync`/`unloadGaussian`. The distance/radius scheduling,
/// concurrency, and memory-budget eviction logic in `GeometryStreamingSystem` is shared
/// across both kinds.
public enum StreamingAssetKind {
    case mesh
    case gaussianSplat
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

    /// File extension (e.g., "usdz", or "ply" for gaussian splats)
    public var assetExtension: String = ""

    /// Optional: specific mesh name within the asset
    public var assetName: String?

    /// Which loader this entity streams through. See `StreamingAssetKind`.
    public var assetKind: StreamingAssetKind = .mesh

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
        priority: Int = 0,
        assetKind: StreamingAssetKind = .mesh
    ) {
        self.init()
        assetFilename = filename
        assetExtension = ext
        self.streamingRadius = streamingRadius
        self.unloadRadius = unloadRadius
        self.priority = priority
        self.assetKind = assetKind
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
