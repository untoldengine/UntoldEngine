//
//  ImportExportSystem.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/12/23.
//

import Foundation
import AppKit

struct Voxel{
    let x:UInt8
    let y:UInt8
    let z:UInt8
    let colorIndex:UInt8
}

func rgbToId(_ red: UInt8, _ green: UInt8, _ blue: UInt8, _ alpha: UInt8) -> UInt8 {
    // Convert RGBA to grayscale intensity value
    let intensity = UInt8(0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue))

    // Scale the intensity value to the range 0-255
    let scaledIntensity = UInt8((255 * Double(intensity)) / 255.0)

    return scaledIntensity
}

func idToRGBA(_ charValue: UInt8) -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
    // Scale the char value back to grayscale intensity range
    let intensity = Double(charValue) * 255.0 / 255.0

    // Distribute the intensity across RGB components
    let red = UInt8(intensity)
    let green = UInt8(intensity)
    let blue = UInt8(intensity)
    let alpha: UInt8 = 255

    return (red, green, blue, alpha)
}

func exportToVoxFormat(voxels: [Voxel], chunkSize: UInt32, palette: [NSColor]) -> Data {
    var voxData = Data()
    
    // Write the VOX file header
    let header: [UInt8] = [
        0x56, 0x4F, 0x58, 0x20, 0x56, 0x4F, 0x58, 0x20, // Magic number "VOX VOX "
        0x0A, 0x00, 0x00, 0x00, // Version number (currently 150)
        0x0D, 0x0A, 0x1A, 0x0A // Chunk magic number
    ]
    voxData.append(contentsOf: header)
    
    // Calculate the number of chunks in each dimension
    let numChunksX = Int(ceil(Double(chunkSize) / 16.0))
    let numChunksY = Int(ceil(Double(chunkSize) / 16.0))
    let numChunksZ = Int(ceil(Double(chunkSize) / 16.0))
    
    // Write the PACK chunk
    let packChunkSize: UInt32 = 20
    let packChunk: [UInt8] = [
        0x50, 0x41, 0x43, 0x4B, // Chunk ID "PACK"
        UInt8(packChunkSize & 0xFF), UInt8((packChunkSize >> 8) & 0xFF), UInt8((packChunkSize >> 16) & 0xFF), UInt8((packChunkSize >> 24) & 0xFF), // Chunk size
        0x00, 0x00, 0x00, 0x00, // Child chunk size (0)
        UInt8(numChunksX & 0xFF), UInt8((numChunksX >> 8) & 0xFF), UInt8((numChunksX >> 16) & 0xFF), UInt8((numChunksX >> 24) & 0xFF), // Number of chunks in X dimension
        UInt8(numChunksY & 0xFF), UInt8((numChunksY >> 8) & 0xFF), UInt8((numChunksY >> 16) & 0xFF), UInt8((numChunksY >> 24) & 0xFF), // Number of chunks in Y dimension
        UInt8(numChunksZ & 0xFF), UInt8((numChunksZ >> 8) & 0xFF), UInt8((numChunksZ >> 16) & 0xFF), UInt8((numChunksZ >> 24) & 0xFF) // Number of chunks in Z dimension
    ]
    voxData.append(contentsOf: packChunk)
    
    // Generate and write voxel chunks
    for chunkX in 0..<numChunksX {
        for chunkY in 0..<numChunksY {
            for chunkZ in 0..<numChunksZ {
                let chunkOffsetX = chunkX * 16
                let chunkOffsetY = chunkY * 16
                let chunkOffsetZ = chunkZ * 16
                let chunkVoxels = voxels.filter { voxel in
                    let x = Int(voxel.x)
                    let y = Int(voxel.y)
                    let z = Int(voxel.z)
                    return x >= chunkOffsetX && x < chunkOffsetX + 16 &&
                           y >= chunkOffsetY && y < chunkOffsetY + 16 &&
                           z >= chunkOffsetZ && z < chunkOffsetZ + 16
                }
                let chunkData = generateChunkData(chunkVoxels, chunkSize: chunkSize, chunkOffsetX: chunkOffsetX, chunkOffsetY: chunkOffsetY, chunkOffsetZ: chunkOffsetZ)
                voxData.append(contentsOf: chunkData)
            }
        }
    }
    
    // Write the RGBA chunk
    let rgbaChunkSize: UInt32 = UInt32(palette.count) * 4 + 12
    var rgbaChunk: [UInt8] = [
        0x52, 0x47, 0x42, 0x41, // Chunk ID "RGBA"
        UInt8(rgbaChunkSize & 0xFF), UInt8((rgbaChunkSize >> 8) & 0xFF), UInt8((rgbaChunkSize >> 16) & 0xFF), UInt8((rgbaChunkSize >> 24) & 0xFF), // Chunk size
        0x00, 0x00, 0x00, 0x00 // Child chunk size (0)
    ]
    
    // Write color palette
    for color in palette {
        let components = color.cgColor.components ?? [0, 0, 0, 0]
        rgbaChunk.append(UInt8(components[0] * 255)) // Red component
        rgbaChunk.append(UInt8(components[1] * 255)) // Green component
        rgbaChunk.append(UInt8(components[2] * 255)) // Blue component
        rgbaChunk.append(UInt8(components[3] * 255)) // Alpha component
    }
    
    voxData.append(contentsOf: rgbaChunk)
    
    return voxData
}

func generateChunkData(_ voxels: [Voxel], chunkSize: UInt32, chunkOffsetX: Int, chunkOffsetY: Int, chunkOffsetZ: Int) -> [UInt8] {
    var chunkData = [UInt8]()
    
    let xyziChunkSize: UInt32 = UInt32(4 * voxels.count) + 12
    var xyziChunk: [UInt8] = [
        0x58, 0x59, 0x5A, 0x49, // Chunk ID "XYZI"
        UInt8(xyziChunkSize & 0xFF), UInt8((xyziChunkSize >> 8) & 0xFF), UInt8((xyziChunkSize >> 16) & 0xFF), UInt8((xyziChunkSize >> 24) & 0xFF), // Chunk size
        0x00, 0x00, 0x00, 0x00, // Child chunk size (0)
        UInt8(voxels.count & 0xFF), UInt8((voxels.count >> 8) & 0xFF), UInt8((voxels.count >> 16) & 0xFF), UInt8((voxels.count >> 24) & 0xFF) // Number of voxels
    ]
    
    // Write voxel data
    for voxel in voxels {
        let adjustedX = UInt8(voxel.x) - UInt8(chunkOffsetX)
        let adjustedY = UInt8(voxel.y) - UInt8(chunkOffsetY)
        let adjustedZ = UInt8(voxel.z) - UInt8(chunkOffsetZ)
        xyziChunk.append(adjustedX)
        xyziChunk.append(adjustedY)
        xyziChunk.append(adjustedZ)
        xyziChunk.append(voxel.colorIndex)
    }
    
    chunkData.append(contentsOf: xyziChunk)
    
    return chunkData
}

