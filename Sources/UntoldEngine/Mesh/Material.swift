import MetalKit

struct Material {
    var baseColor: MTLTexture?
    var roughness: MTLTexture?
    var metallic: MTLTexture?
    var normal: MTLTexture?

    // Texture URLs
    var baseColorURL: URL?
    var roughnessURL: URL?
    var metallicURL: URL?
    var normalURL: URL?

    // Default values
    var baseColorValue: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var roughnessValue: Float = 1.0
    var metallicValue: Float = 0.0

    // Disney material properties
    var specular: Float = 0.0
    var specularTint: Float = 0.0
    var subsurface: Float = 0.0
    var anisotropic: Float = 0.0
    var sheen: Float = 0.0
    var sheenTint: Float = 0.0
    var clearCoat: Float = 0.0
    var clearCoatGloss: Float = 0.0
    var ior: Float = 1.5
    var emit: Bool = false
    var interactWithLight: Bool = true

    // Texture presence flags
    var hasNormalMap: Bool { normal != nil }
    var hasBaseMap: Bool { baseColor != nil }
    var hasRoughMap: Bool { roughness != nil }
    var hasMetalMap: Bool { metallic != nil }

    init(mdlMaterial: MDLMaterial, textureLoader: MTKTextureLoader) {
        // Load textures and set URLs
        baseColor = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .baseColor,
            textureLoader: textureLoader,
            isSRGB: true,
            outputURL: &baseColorURL
        ) ?? loadDefaultColor(for: mdlMaterial.property(with: .baseColor), defaultColor: &baseColorValue)

        normal = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .tangentSpaceNormal,
            textureLoader: textureLoader,
            isSRGB: false,
            outputURL: &normalURL
        )

        roughness = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .roughness,
            textureLoader: textureLoader,
            isSRGB: false,
            outputURL: &roughnessURL
        ) ?? loadDefaultFloat(for: mdlMaterial.property(with: .roughness), defaultValue: &roughnessValue)

        metallic = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .metallic,
            textureLoader: textureLoader,
            isSRGB: false,
            outputURL: &metallicURL
        ) ?? loadDefaultFloat(for: mdlMaterial.property(with: .metallic), defaultValue: &metallicValue)

        // Load remaining Disney properties
        specular = mdlMaterial.property(with: .specular)?.floatValue ?? 0.0
        specularTint = mdlMaterial.property(with: .specularTint)?.floatValue ?? 0.0
        subsurface = mdlMaterial.property(with: .subsurface)?.floatValue ?? 0.0
        anisotropic = mdlMaterial.property(with: .anisotropicRotation)?.floatValue ?? 0.0
        sheenTint = mdlMaterial.property(with: .sheenTint)?.floatValue ?? 0.0
        clearCoat = mdlMaterial.property(with: .clearcoat)?.floatValue ?? 0.0
        ior = mdlMaterial.property(with: .materialIndexOfRefraction)?.floatValue ?? 1.5
    }

    // Helper function to load textures
    private static func makeTexture(
        from material: MDLMaterial,
        materialSemantic: MDLMaterialSemantic,
        textureLoader: MTKTextureLoader,
        isSRGB: Bool,
        outputURL: inout URL?
    ) -> MTLTexture? {
        for property in material.properties(with: materialSemantic) {
            let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .SRGB: isSRGB,
            ]

            if let stringValue = property.stringValue ?? property.urlValue?.absoluteString {

                if let texture = try? textureLoader.newTexture(name: stringValue, scaleFactor: 1.0, bundle: nil, options: textureLoaderOptions) {
                    outputURL = nil
                    return texture
                } else if let textureURL = property.urlValue,
                          let texture = try? textureLoader.newTexture(URL: textureURL, options: textureLoaderOptions)
                {

                    outputURL = textureURL
                    return texture
                }

                handleError(.textureMissing, stringValue)
            }
        }
        return nil
    }

    // Load a default color if the texture is not found
    private func loadDefaultColor(for property: MDLMaterialProperty?, defaultColor: inout simd_float4) -> MTLTexture? {
        if let color = property?.float4Value {
            defaultColor = color
        }
        return nil
    }

    // Load a default float value if the texture is not found
    private func loadDefaultFloat(for property: MDLMaterialProperty?, defaultValue: inout Float) -> MTLTexture? {
        if let value = property?.floatValue {
            defaultValue = value
        }
        return nil
    }
}
