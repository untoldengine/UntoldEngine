//
//  AssetLoadingPolicy.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// MARK: - Geometry Residency Policy

/// Controls how an asset's geometry (vertex and index buffers) is managed in GPU memory.
public enum GeometryResidencyPolicy: String, Sendable {
    /// Upload all geometry immediately during registration.
    /// The mesh is permanently resident and is never evicted by the streaming system.
    /// Prefer for assets where total geometry is small relative to the platform memory budget.
    case eager

    /// Register leaf meshes as zero-GPU stub entities.
    /// `GeometryStreamingSystem` uploads each stub from CPU RAM when the camera enters
    /// `streamingRadius` and evicts it when the camera moves beyond `unloadRadius`.
    /// No GPU allocation happens at registration time.
    case streaming
}

// MARK: - Texture Residency Policy

/// Controls how an asset's textures are managed in GPU memory.
public enum TextureResidencyPolicy: String, Sendable {
    /// Load and cap textures at import time using `TextureLoader.maxTextureDimension`.
    /// `TextureStreamingSystem` may still adjust resolution by camera distance at runtime.
    case eager

    /// `TextureStreamingSystem` manages resolution tiers by camera distance.
    /// Textures are upgraded toward full resolution when the camera is close and
    /// downgraded to lower tiers when it moves away, subject to the memory budget.
    case streaming
}

// MARK: - Asset Loading Policy

/// The combined per-asset loading policy that controls both geometry and texture residency.
///
/// When `source == .auto` this policy was computed by `AssetProfiler` from signals such as
/// estimated geometry bytes, estimated texture bytes, mesh count, and the platform memory
/// budget. When `source == .userForced` it was constructed directly from a caller-supplied
/// `MeshStreamingPolicy`.
///
/// ## Typical combinations
/// | Geometry | Texture | When to use |
/// |---|---|---|
/// | `.eager` | `.eager` | Small asset; fits comfortably in the budget |
/// | `.streaming` | `.eager` | Geometry-dominated; many meshes or large vertex data |
/// | `.eager` | `.streaming` | Texture-dominated; few meshes but large textures |
/// | `.streaming` | `.streaming` | Mixed or very large asset; both domains are significant |
public struct AssetLoadingPolicy: Sendable {
    /// Controls geometry (vertex/index buffer) residency.
    public var geometryPolicy: GeometryResidencyPolicy

    /// Controls texture residency.
    public var texturePolicy: TextureResidencyPolicy

    /// Whether this policy was computed automatically or forced by the caller.
    public var source: PolicySource

    public enum PolicySource: String, Sendable {
        case auto
        case userForced
    }

    public init(
        geometry: GeometryResidencyPolicy,
        texture: TextureResidencyPolicy,
        source: PolicySource = .userForced
    ) {
        geometryPolicy = geometry
        texturePolicy = texture
        self.source = source
    }

    // MARK: - Presets

    /// Full eager load: all geometry and textures uploaded immediately at registration time.
    public static var fullLoad: AssetLoadingPolicy {
        AssetLoadingPolicy(geometry: .eager, texture: .eager)
    }

    /// Geometry streaming only: stubs registered; textures loaded eagerly at first GPU upload.
    public static var geometryStreaming: AssetLoadingPolicy {
        AssetLoadingPolicy(geometry: .streaming, texture: .eager)
    }

    /// Texture streaming only: geometry uploaded immediately; textures streamed by distance.
    public static var textureStreaming: AssetLoadingPolicy {
        AssetLoadingPolicy(geometry: .eager, texture: .streaming)
    }

    /// Combined streaming: geometry stubs registered and textures streamed by distance.
    public static var combinedStreaming: AssetLoadingPolicy {
        AssetLoadingPolicy(geometry: .streaming, texture: .streaming)
    }
}
