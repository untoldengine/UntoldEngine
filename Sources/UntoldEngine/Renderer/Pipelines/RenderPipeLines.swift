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
    public var rasterSampleCount: Int = 1

    public init(
        pipelineState: MTLRenderPipelineState? = nil,
        depthState: MTLDepthStencilState? = nil,
        success: Bool = false,
        name: String? = nil,
        rasterSampleCount: Int = 1
    ) {
        self.pipelineState = pipelineState
        self.depthState = depthState
        self.success = success
        self.name = name
        self.rasterSampleCount = rasterSampleCount
    }
}

/// Why `buildRenderPipeline` or `buildComputePipeline` could not create a pipeline.
///
/// `CreatePipeline` and `CreateComputePipeline` report these through `handleError`
/// and return no pipeline; the render-extension registry keeps the reason in its
/// `RenderExtensionPipelineError.creationFailed` diagnostics instead.
enum PipelineCreationError: Error {
    /// No Metal device is available yet.
    case metalUnavailable
    /// The shader library could not be resolved; `resolveRenderShaderLibrary` has already logged why.
    case missingShaderLibrary(usage: String)
    /// The shader library has no function with this name.
    case missingFunction(name: String)
    /// Metal rejected the pipeline; `underlying` is the error it threw.
    case pipelineStateCreationFailed(underlying: any Error)

    var reason: String {
        switch self {
        case .metalUnavailable:
            return "Metal device is not available"
        case let .missingShaderLibrary(usage):
            return "missing shader library for \(usage)"
        case let .missingFunction(name):
            return "shader function '\(name)' not found"
        case let .pipelineStateCreationFailed(underlying):
            return failureReason(for: underlying)
        }
    }
}

public enum PipelineBlendMode: Equatable, Sendable {
    case none
    case alphaStraight
    case alphaPremultiplied
    case additive
}

public func CreatePipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexShaderLibrary: RenderShaderLibraryReference = .engine,
    fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
    vertexDescriptor: MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    reverseZCompatible: Bool = true,
    blendMode: PipelineBlendMode = .none,
    name: String,
    reflectionHandler: ((MTLRenderPipelineReflection) -> Void)? = nil
) -> RenderPipeline? {
    do {
        return try buildRenderPipeline(
            vertexShader: vertexShader,
            fragmentShader: fragmentShader,
            vertexShaderLibrary: vertexShaderLibrary,
            fragmentShaderLibrary: fragmentShaderLibrary,
            vertexDescriptor: vertexDescriptor,
            colorFormats: colorFormats,
            depthFormat: depthFormat,
            depthCompareFunction: depthCompareFunction,
            depthEnabled: depthEnabled,
            reverseZCompatible: reverseZCompatible,
            blendMode: blendMode,
            name: name,
            reflectionHandler: reflectionHandler
        )
    } catch PipelineCreationError.missingShaderLibrary {
        return nil
    } catch let PipelineCreationError.missingFunction(function) {
        handleError(.shaderCreationFailed, function)
        return nil
    } catch {
        handleError(.pipelineStateCreationFailed, "\(name): \(failureReason(for: error))")
        return nil
    }
}

/// Builds a render pipeline, throwing a `PipelineCreationError` that says why Metal
/// could not create it. `CreatePipeline` wraps this for callers that only need a
/// pipeline or nothing.
func buildRenderPipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexShaderLibrary: RenderShaderLibraryReference = .engine,
    fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
    vertexDescriptor: MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    reverseZCompatible: Bool = true,
    blendMode: PipelineBlendMode = .none,
    name: String,
    reflectionHandler: ((MTLRenderPipelineReflection) -> Void)? = nil
) throws -> RenderPipeline {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let depthStateDescriptor = MTLDepthStencilDescriptor()

    let vertexUsage = "vertex shader '\(vertexShader)'"
    guard let vertexLibrary = resolveRenderShaderLibrary(vertexShaderLibrary, usage: vertexUsage) else {
        throw PipelineCreationError.missingShaderLibrary(usage: vertexUsage)
    }
    guard let vertexFunction = vertexLibrary.makeFunction(name: vertexShader) else {
        throw PipelineCreationError.missingFunction(name: vertexShader)
    }
    pipelineDescriptor.vertexFunction = vertexFunction

    if let fragmentShader {
        let fragmentUsage = "fragment shader '\(fragmentShader)'"
        guard let fragmentLibrary = resolveRenderShaderLibrary(fragmentShaderLibrary, usage: fragmentUsage) else {
            throw PipelineCreationError.missingShaderLibrary(usage: fragmentUsage)
        }
        guard let fragmentFunction = fragmentLibrary.makeFunction(name: fragmentShader) else {
            throw PipelineCreationError.missingFunction(name: fragmentShader)
        }
        pipelineDescriptor.fragmentFunction = fragmentFunction
    }

    do {
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
            }
        }

        pipelineDescriptor.depthAttachmentPixelFormat = depthFormat

        depthStateDescriptor.depthCompareFunction = sceneDepthCompareFunction(
            depthCompareFunction,
            reverseZCompatible: reverseZCompatible
        )
        depthStateDescriptor.isDepthWriteEnabled = depthEnabled

        let pipelineState: MTLRenderPipelineState
        if let reflectionHandler {
            var reflection: MTLAutoreleasedRenderPipelineReflection?
            pipelineState = try renderInfo.device.makeRenderPipelineState(
                descriptor: pipelineDescriptor,
                options: [.bindingInfo],
                reflection: &reflection
            )
            if let reflection {
                reflectionHandler(reflection)
            }
        } else {
            pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }
        let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)

        return RenderPipeline(
            pipelineState: pipelineState,
            depthState: depthState,
            success: true,
            name: name
        )
    } catch {
        throw PipelineCreationError.pipelineStateCreationFailed(underlying: error)
    }
}

public func CreateTilePipeline(
    tileShader: String,
    tileShaderLibrary: RenderShaderLibraryReference = .engine,
    colorFormats: [MTLPixelFormat],
    name: String
) -> RenderPipeline? {
    #if targetEnvironment(simulator)
        // Tile shaders are unsupported in the simulator; creating the pipeline state
        // raises a hard assertion (not a catchable error), so bail out before that.
        Logger.log(message: "Skipping tile pipeline '\(name)': tile shaders are not supported in the simulator")
        return nil
    #else
        let pipelineDescriptor = MTLTileRenderPipelineDescriptor()

        guard let tileLibrary = resolveRenderShaderLibrary(
            tileShaderLibrary,
            usage: "tile shader '\(tileShader)'"
        ) else {
            return nil
        }

        do {
            guard let tileFunction = tileLibrary.makeFunction(name: tileShader) else {
                handleError(.shaderCreationFailed, tileShader)
                return nil
            }

            pipelineDescriptor.label = name
            pipelineDescriptor.tileFunction = tileFunction
            pipelineDescriptor.threadgroupSizeMatchesTileSize = true

            for (index, format) in colorFormats.enumerated() {
                pipelineDescriptor.colorAttachments[index].pixelFormat = format
            }

            let pipelineState = try renderInfo.device.makeRenderPipelineState(
                tileDescriptor: pipelineDescriptor,
                options: [],
                reflection: nil
            )

            return RenderPipeline(
                pipelineState: pipelineState,
                depthState: nil,
                success: true,
                name: name
            )

        } catch {
            handleError(.pipelineStateCreationFailed, name)
            return nil
        }
    #endif
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
        depthCompareFunction: MTLCompareFunction.lessEqual,
        depthEnabled: false,
        blendMode: .alphaStraight,
        name: "Grid Pipeline"
    )
}

// MARK: Sky pipeline

public func InitSkyPipeline() -> RenderPipeline? {
    let wf = renderInfo.colorPipeline.working
    return CreatePipeline(
        vertexShader: "vertexSkyShader",
        fragmentShader: "fragmentSkyShader",
        vertexDescriptor: createGridVertexDescriptor(),
        colorFormats: [wf.environment],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.lessEqual,
        depthEnabled: false,
        blendMode: .none,
        name: "Sky Pipeline"
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

/// The model pipeline shares the same 6-attachment descriptor as the TBDR light
/// pipeline. Attachments 0-4 are the G-buffer targets written by geometry draws.
/// Attachment 5 is the lit output (deferredColorMap) that only the light sub-pass
/// writes — geometry must not touch it, so writeMask is disabled for slot 5.
public func InitModelPipeline() -> RenderPipeline? {
    guard let library = renderInfo.library else {
        handleError(.metalLibraryNotFound)
        return nil
    }
    guard let vertexFunction = library.makeFunction(name: "vertexModelShader") else {
        handleError(.shaderCreationFailed, "vertexModelShader")
        return nil
    }
    guard let fragmentFunction = library.makeFunction(name: "fragmentModelShader") else {
        handleError(.shaderCreationFailed, "fragmentModelShader")
        return nil
    }

    let desc = MTLRenderPipelineDescriptor()
    desc.label = "Model Pipeline"
    desc.vertexFunction = vertexFunction
    desc.fragmentFunction = fragmentFunction
    desc.vertexDescriptor = createModelVertexDescriptor()
    desc.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    desc.rasterSampleCount = max(1, renderInfo.opaqueSampleCount)

    // G-buffer outputs: geometry writes to these.
    let gbufferFormats: [MTLPixelFormat] = [
        wf.gBufferAlbedo, wf.gBufferNormal, wf.gBufferPosition,
        wf.gBufferMaterial, wf.gBufferEmissive,
    ]
    for (i, fmt) in gbufferFormats.enumerated() {
        desc.colorAttachments[i].pixelFormat = fmt
        desc.colorAttachments[i].writeMask = .all
    }

    // Attachment 5: deferredColorMap — geometry must not write here.
    desc.colorAttachments[5].pixelFormat = wf.sceneColor
    desc.colorAttachments[5].writeMask = []

    let depthDesc = MTLDepthStencilDescriptor()
    depthDesc.depthCompareFunction = sceneDepthCompareFunction(.lessEqual)
    depthDesc.isDepthWriteEnabled = true

    do {
        let pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: desc)
        let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthDesc)
        return RenderPipeline(
            pipelineState: pipelineState,
            depthState: depthState,
            success: true,
            name: "Model Pipeline",
            rasterSampleCount: desc.rasterSampleCount
        )
    } catch {
        handleError(.pipelineStateCreationFailed, "Model Pipeline")
        return nil
    }
}

// MARK: Light pipeline (TBDR)

///
/// The light pass runs inside the same MTLRenderCommandEncoder as the geometry
/// pass. The fragment shader reads G-buffer data from tile memory via [[color(N)]]
/// (framebuffer fetch) and writes the lit result to attachment 5 (deferredColorMap).
/// Attachments 0-4 carry G-buffer data; their writeMask is disabled so the light
/// quad does not overwrite geometry output that is still live in tile memory.
///
/// Simulator: framebuffer fetch is unsupported ("reading from a rendertarget is
/// not supported"), so the light pass instead samples the stored G-buffer
/// textures with the texture-based fragmentLightShader in its own encoder
/// (deferredRenderPassDescriptor). See combinedModelLightExecution.
public func InitLightPipeline() -> RenderPipeline? {
    #if targetEnvironment(simulator)
        return CreatePipeline(
            vertexShader: "vertexLightShader",
            fragmentShader: "fragmentLightShader",
            vertexDescriptor: createLightVertexDescriptor(),
            colorFormats: [wf.sceneColor],
            depthFormat: renderInfo.depthPixelFormat,
            depthCompareFunction: .always,
            depthEnabled: false,
            reverseZCompatible: false,
            name: "Light Pipeline (Simulator)"
        )
    #else
        guard let library = renderInfo.library else {
            handleError(.metalLibraryNotFound)
            return nil
        }
        guard let vertexFunction = library.makeFunction(name: "vertexLightShader") else {
            handleError(.shaderCreationFailed, "vertexLightShader")
            return nil
        }
        guard let fragmentFunction = library.makeFunction(name: "fragmentLightShaderTBDR") else {
            handleError(.shaderCreationFailed, "fragmentLightShaderTBDR")
            return nil
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Light Pipeline (TBDR)"
        desc.vertexFunction = vertexFunction
        desc.fragmentFunction = fragmentFunction
        desc.vertexDescriptor = createLightVertexDescriptor()
        desc.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
        desc.rasterSampleCount = max(1, renderInfo.opaqueSampleCount)

        // G-buffer slots: readable via [[color(N)]] framebuffer fetch; light quad must not write them.
        let gbufferFormats: [MTLPixelFormat] = [
            wf.gBufferAlbedo, wf.gBufferNormal, wf.gBufferPosition,
            wf.gBufferMaterial, wf.gBufferEmissive,
        ]
        for (i, fmt) in gbufferFormats.enumerated() {
            desc.colorAttachments[i].pixelFormat = fmt
            desc.colorAttachments[i].writeMask = []
        }

        // Attachment 5: deferredColorMap — the lit output.
        desc.colorAttachments[5].pixelFormat = wf.sceneColor
        desc.colorAttachments[5].writeMask = .all

        do {
            let pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: desc)
            let depthDesc = MTLDepthStencilDescriptor()
            depthDesc.isDepthWriteEnabled = false
            depthDesc.depthCompareFunction = .always
            let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthDesc)
            return RenderPipeline(
                pipelineState: pipelineState,
                depthState: depthState,
                success: true,
                name: "Light Pipeline (TBDR)",
                rasterSampleCount: desc.rasterSampleCount
            )
        } catch {
            handleError(.pipelineStateCreationFailed, "Light Pipeline (TBDR): \(error.localizedDescription)")
            return nil
        }
    #endif
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

public func InitGaussianTBDRInitializePipeline() -> RenderPipeline? {
    CreateTilePipeline(
        tileShader: "initializeGaussianFragmentStore",
        colorFormats: [wf.gaussian],
        name: "Gaussian TBDR Initialize Pipeline"
    )
}

public func InitGaussianTBDRDrawPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGaussianTBDRShader",
        fragmentShader: "fragmentGaussianTBDRShader",
        vertexDescriptor: createGaussianVertexDescriptor(),
        colorFormats: [wf.gaussian],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .always,
        depthEnabled: false,
        blendMode: .none,
        name: "Gaussian TBDR Draw Pipeline"
    )
}

public func InitGaussianTBDRPostprocessPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexGaussianTBDRPostprocessShader",
        fragmentShader: "fragmentGaussianTBDRPostprocessShader",
        vertexDescriptor: nil,
        colorFormats: [wf.gaussian],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .always,
        depthEnabled: true,
        blendMode: .none,
        name: "Gaussian TBDR Postprocess Pipeline"
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

public func InitIBLSpecularPreFilterPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexIBLPreFilterShader",
        fragmentShader: "fragmentIBLSpecularPreFilterShader",
        vertexDescriptor: createIBLPreFilterVertexDescriptor(),
        colorFormats: [wf.ibl],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "IBL Specular Pre-Filter Pipeline"
    )
}

public func InitXRIBLCubePreFilterPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexIBLPreFilterShader",
        fragmentShader: "fragmentXRIBLCubePreFilterShader",
        vertexDescriptor: createIBLPreFilterVertexDescriptor(),
        colorFormats: [wf.ibl, wf.ibl, wf.ibl],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "XR IBL Cube Pre-Filter Pipeline"
    )
}

public func InitXRIBLCubeSpecularPreFilterPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexIBLPreFilterShader",
        fragmentShader: "fragmentXRIBLCubeSpecularPreFilterShader",
        vertexDescriptor: createIBLPreFilterVertexDescriptor(),
        colorFormats: [wf.ibl],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "XR IBL Cube Specular Pre-Filter Pipeline"
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

public func InitFXAAEdgeDebugPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexFXAAShader",
        fragmentShader: "fragmentFXAAEdgeDebugShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPipeline.working.lookOutput],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "FXAA Edge Debug Pipeline"
    )
}

public func InitSMAAEdgesPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSMAAShader",
        fragmentShader: "fragmentSMAAEdgeDetectionShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [.rg8Unorm],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SMAA Edges Pipeline"
    )
}

public func InitSMAABlendWeightsPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSMAAShader",
        fragmentShader: "fragmentSMAABlendWeightShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [.rgba8Unorm],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SMAA Blend Weights Pipeline"
    )
}

public func InitSMAANeighborhoodPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSMAAShader",
        fragmentShader: "fragmentSMAANeighborhoodShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPipeline.working.lookOutput],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SMAA Neighborhood Pipeline"
    )
}

public func InitSMAADifferencePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexSMAAShader",
        fragmentShader: "fragmentSMAADifferenceShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [.rgba8Unorm],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SMAA Difference Pipeline"
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

public func InitWireframePipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexWireframeShader",
        fragmentShader: "fragmentWireframeShader",
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [wf.sceneColor],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: false,
        blendMode: .alphaStraight,
        name: "Wireframe Pipeline"
    )
}

public func InitWireframeOcclusionDepthPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexModelShader",
        fragmentShader: nil,
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [.invalid],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: true,
        name: "Wireframe Occlusion Depth Pipeline"
    )
}

/// Depth-only draw of a mesh carrying a `MeshOccluderComponent`, pushed along its normals away
/// from the camera by the component's margin (`vertexMeshOccluderShellShader`). Runs in its own
/// encoder on the resolved opaque depth after the G-buffer pass, before the HZB copy and the
/// splat pass snapshot it, so both see the shell.
public func InitMeshOccluderShellPipeline() -> RenderPipeline? {
    CreatePipeline(
        vertexShader: "vertexMeshOccluderShellShader",
        fragmentShader: nil,
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [.invalid],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: true,
        name: "Mesh Occluder Shell Pipeline"
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
        (.sky, InitSkyPipeline),
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
        (.iblSpecularPreFilter, InitIBLSpecularPreFilterPipeline),
        (.xrIBLCubePreFilter, InitXRIBLCubePreFilterPipeline),
        (.xrIBLCubeSpecularPreFilter, InitXRIBLCubeSpecularPreFilterPipeline),
        (.gaussianTBDRInitialize, InitGaussianTBDRInitializePipeline),
        (.gaussianTBDRDraw, InitGaussianTBDRDrawPipeline),
        (.gaussianTBDRPostprocess, InitGaussianTBDRPostprocessPipeline),
        (.spatialDebug, InitSpatialDebugPipeline),
        (.look, InitLookPipeline),
        (.fxaa, InitFXAAPipeline),
        (.fxaaEdgeDebug, InitFXAAEdgeDebugPipeline),
        (.smaaEdges, InitSMAAEdgesPipeline),
        (.smaaBlendWeights, InitSMAABlendWeightsPipeline),
        (.smaaNeighborhood, InitSMAANeighborhoodPipeline),
        (.smaaDifference, InitSMAADifferencePipeline),
        (.outputTransform, InitOutputTransformPipeline),
        (.debug, InitDebugPipeline),
        (.transparency, InitTransparencyPipeline),
        (.wireframe, InitWireframePipeline),
        (.meshOccluderShell, InitMeshOccluderShellPipeline),
    ]
}

public func GaussianSplatPipeLines() -> [(RenderPipelineType, RenderPipelineInitBlock)] {
    DefaultPipeLines() + [
        (.gaussianTBDRInitialize, InitGaussianTBDRInitializePipeline),
        (.gaussianTBDRDraw, InitGaussianTBDRDrawPipeline),
        (.gaussianTBDRPostprocess, InitGaussianTBDRPostprocessPipeline),
        (.preComposite, InitPreCompositePipeline),
    ]
}
