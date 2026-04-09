//
//  AssetProfiler.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit
import ModelIO

// MARK: - Asset Profile

/// A lightweight snapshot of an asset's composition used to select the optimal loading policy.
///
/// All byte estimates are rough order-of-magnitude approximations computed at registration
/// time — no texture decompression or full GPU allocation is performed. `AssetProfiler` is
/// designed to run in < a few milliseconds inside the async registration task, well within
/// the cost of `Mesh.parseAssetAsync()` itself.
public struct AssetProfile: Sendable {
    // MARK: Byte Estimates

    /// On-disk file size in bytes.
    public let totalFileBytes: Int

    /// Estimated GPU geometry footprint: vertex + index buffers summed across all meshes.
    /// Uses the same vertex-stride formula as `CPUMeshEntry.estimatedGPUBytes`.
    public let estimatedGeometryBytes: Int

    /// Estimated GPU texture footprint. Derived from texture URL file sizes with a
    /// decompression expansion factor, or a heuristic when textures are embedded in USDZ.
    /// May be 0 if no material texture references could be resolved.
    public let estimatedTextureBytes: Int

    // MARK: Structural Signals

    /// Number of top-level `MDLMesh` objects in the parsed asset.
    public let meshCount: Int

    /// Total number of `MDLSubmesh` / material slots encountered across all meshes.
    public let materialCount: Int

    /// GPU byte estimate for the single largest individual mesh in the asset.
    public let largestSingleMeshBytes: Int

    /// `true` when the asset has ≤ 2 meshes.
    ///
    /// Monolithic assets cannot be incrementally streamed — the single mesh occupies its
    /// full GPU allocation in one step. Geometry streaming still prevents OOM at
    /// registration time, but load appearance will not be incremental.
    public let isEffectivelyMonolithic: Bool

    // MARK: Asset Character

    /// High-level classification of what dominates this asset's memory footprint.
    public let assetCharacter: AssetCharacter

    public enum AssetCharacter: String, Sendable {
        /// Textures account for > 75% of the combined geometry + texture estimate.
        /// Few or small meshes with large textures (e.g. a single hero prop with 4K maps).
        case textureDominated

        /// Geometry accounts for > 75% of the combined estimate.
        /// Many or large meshes with few or small textures (e.g. a dense city LOD mesh).
        case geometryDominated

        /// Neither domain dominates (25–75% split).
        case mixed

        /// Asset has ≤ 2 meshes. Streaming prevents OOM but won't provide incremental load-in.
        case monolithic
    }
}

// MARK: - Asset Profiler

/// Analyzes a parsed `ProgressiveAssetData` to produce an `AssetProfile` and recommend
/// the most appropriate `AssetLoadingPolicy` for the current platform memory budget.
///
/// ## Usage
/// ```swift
/// let profile = AssetProfiler.profile(url: url, assetData: assetData, fileSizeBytes: fileSize)
/// let policy  = AssetProfiler.classifyPolicy(profile: profile, budget: MemoryBudgetManager.shared.meshBudget)
/// ```
///
/// `AssetProfiler` runs after `Mesh.parseAssetAsync()` returns a `ProgressiveAssetData` and
/// before any ECS entity or GPU resource is created, so it has access to all `MDLMesh`
/// objects but no Metal allocations have occurred yet.
public enum AssetProfiler {
    // MARK: - Profile

    /// Build an `AssetProfile` from a parsed asset.
    ///
    /// - Parameters:
    ///   - url: Source URL of the asset (used only to stat on-disk size when `fileSizeBytes == 0`).
    ///   - assetData: Result of `Mesh.parseAssetAsync()`.
    ///   - fileSizeBytes: Pre-computed on-disk file size in bytes. Pass 0 to skip (estimates only).
    /// - Returns: A populated `AssetProfile`.
    static func profile(
        url _: URL,
        assetData: Mesh.ProgressiveAssetData,
        fileSizeBytes: Int
    ) -> AssetProfile {
        var totalGeometryBytes = 0
        var largestMeshBytes = 0
        var materialCount = 0
        var uniqueTextureRefs = Set<String>()
        var meshCount = 0

        for obj in assetData.topLevelObjects {
            guard let mesh = obj as? MDLMesh else { continue }
            meshCount += 1

            // Geometry estimate: vertex bytes + index bytes.
            // Identical formula to CPUMeshEntry.estimatedGPUBytes so the profiler and the
            // budget manager agree on per-mesh costs.
            let stride = Int(
                (mesh.vertexDescriptor.layouts.firstObject as? MDLVertexBufferLayout)?.stride ?? 48
            )
            let vertexBytes = mesh.vertexCount * stride
            let indexBytes = mesh.vertexCount * 3 * 4 // ~3 indices/vertex, 4 bytes each
            let meshBytes = vertexBytes + indexBytes
            totalGeometryBytes += meshBytes
            largestMeshBytes = max(largestMeshBytes, meshBytes)

            // Scan submesh materials for texture URL references.
            if let submeshes = mesh.submeshes {
                for case let submesh as MDLSubmesh in submeshes {
                    guard let material = submesh.material else { continue }
                    materialCount += 1
                    scanMaterialForTextureRefs(material, into: &uniqueTextureRefs)
                }
            }
        }

        // Estimate total texture GPU footprint from the collected URL references.
        let textureBytes = estimateTextureBytes(
            textureRefs: uniqueTextureRefs,
            fileSizeBytes: fileSizeBytes,
            geometryBytes: totalGeometryBytes
        )

        // Classify the asset's dominant memory domain.
        let isMonolithic = meshCount <= 2
        let assetCharacter: AssetProfile.AssetCharacter

        if isMonolithic {
            assetCharacter = .monolithic
        } else {
            let total = totalGeometryBytes + textureBytes
            if total == 0 {
                assetCharacter = .mixed
            } else {
                let textureFraction = Float(textureBytes) / Float(total)
                let geoFraction = Float(totalGeometryBytes) / Float(total)
                switch (textureFraction, geoFraction) {
                case let (t, _) where t > 0.75:
                    assetCharacter = .textureDominated
                case let (_, g) where g > 0.75:
                    assetCharacter = .geometryDominated
                default:
                    assetCharacter = .mixed
                }
            }
        }

        return AssetProfile(
            totalFileBytes: fileSizeBytes,
            estimatedGeometryBytes: totalGeometryBytes,
            estimatedTextureBytes: textureBytes,
            meshCount: meshCount,
            materialCount: materialCount,
            largestSingleMeshBytes: largestMeshBytes,
            isEffectivelyMonolithic: isMonolithic,
            assetCharacter: assetCharacter
        )
    }

    // MARK: - Classify Policy

    /// Recommend an `AssetLoadingPolicy` for the given profile and platform memory budget.
    ///
    /// ## Geometry policy logic
    /// Geometry streaming is selected when any of the following is true:
    /// - The asset has ≥ 50 meshes (many small meshes still spike GPU allocation without streaming).
    /// - Estimated geometry bytes exceed 30% of the platform budget.
    /// - The asset is monolithic AND geometry exceeds 30% of the budget (prevents OOM at registration).
    ///
    /// ## Texture policy logic
    /// Texture streaming is selected when estimated texture bytes exceed 10% of the budget
    /// or exceed 32 MB in absolute terms. `TextureStreamingSystem` already runs on all
    /// entities with a `RenderComponent`; this policy makes the intent explicit and will
    /// gate per-entity texture streaming in future phases.
    ///
    /// All thresholds are expressed as fractions of `budget` so the policy scales correctly
    /// across macOS (1 GB), high-end iOS (512 MB), low-end iOS (256 MB), and visionOS (512 MB).
    ///
    /// - Parameters:
    ///   - profile: The `AssetProfile` produced by `profile(url:assetData:fileSizeBytes:)`.
    ///   - budget: Current platform GPU memory budget in bytes (`MemoryBudgetManager.meshBudget`).
    /// - Returns: The recommended `AssetLoadingPolicy` with `source == .auto`.
    public static func classifyPolicy(profile: AssetProfile, budget: Int) -> AssetLoadingPolicy {
        let geometryPolicy = classifyGeometryPolicy(profile: profile, budget: budget)
        let texturePolicy = classifyTexturePolicy(profile: profile, budget: budget)
        return AssetLoadingPolicy(geometry: geometryPolicy, texture: texturePolicy, source: .auto)
    }

    // MARK: - Private: Policy Classification

    private static func classifyGeometryPolicy(
        profile: AssetProfile,
        budget: Int
    ) -> GeometryResidencyPolicy {
        let budgetFraction: Float = budget > 0
            ? Float(profile.estimatedGeometryBytes) / Float(budget)
            : 1.0

        // Monolithic assets: stream only if geometry would consume a significant budget share.
        // Streaming still prevents OOM at registration, even though the mesh loads in one step.
        if profile.isEffectivelyMonolithic {
            return budgetFraction > 0.30 ? .streaming : .eager
        }

        // Many meshes always benefit from streaming (incremental, distance-ordered upload).
        if profile.meshCount >= 50 {
            return .streaming
        }

        // Geometry footprint is significant relative to the platform budget.
        if budgetFraction > 0.30 {
            return .streaming
        }

        return .eager
    }

    private static func classifyTexturePolicy(
        profile: AssetProfile,
        budget: Int
    ) -> TextureResidencyPolicy {
        let budgetFraction: Float = budget > 0
            ? Float(profile.estimatedTextureBytes) / Float(budget)
            : 0.0

        // Stream textures when they are either significant relative to the budget
        // or exceed a fixed 32 MB floor (small budget devices may have small absolute limits).
        if budgetFraction > 0.10 || profile.estimatedTextureBytes > 32 * 1024 * 1024 {
            return .streaming
        }

        return .eager
    }

    // MARK: - Private: Texture Estimation Helpers

    /// Collect texture URL strings from an MDLMaterial's known semantic slots.
    ///
    /// Checks `urlValue` and `stringValue` for each semantic. Both regular file URLs and
    /// USDZ bracket-notation strings (e.g. `"file:///asset.usdz[0/texture.png]"`) are captured.
    private static func scanMaterialForTextureRefs(
        _ material: MDLMaterial,
        into refs: inout Set<String>
    ) {
        let textureSemantics: [MDLMaterialSemantic] = [
            .baseColor,
            .roughness,
            .metallic,
            .bump,
            .emission,
            .opacity,
            .ambientOcclusion,
        ]
        for semantic in textureSemantics {
            guard let prop = material.property(with: semantic) else { continue }
            if let url = prop.urlValue {
                refs.insert(url.absoluteString)
            } else if let str = prop.stringValue, !str.isEmpty {
                refs.insert(str)
            }
        }
    }

    /// Estimate the GPU texture footprint from a set of texture URL strings.
    ///
    /// **Regular file URLs**: stats the file and multiplies by 3× (conservative PNG/JPEG
    /// decode expansion; ASTC expands ~6–8× but is less common for external files).
    ///
    /// **USDZ-embedded textures** (bracket-notation URLs): cannot stat individual zip entries
    /// without decompressing. Uses a single heuristic: `(fileSize − geometryBytes) × 3`.
    /// This overestimates for geometry-heavy USDZs but is safe to err high (only triggers
    /// more streaming, never less).
    ///
    /// **No URLs found**: returns 0 (profiler leaves texture policy to the default).
    private static func estimateTextureBytes(
        textureRefs: Set<String>,
        fileSizeBytes: Int,
        geometryBytes: Int
    ) -> Int {
        guard !textureRefs.isEmpty else { return 0 }

        var totalBytes = 0
        var hasEmbeddedTextures = false

        for ref in textureRefs {
            if ref.contains("[") {
                // USDZ bracket-notation — embedded textures; use a file-level heuristic below.
                hasEmbeddedTextures = true
            } else if let textureURL = URL(string: ref), textureURL.isFileURL {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: textureURL.path))?[.size] as? Int ?? 0
                if textureURL.pathExtension.lowercased() == "utex" {
                    // .utex is the engine-native ASTC container: the file payload IS the GPU
                    // data (ASTC blocks transferred as-is).  No decode expansion — file size
                    // ≈ GPU allocation.  Use 1× with no multiplier.
                    totalBytes += fileSize
                } else {
                    // PNG/JPEG typically decode to 3–4× their compressed size on the GPU.
                    totalBytes += fileSize * 3
                }
            }
        }

        // For embedded USDZ textures where we cannot stat individual entries:
        // estimate total packed texture bytes as (fileSize − estimated_packed_geometry).
        // Packed geometry is roughly 1/10 of its uncompressed GPU size.
        if hasEmbeddedTextures, totalBytes == 0 {
            let estimatedPackedGeometry = geometryBytes / 10
            let estimatedPackedTextureBytes = max(0, fileSizeBytes - estimatedPackedGeometry)
            totalBytes = estimatedPackedTextureBytes * 3
        }

        return totalBytes
    }
}
