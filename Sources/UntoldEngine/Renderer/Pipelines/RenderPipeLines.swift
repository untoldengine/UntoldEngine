//
//  RenderPipeLines.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
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

public enum PipelineBlendMode {
    case none
    case alphaStraight
    case alphaPremultiplied
    case additive
    case gaussianFrontToBack
}

public func CreatePipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexDescriptor: MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    reverseZCompatible: Bool = true,
    blendMode: PipelineBlendMode = .none,
    name: String
) -> RenderPipeline? {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let depthStateDescriptor = MTLDepthStencilDescriptor()

    guard renderInfo.library != nil else {
        handleError(.metalLibraryNotFound)
        return nil
    }

    do {
        guard let vertexFunction = renderInfo.library.makeFunction(name: vertexShader) else {
            handleError(.shaderCreationFailed, vertexShader)
            return nil
        }
        pipelineDescriptor.vertexFunction = vertexFunction

        if let fragmentShader {
            guard let fragmentFunction = renderInfo.library.makeFunction(name: fragmentShader) else {
                handleError(.shaderCreationFailed, fragmentShader)
                return nil
            }
            pipelineDescriptor.fragmentFunction = fragmentFunction
        }

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        for (index, format) in colorFormats.enumerated() {
            let attachment = pipelineDescriptor.colorAttachments[index]
            attachment?.pixelFormat = format

            switch blendMode {
            case .none:
                attachment?.isBlendingEnabled = false

            case .alphaStraight:
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .sourceAlpha
                attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha

                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .one
                attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

            case .alphaPremultiplied:
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .one
                attachment?.destinationRGBBlendFactor = .oneMinusSourceAlpha

                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .one
                attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha

            case .additive:
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .one
                attachment?.destinationRGBBlendFactor = .one

                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .one
                attachment?.destinationAlphaBlendFactor = .one

            case .gaussianFrontToBack:
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .oneMinusDestinationAlpha
                attachment?.destinationRGBBlendFactor = .one

                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .oneMinusDestinationAlpha
                attachment?.destinationAlphaBlendFactor = .one
            }
        }

        pipelineDescriptor.depthAttachmentPixelFormat = depthFormat

        depthStateDescriptor.depthCompareFunction = sceneDepthCompareFunction(
            depthCompareFunction,
            reverseZCompatible: reverseZCompatible
        )
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
    let wf = renderInfo.colorPipeline.working
    return CreatePipeline(
        vertexShader: "vertexGridShader",
        fragmentShader: "fragmentGridShader",
        vertexDescriptor: createGridVertexDescriptor(),
        colorFormats: [wf.environment],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.less,
        depthEnabled: false,
        blendMode: .alphaStraight,
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
        reverseZCompatible: false,
        name: "Shadow Pipeline"
    )
}

// MARK: Model pipeline

private var wf: WorkingColorFormats {
    renderInfo.colorPipeline.working
}

public func InitModelPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexModelShader",
        fragmentShader: "fragmentModelShader",
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [wf.gBufferAlbedo, wf.gBufferNormal, wf.gBufferPosition, wf.gBufferMaterial, wf.gBufferEmissive],
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
        colorFormats: [wf.sceneColor],
        depthFormat: renderInfo.depthPixelFormat,
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
        colorFormats: [wf.gizmo, .rgba16Float, .rgba16Float],
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
        colorFormats: [wf.gizmo],
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
        colorFormats: [wf.gizmo],
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
        colorFormats: [wf.gizmo, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.presentColorPixelFormat],
        depthFormat: renderInfo.presentDepthPixelFormat,
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
        colorFormats: [wf.sceneComposite],
        depthFormat: .invalid,
        depthEnabled: false,
        blendMode: .none,
        name: "Pre-Composite Pipeline"
    )
}

// MARK: Tone mapping pipeline

public func InitTonemappingPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexTonemappingShader",
        fragmentShader: "fragmentTonemappingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.postProcess],
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
        colorFormats: [wf.postProcess],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Blur Pipeline"
    )
}

// MARK: Color correction pipeline

public func InitColorCorrectionPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexColorCorrectionShader",
        fragmentShader: "fragmentColorCorrectionShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.postProcess],
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
        colorFormats: [wf.postProcess],
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
        colorFormats: [wf.postProcess],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        blendMode: .none,
        name: "Bloom Composite Pipeline"
    )
}

// MARK: Vignette pipeline

public func InitVignettePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexVignetteShader",
        fragmentShader: "fragmentVignetteShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.postProcess],
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
        colorFormats: [wf.postProcess],
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
        colorFormats: [wf.postProcess],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Depth of Field Pipeline"
    )
}

// MARK: SSAO pipeline

public func InitSSAOPipeline() -> RenderPipeline? {
    // Use quality-based texture format for SSAO output
    let format = SSAOParams.shared.quality.textureFormat
    return CreatePipeline(
        vertexShader: "vertexSSAOShader",
        fragmentShader: "fragmentSSAOShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [format],
        depthFormat: .invalid, // No depth attachment for SSAO pass
        depthEnabled: false,
        name: "SSAO Pipeline"
    )
}

// MARK: SSAO blur pipeline

public func InitSSAOBlurPipeline() -> RenderPipeline? {
    // Use quality-based texture format for SSAO blur output
    let format = SSAOParams.shared.quality.textureFormat
    return CreatePipeline(
        vertexShader: "vertexSSAOBlurShader",
        fragmentShader: "fragmentSSAOBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [format],
        depthFormat: .invalid, // No depth attachment for blur pass
        depthEnabled: false,
        name: "SSAO Blur Pipeline"
    )
}

// MARK: SSAO bilateral blur pipeline

public func InitSSAOBilateralBlurPipeline() -> RenderPipeline? {
    // Use r8Unorm or r16Float based on quality
    CreatePipeline(
        vertexShader: "vertexSSAOBilateralBlurShader",
        fragmentShader: "fragmentSSAOBilateralBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [SSAOParams.shared.quality.textureFormat],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "SSAO Bilateral Blur Pipeline"
    )
}

// MARK: SSAO upsample pipeline

public func InitSSAOUpsamplePipeline() -> RenderPipeline? {
    // Upsample outputs to full-res blur texture, use quality format
    let format = SSAOParams.shared.quality.textureFormat
    return CreatePipeline(
        vertexShader: "vertexSSAOUpsampleShader",
        fragmentShader: "fragmentSSAOUpsampleShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [format],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "SSAO Upsample Pipeline"
    )
}

// MARK: Gaussian pipeline

public func InitGaussianPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGaussianShader",
        fragmentShader: "fragmentGaussianShader",
        vertexDescriptor: createGaussianVertexDescriptor(),
        colorFormats: [wf.gaussian],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        blendMode: .gaussianFrontToBack,
        name: "Gaussian Pipeline"
    )
}

// MARK: Environment pipeline

public func InitEnvironmentPipeline() -> RenderPipeline? {
    guard var pipeline = CreatePipeline(
        vertexShader: "vertexEnvironmentShader",
        fragmentShader: "fragmentEnvironmentShader",
        vertexDescriptor: createEnvironmentVertexDescriptor(),
        colorFormats: [wf.environment],
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
        stride: 2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride
    )

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
        colorFormats: [wf.ibl, wf.ibl, wf.ibl],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "IBL-Pre Filer Pipeline"
    )
}

public func InitLookPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexLookShader",
        fragmentShader: "fragmentLookShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.lookOutput],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Look Pipeline"
    )
}

public func InitOutputTransformPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexOutputTransformShader",
        fragmentShader: "fragmentOutputTransformShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.presentColorPixelFormat],
        depthFormat: renderInfo.presentDepthPixelFormat,
        depthCompareFunction: .always,
        depthEnabled: true,
        name: "Output Transform Pipeline"
    )
}

public func InitFXAAPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexFXAAShader",
        fragmentShader: "fragmentFXAAShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPipeline.working.lookOutput],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "FXAA Pipeline"
    )
}

public func InitDebugPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexDebugShader",
        fragmentShader: "fragmentDebugShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.lookOutput],
        // Look/debug passes use postProcessRenderPassDescriptor, which carries depthMap.
        // Match that attachment format even though we do not depth-test/write here.
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Debug Pipeline"
    )
}

public func InitTAAResolvePipeline() -> RenderPipeline? {
    let wf = renderInfo.colorPipeline.working
    return CreatePipeline(
        vertexShader: "vertexTAAResolveShader",
        fragmentShader: "fragmentTAAResolveShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [wf.lookOutput],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "TAA Resolve Pipeline"
    )
}

public func InitVelocityPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexVelocityShader",
        fragmentShader: "fragmentVelocityShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [.rg16Float],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "Velocity Pipeline"
    )
}

public func InitTransparencyPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexModelShader",
        fragmentShader: "fragmentTransparencyShader",
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [wf.sceneColor],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: false, // depth test enabled, writes disabled
        blendMode: .alphaPremultiplied,
        name: "Transparency Pipeline"
    )
}

public func InitSpatialDebugPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSpatialDebugShader",
        fragmentShader: "fragmentSpatialDebugShader",
        vertexDescriptor: createGeometryVertexDescriptor(),
        colorFormats: [wf.sceneColor],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: false, // keep scene depth intact
        name: "Spatial Debug Pipeline"
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
        (.colorCorrection, InitColorCorrectionPipeline),
        (.bloomThreshold, InitBloomThresholdPipeline),
        (.bloomComposite, InitBloomCompositePipeline),
        (.vignette, InitVignettePipeline),
        (.chromaticAberration, InitChromaticAberrationPipeline),
        (.depthOfField, InitDepthOfFieldPipeline),
        (.ssao, InitSSAOPipeline),
        (.ssaoBlur, InitSSAOBlurPipeline),
        (.ssaoBilateralBlur, InitSSAOBilateralBlurPipeline),
        (.ssaoUpsample, InitSSAOUpsamplePipeline),
        (.environment, InitEnvironmentPipeline),
        (.iblPreFilter, InitIBLPreFilterPipeline),
        (.gaussian, InitGaussianPipeline),
        (.spatialDebug, InitSpatialDebugPipeline),
        (.look, InitLookPipeline),
        (.fxaa, InitFXAAPipeline),
        (.outputTransform, InitOutputTransformPipeline),
        (.debug, InitDebugPipeline),
        (.transparency, InitTransparencyPipeline),
        (.velocity, InitVelocityPipeline),
        (.taaResolve, InitTAAResolvePipeline),
    ]
}

public func GaussianSplatPipeLines() -> [(RenderPipelineType, RenderPipelineInitBlock)] {
    DefaultPipeLines() + [
        (.gaussian, InitGaussianPipeline),
        (.preComposite, InitPreCompositePipeline),
    ]
}
