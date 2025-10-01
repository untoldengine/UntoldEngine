//
//  RenderPipeLines.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
import MetalKit

public struct RenderPipeline {
    public var pipelineState: MTLRenderPipelineState?
    public var depthState: MTLDepthStencilState?
    public var success: Bool = false
    public var name: String?

    public init(pipelineState: MTLRenderPipelineState? = nil, depthState: MTLDepthStencilState? = nil, success: Bool = false, name: String? = nil) {
        self.pipelineState = pipelineState
        self.depthState = depthState
        self.success = success
        self.name = name
    }
}

public func CreatePipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexDescriptor: MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    blendEnabled: Bool = false,
    name: String
) -> RenderPipeline? {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let depthStateDescriptor = MTLDepthStencilDescriptor()

    do {
        let vertexFunction = renderInfo.library.makeFunction(name: vertexShader)!
        pipelineDescriptor.vertexFunction = vertexFunction

        if let fragmentShader {
            let fragmentFunction = renderInfo.library.makeFunction(name: fragmentShader)!
            pipelineDescriptor.fragmentFunction = fragmentFunction
        }

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        for (index, format) in colorFormats.enumerated() {
            let attachment = pipelineDescriptor.colorAttachments[index]
            attachment?.pixelFormat = format
            if blendEnabled {
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .sourceAlpha
                attachment?.destinationRGBBlendFactor = .one
                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .sourceAlpha
                attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }

        pipelineDescriptor.depthAttachmentPixelFormat = depthFormat

        depthStateDescriptor.depthCompareFunction = depthCompareFunction
        depthStateDescriptor.isDepthWriteEnabled = depthEnabled

        let pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)

        return RenderPipeline(
            pipelineState: pipelineState,
            depthState: depthState,
            success: true,
            name: name
        )

    } catch {
        handleError(.pipelineStateCreationFailed, name)
        return nil
    }
}

public typealias RenderPipelineInitBlock = () -> RenderPipeline?

// MARK: Grid pipeline

public func InitGridPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGridShader",
        fragmentShader: "fragmentGridShader",
        vertexDescriptor: createGridVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.less,
        depthEnabled: false,
        blendEnabled: true,
        name: "Grid Pipeline"
    )
}

// MARK: Shadow pipeline

public func InitShadowPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexShadowShader",
        fragmentShader: nil,
        vertexDescriptor: createShadowVertexDescriptor(),
        colorFormats: [.invalid],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.less,
        name: "Shadow Pipeline"
    )
}

// MARK: Model pipeline

public func InitModelPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexModelShader",
        fragmentShader: "fragmentModelShader",
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float, .rgba8Unorm, .rgba8Unorm],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Model Pipeline"
    )
}

// MARK: Light pipeline

public func InitLightPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexLightShader",
        fragmentShader: "fragmentLightShader",
        vertexDescriptor: createLightVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "Light Pipeline"
    )
}

// MARK: Geometry pipeline

public func InitGeometryPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGeometryShader",
        fragmentShader: "fragmentGeometryShader",
        vertexDescriptor: createGeometryVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Geometry Pipeline"
    )
}

// MARK: Highlight pipeline

public func InitHighlightPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGeometryShader",
        fragmentShader: "fragmentGeometryShader",
        vertexDescriptor: createGeometryVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .always,
        depthEnabled: false,
        name: "Highlight Pipeline"
    )
}

// MARK: Light Visual pipeline

public func InitLightVisualPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexLightVisualShader",
        fragmentShader: "fragmentLightVisualShader",
        vertexDescriptor: createLightVisualVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: true,
        name: "Light Visual Pipeline"
    )
}

// MARK: Outline pipeline

public func InitOutlinePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexOutlineShader",
        fragmentShader: "fragmentOutlineShader",
        vertexDescriptor: createOutlineVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: true,
        name: "Outline Pipeline"
    )
}

// MARK: Composite pipeline

public func InitCompositePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexCompositeShader",
        fragmentShader: "fragmentCompositeShader",
        vertexDescriptor: createCompositeVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Composite Pipeline"
    )
}

// MARK: Pre composite pipeline

public func InitPreCompositePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexPreCompositeShader",
        fragmentShader: "fragmentPreCompositeShader",
        vertexDescriptor: createPreCompositeVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Pre-Composite Pipeline"
    )
}

// MARK: Tone mapping pipeline

public func InitTonemappingPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexTonemappingShader",
        fragmentShader: "fragmentTonemappingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Tone-mapping Pipeline"
    )
}

// MARK: Blur pipeline

public func InitBlurPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexBlurShader",
        fragmentShader: "fragmentBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Blur Pipeline"
    )
}

// MARK: Color grading pipeline

public func InitColorGradingPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexColorGradingShader",
        fragmentShader: "fragmentColorGradingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "ColorGrading Pipeline"
    )
}

// MARK: Color correction pipeline

public func InitColorCorrectionPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexColorCorrectionShader",
        fragmentShader: "fragmentColorCorrectionShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Color Correction Pipeline"
    )
}

// MARK: Bloom threshold pipeline

public func InitBloomThresholdPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexBloomThresholdShader",
        fragmentShader: "fragmentBloomThresholdShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Bloom Threshold Pipeline"
    )
}

// MARK: Bloom composite pipeline

public func InitBloomCompositePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexBloomCompositeShader",
        fragmentShader: "fragmentBloomCompositeShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        blendEnabled: true,
        name: "Bloom Composite Pipeline"
    )
}

// MARK: Vignette pipeline

public func InitVignettePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexVignetteShader",
        fragmentShader: "fragmentVignetteShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Vignette Pipeline"
    )
}

// MARK: Chromatic aberration pipeline

public func InitChromaticAberrationPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexChromaticAberrationShader",
        fragmentShader: "fragmentChromaticAberrationShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Chromatic Aberration Pipeline"
    )
}

// MARK: Depth of field pipeline

public func InitDepthOfFieldPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexDepthOfFieldShader",
        fragmentShader: "fragmentDepthOfFieldShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Depth of Field Pipeline"
    )
}

// MARK: SSAO pipeline

public func InitSSAOPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSSAOShader",
        fragmentShader: "fragmentSSAOShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SSAO Pipeline"
    )
}

// MARK: SSAO blur pipeline

public func InitSSAOBlurPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSSAOBlurShader",
        fragmentShader: "fragmentSSAOBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SSAO Blur Pipeline"
    )
}

// MARK: Environment pipeline

public func InitEnvironmentPipeline() -> RenderPipeline? {
    guard var pipeline = CreatePipeline(
        vertexShader: "vertexEnvironmentShader",
        fragmentShader: "fragmentEnvironmentShader",
        vertexDescriptor: createEnvironmentVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Environment Pipeline"
    ) else {
        return nil
    }

    // create the mesh
    let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

    let mdlMesh = MDLMesh.newEllipsoid(
        withRadii: simd_float3(5.0, 5.0, 5.0), radialSegments: 24, verticalSegments: 24,
        geometryType: .triangles, inwardNormals: true, hemisphere: false, allocator: bufferAllocator
    )

    let mdlVertexDescriptor = MDLVertexDescriptor()
    guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
        fatalError("could not get the mdl attributes")
    }

    attributes[0].name = MDLVertexAttributePosition
    attributes[0].format = MDLVertexFormat.float3
    attributes[0].bufferIndex = 0
    attributes[0].offset = 0

    attributes[1].name = MDLVertexAttributeNormal
    attributes[1].format = MDLVertexFormat.float3
    attributes[1].bufferIndex = 0
    attributes[1].offset = MemoryLayout<simd_float3>.stride

    attributes[2].name = MDLVertexAttributeTextureCoordinate
    attributes[2].format = MDLVertexFormat.float2
    attributes[2].bufferIndex = 0
    attributes[2].offset = 2 * MemoryLayout<simd_float3>.stride

    // Initialize the layout
    mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(
        stride: 2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride)

    guard let bufferLayouts = mdlVertexDescriptor.layouts as? [MDLVertexBufferLayout] else {
        fatalError("Could not get the MDL layouts")
    }

    bufferLayouts[0].stride =
        2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride

    mdlMesh.vertexDescriptor = mdlVertexDescriptor

    do {
        environmentMesh = try MTKMesh(mesh: mdlMesh, device: renderInfo.device)
    } catch {
        fatalError("Unable to build MetalKit Mesh. Error info: ")
    }

    pipeline.success = true
    return pipeline
}

// MARK: IBL pre filter pipeline

public func InitIBLPreFilterPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexIBLPreFilterShader",
        fragmentShader: "fragmentIBLPreFilterShader",
        vertexDescriptor: createIBLPreFilterVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, renderInfo.colorPixelFormat, renderInfo.colorPixelFormat],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "IBL-Pre Filer Pipeline"
    )
}

public func DefaultPipeLines() -> [(RenderPipelineType, RenderPipelineInitBlock)] {
    [
        (.grid, InitGridPipeline),
        (.shadow, InitShadowPipeline),
        (.model, InitModelPipeline),
        (.light, InitLightPipeline),
        (.geometry, InitGeometryPipeline),
        (.highlight, InitHighlightPipeline),
        (.lightVisual, InitLightVisualPipeline),
        (.outline, InitOutlinePipeline),
        (.composite, InitCompositePipeline),
        (.preComposite, InitPreCompositePipeline),
        (.tonemapping, InitTonemappingPipeline),
        (.blur, InitBlurPipeline),
        (.colorGrading, InitColorGradingPipeline),
        (.colorCorrection, InitColorCorrectionPipeline),
        (.bloomThreshold, InitBloomThresholdPipeline),
        (.bloomComposite, InitBloomCompositePipeline),
        (.vignette, InitVignettePipeline),
        (.chromaticAberration, InitChromaticAberrationPipeline),
        (.depthOfField, InitDepthOfFieldPipeline),
        (.ssao, InitSSAOPipeline),
        (.ssaoBlur, InitSSAOBlurPipeline),
        (.environment, InitEnvironmentPipeline),
        (.iblPreFilter, InitIBLPreFilterPipeline),
    ]
}
