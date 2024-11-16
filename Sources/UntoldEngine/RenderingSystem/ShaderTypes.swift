//
//  ShaderTypes.swift
//
//
//  Created by Harold Serrano on 11/2/24.
//

import Foundation
import simd

struct Uniforms {
    var projectionMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var viewMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var modelViewMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var normalMatrix: matrix_float3x3 = .init(diagonal: simd_float3(repeating: 1.0))
    var modelMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var cameraPosition: simd_float3? = simd_float3(repeating: 0.0)
}

struct PointLightUniform {
    var position: simd_float4
    var color: simd_float4
    var attenuation: simd_float4
    var intensity: Float
    var radius: Float
}

enum GridPassBufferIndices: Int {
    case gridPassPositionIndex
    case gridPassUniformIndex
}

enum ModelPassBufferIndices: Int {
    case modelPassVerticesIndex
    case modelPassNormalIndex
    case modelPassUVIndex
    case modelPassTangentIndex
    case modelPassJointIdIndex
    case modelPassJointWeightsIndex
    case modelPassBitangentIndex
    case modelPassUniformIndex
    case modelPassLightOrthoViewMatrixIndex
    case modelPassLightDirectionIndex
    case modelPassLightDirectionColorIndex
    case modelPassLightIntensityIndex
    case modelPassPointLightsIndex
    case modelPassPointLightsCountIndex
    case modelBaseTextureIndex
    case modelRoughnessTextureIndex
    case modelMetallicTextureIndex
    case modelNormalTextureIndex
    case shadowTextureIndex
    case modelHasNormalTextureIndex
    case modelDisneyParameterIndex
    case modelIBLIrradianceTextureIndex
    case modelIBLSpecularTextureIndex
    case modelIBLBRDFMapTextureIndex
    case modelPassBRDFIndex
    case modelPassIBLRotationAngleIndex
    case modelPassJointMatrixIndex
}

enum EnvironmentPassBufferIndices: Int {
    case envPassPositionIndex
    case envPassNormalIndex
    case envPassUVIndex
    case envPassConstantIndex
    case envPassRotationAngleIndex
}

enum ToneMapPassBufferIndices: Int {
    case toneMapPassColorTextureIndex
    case toneMapPassToneMappingIndex
}

enum ShadowBufferIndices: Int {
    case shadowModelPositionIndex
    case shadowModelUniform
    case shadowModelLightMatrixUniform
    case shadowModelLightPositionUniform
}

struct EnvironmentConstants {
    var projectionMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var viewMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var modelMatrix: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
    var environmentRotation: matrix_float4x4 = .init(diagonal: simd_float4(repeating: 1.0))
}

enum RenderTargets: Int {
    case colorTarget = 0
    case normalTarget
    case positionTarget
}

struct MaterialParametersUniform {
    var baseColor: simd_float4 = .init(repeating: 0.0)
    var hasTexture: simd_int4 = .init(repeating: 0) // x = hasBaseColor, y = hasRoughMap, z = hasMetalMap
    var edgeTint: simd_float4 = .init(repeating: 0.0)
    var roughness: Float = 0.0
    var specular: Float = 0.0
    var subsurface: Float = 0.0
    var metallic: Float = 0.0
    var specularTint: Float = 0.0
    var anisotropic: Float = 0.0
    var sheen: Float = 0.0
    var sheenTint: Float = 0.0
    var clearCoat: Float = 0.0
    var clearCoatGloss: Float = 0.0
    var ior: Float = 0.0
    var interactWithLight: Bool = true
}

struct BRDFSelectionUniform {
    var ambientIntensity: Float = 0.0
    var brdfSelection: Int = 0
    var ndfSelection: Int = 0
    var gsSelection: Int = 0
    var applyIBL: Bool = true
}
