
/*
 See LICENSE folder for this sample’s licensing information.

 Abstract:
 A struct that represents a material used by a SubMesh.
 */

import MetalKit

struct Material {
    var baseColor: MTLTexture?
    var roughness: MTLTexture?
    var metallic: MTLTexture?
    var normal: MTLTexture?

    // urls
    var baseColorURL: URL?
    var roughnessURL: URL?
    var metallicURL: URL?
    var normalURL: URL?

    var baseColorValue: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    var roughnessValue: Float = 1.0
    var metallicValue: Float = 0.0

    // disney
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

    var hasNormalMap: Bool = true
    var hasBaseMap: Int = 1
    var hasRoughMap: Int = 1
    var hasMetalMap: Int = 1

    init(_ mdlMaterial: MDLMaterial, textureLoader: MTKTextureLoader) {
        baseColor = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .baseColor,
            textureLoader: textureLoader,
            isSRGB: true,
            outputURL: &baseColorURL
        )

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
        )

        metallic = Material.makeTexture(
            from: mdlMaterial,
            materialSemantic: .metallic,
            textureLoader: textureLoader,
            isSRGB: false,
            outputURL: &metallicURL
        )

        // Load base color value if texture is null
        if baseColor == nil {
            hasBaseMap = 0
            // baseColorValue=simd_float4(1.0,0.0,0.0,1.0)
            //            print("base color texture not found. Attempting to read base color value")
            baseColorValue = mdlMaterial.property(with: .baseColor)!.float4Value
            //            if let colorValue=baseColorValue{
            //                baseColor=Material.createColorTexture(from: colorValue)
            //            }
        }

        if roughness == nil {
            hasRoughMap = 0
            //            print("Rougness texture not found. Attempting to read roughness value")
            roughnessValue = mdlMaterial.property(with: .roughness)!.floatValue
            //            if let value=roughnessValue{
            //                roughness=Material.createColorTexture(from: simd_float4(value,1.0,0.0,0.0))
            //            }
        }

        if metallic == nil {
            hasMetalMap = 0
            //            print("Metallic texture not found. Attempting to read metallic value")
            metallicValue = mdlMaterial.property(with: .metallic)!.floatValue
            //            if let value=metallicValue{
            //                metallic=Material.createColorTexture(from: simd_float4(value,0.0,0.0,0.0))
            //            }
        }

        specular = mdlMaterial.property(with: .specular)!.floatValue
        specularTint = mdlMaterial.property(with: .specularTint)!.floatValue
        subsurface = mdlMaterial.property(with: .subsurface)!.floatValue
        anisotropic = mdlMaterial.property(with: .anisotropicRotation)!.floatValue
        // sheen=mdlMaterial.property(with: .sheen)!.floatValue
        sheen = 0.0
        sheenTint = mdlMaterial.property(with: .sheenTint)!.floatValue
        clearCoat = mdlMaterial.property(with: .clearcoat)!.floatValue
        // clearCoatGloss=mdlMaterial.property(with: .clearcoatGloss)!.floatValue
        clearCoatGloss = 0.0
        ior = mdlMaterial.property(with: .materialIndexOfRefraction)!.floatValue
        emit = false
        interactWithLight = true
        // check if a normal map was loaded
        if normal == nil {
            hasNormalMap = false
        }
    }

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
                print("Attempting to load texture: \(stringValue)")
                // Try to load from the asset catalog
                if let texture = try? textureLoader.newTexture(
                    name: stringValue, scaleFactor: 1.0, bundle: nil, options: textureLoaderOptions
                ) {
                    outputURL = nil
                    return texture
                }
                // Try to load from a file URL
                else if let textureURL = property.urlValue,
                        let texture = try? textureLoader.newTexture(
                            URL: textureURL, options: textureLoaderOptions
                        )
                {
                    print("Texture found \(stringValue)")
                    outputURL = textureURL
                    return texture
                }
                print("Texture not found \(stringValue)")
            }
        }
        return nil
    }

    private static func createColorTexture(from color: simd_float4) -> MTLTexture? {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        textureDescriptor.storageMode = .shared // Adjusted to shared storage mode

        guard let texture = renderInfo.device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }

        var colorData = [UInt8](repeating: 0, count: 4)
        colorData[0] = UInt8(clamping: Int(color.x * 255))
        colorData[1] = UInt8(clamping: Int(color.y * 255))
        colorData[2] = UInt8(clamping: Int(color.z * 255))
        colorData[3] = UInt8(clamping: Int(color.w * 255))

        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: colorData,
            bytesPerRow: 4
        )

        return texture
    }

    /*
     static private func makeTexture(from material: MDLMaterial,
                                     materialSemantic: MDLMaterialSemantic,
                                     textureLoader: MTKTextureLoader) -> MTLTexture {

         var newTexture: MTLTexture!

         for property in material.properties(with: materialSemantic) {
             // Load the textures with shader read using private storage
             let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
             .textureUsage: MTLTextureUsage.shaderRead.rawValue,
             .textureStorageMode: MTLStorageMode.private.rawValue]

             switch property.type {
             case .string:
                 if let stringValue = property.stringValue {

                     // If not texture has been fround by interpreting the URL as a path,  interpret
                     // string as an asset catalog name and attempt to load it with
                     //  -[MTKTextureLoader newTextureWithName:scaleFactor:bundle:options::error:]
                     // If a texture with the by interpreting the URL as an asset catalog name
                     if let texture = try? textureLoader.newTexture(name: stringValue, scaleFactor: 1.0, bundle: nil, options: textureLoaderOptions) {
                         newTexture = texture
                     }
                 }
             case .URL:
                 if let textureURL = property.urlValue {
                     // Attempt to load the texture from the file system
                     // If the texture has been found for a material using the string as a file path name...
                     if let texture = try? textureLoader.newTexture(URL: textureURL, options: textureLoaderOptions) {
                         newTexture = texture
                     }
                 }
             default:
                 // If we did not find the texture by interpreting it as a file path or as an asset name in the asset catalog, something went wrong
                 // (Perhaps the file was missing or misnamed in the asset catalog, model/material file, or file system)
                 // Depending on how the Metal render pipeline use with this submesh is implemented, this condition can be handled more gracefully.
                 // The app could load a dummy texture that will look okay when set with the pipeline or ensure that the pipelines rendering
                 // this submesh does not require a material with this property.

                 fatalError("Texture data for material property not found.")
             }
         }
         return newTexture
     }
      */
}
