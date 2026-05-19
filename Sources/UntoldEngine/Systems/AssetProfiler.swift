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

// MARK: - Asset Profile

/// A lightweight snapshot of an asset's composition used to select the optimal loading policy.
public struct AssetProfile: Sendable {
    // MARK: Byte Estimates

    /// On-disk file size in bytes.
    public let totalFileBytes: Int

    /// Estimated GPU geometry footprint: vertex + index buffers summed across all meshes.
    public let estimatedGeometryBytes: Int

    /// Estimated GPU texture footprint.
    public let estimatedTextureBytes: Int

    // MARK: Structural Signals

    /// Number of top-level mesh objects in the parsed asset.
    public let meshCount: Int

    /// Total number of material slots encountered across all meshes.
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

/// Classifies asset loading policy from an `AssetProfile` and the current memory budget.
public enum AssetProfiler {
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
}
