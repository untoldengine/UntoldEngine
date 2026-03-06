//
//  Mesh+GPUMemory.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit

public extension Mesh {
    /// Calculate total GPU memory used by this mesh in bytes
    var gpuMemorySize: Int {
        var totalSize = 0

        // Vertex buffers
        for vertexBuffer in metalKitMesh.vertexBuffers {
            totalSize += vertexBuffer.buffer.length
        }

        // Index buffers from submeshes
        for submesh in metalKitMesh.submeshes {
            totalSize += submesh.indexBuffer.buffer.length
        }

        // Uniform buffers (space uniforms for transforms)
        for buffer in spaceUniform {
            if let buffer {
                totalSize += buffer.length
            }
        }

        // Skin buffers (if skeletal mesh)
        if let skin {
            totalSize += skin.gpuMemorySize
        }

        return totalSize
    }

    /// Calculate texture memory used by this mesh's materials
    var textureMemorySize: Int {
        var totalSize = 0

        for submesh in submeshes {
            totalSize += submesh.textureMemorySize
        }

        return totalSize
    }

    /// Total GPU memory including textures
    var totalGPUMemorySize: Int {
        gpuMemorySize + textureMemorySize
    }
}

// MARK: - SubMesh GPU Memory

public extension SubMesh {
    /// Calculate texture memory used by this submesh's material
    var textureMemorySize: Int {
        var totalSize = 0

        guard let material else { return 0 }

        // Base color texture
        if let texture = material.baseColor.texture {
            totalSize += texture.allocatedSize
        }

        // Normal map
        if let texture = material.normal.texture {
            totalSize += texture.allocatedSize
        }

        // Metallic texture
        if let texture = material.metallic.texture {
            totalSize += texture.allocatedSize
        }

        // Roughness texture
        if let texture = material.roughness.texture {
            totalSize += texture.allocatedSize
        }

        return totalSize
    }
}

// MARK: - Skin GPU Memory

extension Skin {
    /// Calculate GPU memory used by skin buffers
    var gpuMemorySize: Int {
        var totalSize = 0

        // Joint transforms buffer
        if let buffer = jointTransformsBuffer {
            totalSize += buffer.length
        }

        return totalSize
    }
}

// MARK: - Utility Functions

/// Calculate total GPU memory for an array of meshes
public func calculateMeshArrayMemory(_ meshes: [Mesh]) -> Int {
    meshes.reduce(0) { $0 + $1.gpuMemorySize }
}

/// Calculate total GPU memory including textures for an array of meshes
public func calculateMeshArrayTotalMemory(_ meshes: [Mesh]) -> Int {
    meshes.reduce(0) { $0 + $1.totalGPUMemorySize }
}

// MARK: - Memory Formatting Helpers

public extension Int {
    /// Format bytes as human-readable string (KB, MB, GB)
    var formattedAsMemory: String {
        let kb = 1024
        let mb = kb * 1024
        let gb = mb * 1024

        if self >= gb {
            return String(format: "%.2f GB", Double(self) / Double(gb))
        } else if self >= mb {
            return String(format: "%.2f MB", Double(self) / Double(mb))
        } else if self >= kb {
            return String(format: "%.2f KB", Double(self) / Double(kb))
        } else {
            return "\(self) bytes"
        }
    }
}
