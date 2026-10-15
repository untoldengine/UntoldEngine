//
//  RenderInstancing.swift
//  UntoldEngine
//
//  Instanced draws: entities that draw the same meshes with the same materials are
//  encoded as one draw, with a record per instance.
//
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

/// Instanced drawing as a whole.
///
/// A scene that places one model many times (the chairs of a hall, the trees of a site)
/// asks for the same draw over and over with a different transform. The opaque pass and
/// the shadow cascades gather the entities that draw the same thing and encode one draw
/// for all of them: the meshes and the material are bound once, and each instance reads
/// its transform from a buffer.
enum InstancedDrawing {
    /// Whether the passes draw instanced. Off, every entity is encoded on its own, as
    /// before. Set with `setRendering(.instancedDraws(_:))`.
    nonisolated(unsafe) static var isEnabled = true

    /// Whether `device` can draw instanced the way the passes do: each draw starts at a
    /// record of its own in a buffer the pass binds once (its base instance), which
    /// every Mac and every Apple GPU from the A9 on can do. On an older one the instanced
    /// pipelines are not made, and the passes draw entity by entity.
    static func isSupported(by device: MTLDevice) -> Bool {
        device.supportsFamily(.apple3) || device.supportsFamily(.mac2)
    }
}

/// The current value set via `setRendering(.instancedDraws(_:))`.
public func getInstancedDrawsEnabled() -> Bool {
    InstancedDrawing.isEnabled
}

/// What a render component draws, as a number: see `RenderInstanceKeyTable`.
struct RenderInstanceKey: Equatable {
    /// The generation of the table the key was looked up in. A key of another generation
    /// says nothing.
    var generation: UInt32
    /// The number of what the component draws, or `notInstanced`.
    var id: Int32

    /// The id of a component that is drawn on its own.
    static let notInstanced: Int32 = -1
    /// The key of a component nobody has looked at since its meshes last changed.
    static let unresolved = RenderInstanceKey(generation: 0, id: notInstanced)
}

/// One draw of an instanced group in the opaque pass: a submesh, with everything the
/// encoder is handed for it.
///
/// It is made from the submesh's material once, when a component first stands for its
/// group, and kept by the component until its meshes change. Two things read it: the
/// encoder, which binds exactly these values, and `MeshListDescription`, which decides
/// from the same values whether two materials are the same. A value an instanced draw
/// is to bind is added here and to `MeshListDescription.addMaterial(of:)`.
struct InstancedSubmeshDraw {
    let meshIndex: Int32

    let primitiveType: MTLPrimitiveType
    let indexCount: Int
    let indexType: MTLIndexType
    let indexBuffer: MTLBuffer
    let indexBufferOffset: Int

    let baseColorTexture: MTLTexture?
    let roughnessTexture: MTLTexture?
    let metallicTexture: MTLTexture?
    let normalTexture: MTLTexture?
    let heightTexture: MTLTexture?
    let emissiveTexture: MTLTexture?
    let baseColorSampler: MTLSamplerState?
    /// The sampler of the roughness and metallic textures.
    let materialSampler: MTLSamplerState?
    let normalSampler: MTLSamplerState?
    let heightSampler: MTLSamplerState?

    let stScale: Float
    let hasNormal: Bool
    let normalIsPackedXY: Bool
    /// The material's parameter block. Its `passthroughAlpha` and `lodDither` are not
    /// used: an instance takes its opacity from its record and has no dither.
    let parameters: MaterialParametersUniform

    /// The draw of `submesh`, whose material is `material`: one the opaque pass draws.
    init(meshIndex: Int, submesh: borrowing SubMesh, material: borrowing Material) {
        self.meshIndex = Int32(meshIndex)
        primitiveType = submesh.primitiveType
        indexCount = submesh.indexCount
        indexType = submesh.indexType
        indexBuffer = submesh.indexBuffer
        indexBufferOffset = submesh.indexBufferOffset

        baseColorTexture = material.baseColor.texture
        roughnessTexture = material.roughness.texture
        metallicTexture = material.metallic.texture
        normalTexture = material.normal.texture
        heightTexture = material.height.texture
        emissiveTexture = material.emissive.texture
        baseColorSampler = material.baseColor.sampler
        materialSampler = material.roughness.sampler
        normalSampler = material.normal.sampler
        heightSampler = material.height.sampler

        stScale = material.stScale
        hasNormal = material.normal.texture != nil
        normalIsPackedXY = material.normalIsPackedXY
        parameters = RenderPasses.opaqueMaterialParameters(of: material)
    }

    /// The draws of `meshes` in the opaque pass, in the order they are encoded: every
    /// submesh that has a material and is not blended.
    static func draws(of meshes: [Mesh]) -> [InstancedSubmeshDraw] {
        var draws: [InstancedSubmeshDraw] = []
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                // A material that is blended or lets light through belongs to the
                // transparency pass.
                guard let material = meshes[meshIndex].submeshes[submeshIndex].material,
                      !material.hasTransparency
                else { continue }
                draws.append(InstancedSubmeshDraw(
                    meshIndex: meshIndex,
                    submesh: meshes[meshIndex].submeshes[submeshIndex],
                    material: material
                ))
            }
        }
        return draws
    }
}

/// One draw of an instanced group in a shadow pass: the index data of a submesh that
/// casts. Glass casts no shadow, so its submeshes are not among them.
struct InstancedShadowDraw {
    let meshIndex: Int32
    let primitiveType: MTLPrimitiveType
    let indexCount: Int
    let indexType: MTLIndexType
    let indexBuffer: MTLBuffer
    let indexBufferOffset: Int

    /// The shadow draws of `meshes`, in the order they are encoded.
    static func draws(of meshes: [Mesh]) -> [InstancedShadowDraw] {
        var draws: [InstancedShadowDraw] = []
        for meshIndex in meshes.indices {
            for submeshIndex in meshes[meshIndex].submeshes.indices {
                if let material = meshes[meshIndex].submeshes[submeshIndex].material, material.transmitsLight {
                    continue
                }
                draws.append(InstancedShadowDraw(
                    meshIndex: Int32(meshIndex),
                    primitiveType: meshes[meshIndex].submeshes[submeshIndex].primitiveType,
                    indexCount: meshes[meshIndex].submeshes[submeshIndex].indexCount,
                    indexType: meshes[meshIndex].submeshes[submeshIndex].indexType,
                    indexBuffer: meshes[meshIndex].submeshes[submeshIndex].indexBuffer,
                    indexBufferOffset: meshes[meshIndex].submeshes[submeshIndex].indexBufferOffset
                ))
            }
        }
        return draws
    }
}

/// What a mesh list sends to the GPU in an opaque draw, as a list of words that two mesh
/// lists have in common exactly when their entities can share a draw.
///
/// The words name the Metal meshes, their local transforms and, for every submesh, its
/// index data and what the pass binds for its material (`InstancedSubmeshDraw`): the
/// textures and samplers by identity, the values bit for bit. What differs between two
/// entities that share a draw (the world transform, the opacity of a ghost channel) is
/// not part of it.
struct MeshListDescription {
    private(set) var words: [UInt64] = []

    /// Describes `meshes`. Returns false, leaving `words` unusable, for a list that is
    /// always drawn on its own: one that is empty or draws nothing in the opaque pass.
    ///
    /// Whether the vertices are the entity's own (a skeleton, a deformation) is not the
    /// mesh list's to say: every mesh carries a skin, used or not. The passes ask the
    /// entity, and draw one that has either on its own.
    mutating func describe(_ meshes: [Mesh]) -> Bool {
        words.removeAll(keepingCapacity: true)
        guard !meshes.isEmpty else { return false }

        var drawsOpaque = false
        for meshIndex in meshes.indices {
            add(identityOf: meshes[meshIndex].metalKitMesh)
            add(meshes[meshIndex].localSpace)
            words.append(UInt64(meshes[meshIndex].submeshes.count))

            for submeshIndex in meshes[meshIndex].submeshes.indices {
                // The index data, which a shadow draw reads for every submesh.
                add(identityOf: meshes[meshIndex].submeshes[submeshIndex].metalKitSubmesh)
                guard let material = meshes[meshIndex].submeshes[submeshIndex].material else {
                    words.append(Self.noMaterial)
                    continue
                }
                // The transparency pass draws a blended submesh and one that lets light
                // through, entity by entity. The second casts no shadow, which two
                // components that share a shadow draw have to agree on.
                if material.hasTransparency {
                    words.append(material.transmitsLight ? Self.transmittingMaterial : Self.blendedMaterial)
                    continue
                }
                words.append(Self.opaqueMaterial)
                addMaterial(of: InstancedSubmeshDraw(
                    meshIndex: meshIndex,
                    submesh: meshes[meshIndex].submeshes[submeshIndex],
                    material: material
                ))
                drawsOpaque = true
            }
        }
        return drawsOpaque
    }

    var hash: Int {
        // FNV-1a over the words.
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for word in words {
            hash = (hash ^ word) &* 0x0000_0100_0000_01B3
        }
        return Int(truncatingIfNeeded: hash)
    }

    private static let noMaterial: UInt64 = 0
    private static let blendedMaterial: UInt64 = 1
    private static let opaqueMaterial: UInt64 = 2
    private static let transmittingMaterial: UInt64 = 3

    /// Everything of the material that `draw` binds. A value left out here would let two
    /// different materials share a draw: `RenderInstanceKeyTests` checks the parameter
    /// block against the list below, field by field.
    private mutating func addMaterial(of draw: borrowing InstancedSubmeshDraw) {
        add(identityOf: draw.baseColorTexture)
        add(identityOf: draw.roughnessTexture)
        add(identityOf: draw.metallicTexture)
        add(identityOf: draw.normalTexture)
        add(identityOf: draw.heightTexture)
        add(identityOf: draw.emissiveTexture)
        add(identityOf: draw.baseColorSampler)
        add(identityOf: draw.materialSampler)
        add(identityOf: draw.normalSampler)
        add(identityOf: draw.heightSampler)
        add(draw.stScale, (draw.hasNormal ? 1 : 0) + (draw.normalIsPackedXY ? 2 : 0))

        add(draw.parameters.baseColor)
        add(draw.parameters.hasTexture)
        add(draw.parameters.textureChannels)
        add(draw.parameters.edgeTint)
        add(simd_float4(draw.parameters.emmissive, 0))
        add(draw.parameters.roughness, draw.parameters.specular)
        add(draw.parameters.subsurface, draw.parameters.metallic)
        add(draw.parameters.specularTint, draw.parameters.anisotropic)
        add(draw.parameters.sheen, draw.parameters.sheenTint)
        add(draw.parameters.clearCoat, draw.parameters.clearCoatGloss)
        add(draw.parameters.ior, draw.parameters.alphaCutoff)
        add(draw.parameters.heightScale, draw.parameters.heightMidlevel)
        add(draw.parameters.heightRemapMin, draw.parameters.heightRemapMax)
        add(draw.parameters.normalScale, draw.parameters.interactWithLight ? 1 : 0)
        add(draw.parameters.transmission, 0)
        words.append(
            UInt64(UInt32(bitPattern: draw.parameters.alphaMode))
                | (UInt64(UInt32(bitPattern: draw.parameters.hasEmissiveTexture)) << 32)
        )
        // Not here: passthroughAlpha and lodDither, which an instanced draw does not take
        // from the material's parameter block.
    }

    @inline(__always)
    private mutating func add(identityOf object: AnyObject?) {
        words.append(object.map { UInt64(UInt(bitPattern: ObjectIdentifier($0))) } ?? 0)
    }

    @inline(__always)
    private mutating func add(_ first: Float, _ second: Float) {
        words.append(UInt64(first.bitPattern) | (UInt64(second.bitPattern) << 32))
    }

    @inline(__always)
    private mutating func add(_ value: simd_float4) {
        add(value.x, value.y)
        add(value.z, value.w)
    }

    @inline(__always)
    private mutating func add(_ value: simd_int4) {
        words.append(UInt64(UInt32(bitPattern: value.x)) | (UInt64(UInt32(bitPattern: value.y)) << 32))
        words.append(UInt64(UInt32(bitPattern: value.z)) | (UInt64(UInt32(bitPattern: value.w)) << 32))
    }

    @inline(__always)
    private mutating func add(_ matrix: simd_float4x4) {
        add(matrix.columns.0)
        add(matrix.columns.1)
        add(matrix.columns.2)
        add(matrix.columns.3)
    }
}

/// Gives every distinct thing a render component can draw a number.
///
/// Two components get the same number exactly when their mesh lists have the same
/// `MeshListDescription`. Their entities can then share a draw: only what an instance has
/// of its own differs. The table compares the descriptions themselves, not hashes of
/// them, so two different materials never share a number.
///
/// A description names its meshes and textures by identity and does not keep them alive.
/// That is sound because a component holds on to everything its key was made from for as
/// long as it has the key: whatever changes `RenderComponent.mesh` clears it.
///
/// Descriptions are not removed one by one. A long session leaves old ones behind
/// (a material edited, a texture streamed in); once the table has outgrown
/// `maximumDescriptions`, `beginPass` empties it and starts a new generation, and the keys
/// of the old one are looked up again as their entities are drawn.
final class RenderInstanceKeyTable: @unchecked Sendable {
    static let shared = RenderInstanceKeyTable()

    /// Past this many descriptions the next pass starts with an empty table.
    static let maximumDescriptions = 1 << 16

    private let lock = NSLock()
    private var generation: UInt32 = 1
    private var descriptions: [[UInt64]] = []
    private var idsByHash: [Int: [Int32]] = [:]
    private var scratch = MeshListDescription()

    /// The generation a key must have to be used in the pass that is starting. The table
    /// is emptied here when it has outgrown its limit, and nowhere else: the ids a pass
    /// has collected stay good until the pass ends.
    func beginPass() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        if descriptions.count > Self.maximumDescriptions {
            removeAllLocked()
        }
        return generation
    }

    /// The id of what `component` draws, or `RenderInstanceKey.notInstanced`. Looks it up
    /// and leaves it in the component's `instanceKey` when the key is not of this
    /// generation.
    func resolve(_ component: RenderComponent) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        if component.instanceKey.generation == generation {
            return component.instanceKey.id
        }
        let id = idLocked(for: component.mesh)
        component.instanceKey = RenderInstanceKey(generation: generation, id: id)
        return id
    }

    /// The id of what `meshes` draws, without a component to cache it in.
    func id(for meshes: [Mesh]) -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        return idLocked(for: meshes)
    }

    /// The number of descriptions the table holds.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return descriptions.count
    }

    /// The generation keys are being given in.
    var currentGeneration: UInt32 {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    /// Empties the table and starts a new generation: every key given so far is stale.
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        removeAllLocked()
    }

    private func removeAllLocked() {
        descriptions.removeAll(keepingCapacity: true)
        idsByHash.removeAll(keepingCapacity: true)
        // Zero is the generation of an unresolved key.
        generation = generation == .max ? 1 : generation + 1
    }

    private func idLocked(for meshes: [Mesh]) -> Int32 {
        guard scratch.describe(meshes) else { return RenderInstanceKey.notInstanced }

        let hash = scratch.hash
        if let candidates = idsByHash[hash] {
            for candidate in candidates where descriptions[Int(candidate)] == scratch.words {
                return candidate
            }
        }
        let id = Int32(descriptions.count)
        descriptions.append(scratch.words)
        idsByHash[hash, default: []].append(id)
        return id
    }
}

/// The entities one pass draws instanced, grouped by what they draw.
///
/// The pass adds each entity with the id of its key and its world transform, lays the
/// groups out, writes a record per instance and encodes the draws of each group. A group
/// of one is a draw like any other. The list is kept between passes, so once its arrays
/// have grown a frame allocates nothing.
///
/// A group needs a run of records per distinct local transform among its meshes: the
/// model matrix of an instance is its world transform times the mesh's local one. Meshes
/// that follow each other with the same local transform (nearly always all of them)
/// share a run.
struct InstancedDrawList {
    struct Group {
        let keyID: Int32
        /// The opacity of the group's entities on a ghost channel, 1 for any other. It is
        /// the draw's (the material parameters carry it), so entities that differ in it
        /// are in groups of their own.
        let passthroughAlpha: Float
        var instanceCount: Int32 = 0
        /// Index of the first record of the group's first run.
        var firstRecord: Int32 = 0
        /// Where the group's runs start in `runLocalSpaces`.
        var firstRun: Int32 = 0
        var runCount: Int32 = 0
        /// Where the run of each of the group's meshes starts in `meshRuns`.
        var firstMesh: Int32 = 0
        /// Instances whose records are written.
        var written: Int32 = 0
    }

    private(set) var groups: [Group] = []
    /// One component of each group: every other one draws the same meshes and materials.
    private(set) var groupComponents: [RenderComponent] = []
    /// The local transform of each run of each group.
    private(set) var runLocalSpaces: [simd_float4x4] = []
    /// For each mesh of each group, which of the group's runs it reads.
    private(set) var meshRuns: [Int32] = []
    /// Records the pass has to write, known after `layOutRecords`.
    private(set) var recordCount = 0

    /// By key id, the index plus one of the group of the entities drawn opaque (opacity
    /// 1, nearly every entity), or zero.
    private var groupOfKey: [Int32] = []
    /// The same for the entities on a ghost channel, by key id and opacity.
    private var groupOfGhostKey: [GhostGroupKey: Int32] = [:]
    private var instanceGroups: [Int32] = []
    private var instanceSpaces: [simd_float4x4] = []
    /// Where each instance was the previous frame (its space, when it did not move).
    private var instancePreviousSpaces: [simd_float4x4] = []

    private struct GhostGroupKey: Hashable {
        let keyID: Int32
        let passthroughAlpha: Float
    }

    var isEmpty: Bool {
        instanceGroups.isEmpty
    }

    var instanceCount: Int {
        instanceGroups.count
    }

    /// Adds an entity. `keyID` is the id of `component`'s key and is not negative.
    /// `previousSpace` is the world transform the entity was drawn with the previous frame,
    /// for the velocity the opaque pass writes; nil says it is where it was (a shadow pass
    /// passes none). `passthroughAlpha` is the entity's opacity on a ghost channel: an
    /// entity joins the group of its key with that opacity.
    @inline(__always)
    mutating func add(
        keyID: Int32,
        component: RenderComponent,
        space: simd_float4x4,
        previousSpace: simd_float4x4? = nil,
        passthroughAlpha: Float = 1
    ) {
        var group: Int32
        if passthroughAlpha == 1 {
            let key = Int(keyID)
            if key >= groupOfKey.count {
                groupOfKey.append(contentsOf: repeatElement(0, count: max(key + 1 - groupOfKey.count, 1024)))
            }
            group = groupOfKey[key]
            if group == 0 {
                groups.append(Group(keyID: keyID, passthroughAlpha: 1))
                groupComponents.append(component)
                group = Int32(groups.count)
                groupOfKey[key] = group
            }
        } else {
            let ghostKey = GhostGroupKey(keyID: keyID, passthroughAlpha: passthroughAlpha)
            if let known = groupOfGhostKey[ghostKey] {
                group = known
            } else {
                groups.append(Group(keyID: keyID, passthroughAlpha: passthroughAlpha))
                groupComponents.append(component)
                group = Int32(groups.count)
                groupOfGhostKey[ghostKey] = group
            }
        }
        groups[Int(group) - 1].instanceCount += 1
        instanceGroups.append(group - 1)
        instanceSpaces.append(space)
        instancePreviousSpaces.append(previousSpace ?? space)
    }

    /// Empties the list for the next pass, keeping its storage.
    mutating func removeAll() {
        for group in groups where group.passthroughAlpha == 1 {
            groupOfKey[Int(group.keyID)] = 0
        }
        groupOfGhostKey.removeAll(keepingCapacity: true)
        groups.removeAll(keepingCapacity: true)
        groupComponents.removeAll(keepingCapacity: true)
        runLocalSpaces.removeAll(keepingCapacity: true)
        meshRuns.removeAll(keepingCapacity: true)
        instanceGroups.removeAll(keepingCapacity: true)
        instanceSpaces.removeAll(keepingCapacity: true)
        instancePreviousSpaces.removeAll(keepingCapacity: true)
        recordCount = 0
    }

    /// Decides where each group's records go. Call once every entity is added.
    mutating func layOutRecords() {
        runLocalSpaces.removeAll(keepingCapacity: true)
        meshRuns.removeAll(keepingCapacity: true)

        var nextRecord: Int32 = 0
        for groupIndex in groups.indices {
            let meshes = groupComponents[groupIndex].mesh
            groups[groupIndex].firstRun = Int32(runLocalSpaces.count)
            groups[groupIndex].firstMesh = Int32(meshRuns.count)

            var runCount: Int32 = 0
            for meshIndex in meshes.indices {
                if runCount == 0 || runLocalSpaces[runLocalSpaces.count - 1] != meshes[meshIndex].localSpace {
                    runLocalSpaces.append(meshes[meshIndex].localSpace)
                    runCount += 1
                }
                meshRuns.append(runCount - 1)
            }

            groups[groupIndex].runCount = runCount
            groups[groupIndex].firstRecord = nextRecord
            groups[groupIndex].written = 0
            nextRecord += runCount * groups[groupIndex].instanceCount
        }
        recordCount = Int(nextRecord)
    }

    /// The record the first instance of `group` reads when it draws its mesh `meshIndex`:
    /// the base instance of that draw.
    @inline(__always)
    func baseInstance(of group: Group, meshIndex: Int) -> Int {
        Int(group.firstRecord + meshRuns[Int(group.firstMesh) + meshIndex] * group.instanceCount)
    }

    /// Writes the records of the opaque pass: `records` has room for `recordCount`. The
    /// matrices are the ones the pass computes for an entity it draws on its own, the
    /// previous frame's model matrix included.
    mutating func writeModelRecords(to records: UnsafeMutablePointer<ModelInstanceUniform>, viewMatrix: simd_float4x4) {
        for instance in instanceGroups.indices {
            let groupIndex = Int(instanceGroups[instance])
            let slot = groups[groupIndex].written
            groups[groupIndex].written = slot + 1

            let space = instanceSpaces[instance]
            let previousSpace = instancePreviousSpaces[instance]
            let firstRun = Int(groups[groupIndex].firstRun)
            var record = Int(groups[groupIndex].firstRecord + slot)
            for run in 0 ..< Int(groups[groupIndex].runCount) {
                let localSpace = runLocalSpaces[firstRun + run]
                let modelMatrix = simd_mul(space, localSpace)
                records[record] = ModelInstanceUniform(
                    modelViewMatrix: simd_mul(viewMatrix, modelMatrix),
                    modelMatrix: modelMatrix,
                    prevModelMatrix: simd_mul(previousSpace, localSpace),
                    normalMatrix: matrix3x3_upper_left(modelMatrix).inverse.transpose
                )
                record += Int(groups[groupIndex].instanceCount)
            }
        }
    }

    /// Writes the records of a shadow pass, a model matrix per instance: `records` has
    /// room for `recordCount`.
    mutating func writeShadowRecords(to records: UnsafeMutablePointer<simd_float4x4>) {
        for instance in instanceGroups.indices {
            let groupIndex = Int(instanceGroups[instance])
            let slot = groups[groupIndex].written
            groups[groupIndex].written = slot + 1

            let space = instanceSpaces[instance]
            let firstRun = Int(groups[groupIndex].firstRun)
            var record = Int(groups[groupIndex].firstRecord + slot)
            for run in 0 ..< Int(groups[groupIndex].runCount) {
                records[record] = simd_mul(space, runLocalSpaces[firstRun + run])
                record += Int(groups[groupIndex].instanceCount)
            }
        }
    }
}

/// The buffers that hold the instance records of the frames being drawn.
///
/// A pass borrows a buffer, fills it, and its command buffer's completion handler hands
/// it back: a buffer is never written while the GPU may still read it, however many
/// frames are in flight. The handler gets a token, not the buffer, so nothing that is
/// not `Sendable` crosses into it.
final class InstanceRecordBufferPool: @unchecked Sendable {
    static let shared = InstanceRecordBufferPool()

    /// The smallest buffer the pool makes.
    static let minimumLength = 64 * 1024
    /// Free buffers kept for the next frames; a scene that shrinks gives the rest back.
    static let maximumFreeBuffers = 8

    private let lock = NSLock()
    private var free: [MTLBuffer] = []
    private var lent: [Int: MTLBuffer] = [:]
    private var nextToken = 0

    /// A buffer of at least `length` bytes and the token that returns it, or nil when
    /// the device cannot make one.
    func borrow(length: Int, device: MTLDevice) -> (buffer: MTLBuffer, token: Int)? {
        lock.lock()
        defer { lock.unlock() }

        // The smallest free buffer that is large enough.
        var best: Int?
        for index in free.indices where free[index].length >= length && free[index].device === device {
            if let current = best, free[current].length <= free[index].length { continue }
            best = index
        }

        let buffer: MTLBuffer
        if let best {
            buffer = free.remove(at: best)
        } else {
            var capacity = Self.minimumLength
            while capacity < length {
                capacity *= 2
            }
            guard let made = device.makeBuffer(length: capacity, options: .storageModeShared) else { return nil }
            made.label = "Instance Records"
            buffer = made
        }

        let token = nextToken
        nextToken &+= 1
        lent[token] = buffer
        return (buffer, token)
    }

    /// Hands back the buffer borrowed with `token`.
    func giveBack(_ token: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard let buffer = lent.removeValue(forKey: token) else { return }
        free.append(buffer)
        if free.count > Self.maximumFreeBuffers,
           let smallest = free.indices.min(by: { free[$0].length < free[$1].length })
        {
            free.remove(at: smallest)
        }
    }

    /// Buffers free and lent, for tests.
    var bufferCounts: (free: Int, lent: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (free.count, lent.count)
    }
}
