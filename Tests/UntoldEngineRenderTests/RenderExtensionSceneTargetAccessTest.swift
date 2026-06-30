import Metal
import simd
@testable import UntoldEngine
import XCTest

private final class ProceduralGeometryAcceptanceExtension: RenderExtension, @unchecked Sendable {
    let id = "test.procedural-geometry.acceptance"
    let libraryID: RenderShaderLibraryID = "test.procedural-geometry.acceptance.shaders"
    let pipelineID: RenderPipelineType = "test.procedural-geometry.acceptance.pipeline"
    let passID = "test.procedural-geometry.acceptance.pass"
    let library: MTLLibrary
    private(set) var observedCamera = false
    private(set) var observedPipeline = false
    private(set) var observedSceneTargets = false
    private(set) var observedDepthState = false
    private(set) var issuedDraw = false

    init(library: MTLLibrary) {
        self.library = library
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(libraryID, source: .library(library))
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerScenePipeline(
            pipelineID,
            vertexShader: "acceptanceVertex",
            fragmentShader: "acceptanceFragment",
            vertexShaderLibrary: .registered(libraryID),
            fragmentShaderLibrary: .registered(libraryID),
            depthCompareFunction: .lessEqual,
            depthEnabled: true,
            reverseZCompatible: true,
            blendMode: .alphaPremultiplied,
            name: "Procedural Geometry Acceptance"
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [weak self] context in
            guard let self else { return }
            observedCamera = context.camera.viewProjectionMatrix.columns.0.x.isFinite
            guard let pipeline = context.renderPipelines.pipeline(pipelineID),
                  let pipelineState = pipeline.pipelineState
            else {
                return
            }
            observedPipeline = true
            guard let encoder = context.sceneRenderTargets.makeRenderCommandEncoder(
                label: "Procedural Geometry Acceptance"
            ) else {
                return
            }
            observedSceneTargets = true
            defer { encoder.endEncoding() }

            var viewProjection = context.camera.viewProjectionMatrix
            encoder.setRenderPipelineState(pipelineState)
            if let depthState = pipeline.depthState {
                encoder.setDepthStencilState(depthState)
                observedDepthState = true
            }
            encoder.setVertexBytes(
                &viewProjection,
                length: MemoryLayout<simd_float4x4>.stride,
                index: 0
            )
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            issuedDraw = true
        }
    }
}

final class RenderExtensionSceneTargetAccessTest: BaseRenderSetup {
    func testProceduralGeometryExtensionIntegratesWithSceneGraphAndDraws() throws {
        let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct AcceptanceOut { float4 position [[position]]; float3 color; };
        vertex AcceptanceOut acceptanceVertex(
            uint vertexID [[vertex_id]],
            constant float4x4 &viewProjection [[buffer(0)]]) {
            float3 positions[3] = {
                float3(-0.5, 0.0, 0.0),
                float3( 0.5, 0.0, 0.0),
                float3( 0.0, 0.8, 0.0)
            };
            AcceptanceOut out;
            out.position = viewProjection * float4(positions[vertexID], 1.0);
            out.color = float3(0.1, 0.6, 0.9);
            return out;
        }
        fragment float4 acceptanceFragment(AcceptanceOut in [[stage_in]]) {
            return float4(in.color, 1.0);
        }
        """
        let library = try renderInfo.device.makeLibrary(source: source, options: nil)
        let renderExtension = ProceduralGeometryAcceptanceExtension(library: library)

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        let pipeline = try XCTUnwrap(RenderPipelineAccess().pipeline(renderExtension.pipelineID))
        XCTAssertNotNil(pipeline.pipelineState)
        XCTAssertNotNil(pipeline.depthState)

        let (graph, _) = try buildGameModeGraph()
        let pass = try XCTUnwrap(graph[renderExtension.passID])
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        pass.execute?(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        XCTAssertEqual(commandBuffer.status, .completed)
        XCTAssertTrue(renderExtension.observedCamera)
        XCTAssertTrue(renderExtension.observedPipeline)
        XCTAssertTrue(renderExtension.observedSceneTargets)
        XCTAssertTrue(renderExtension.observedDepthState)
        XCTAssertTrue(renderExtension.issuedDraw)

        setRendering(.extensions(.unregister(renderExtension.id)))
        XCTAssertNil(RenderPipelineAccess().pipeline(renderExtension.pipelineID))
        XCTAssertNil(RenderShaderLibraryManager.shared.library(renderExtension.libraryID))
        let (cleanGraph, _) = try buildGameModeGraph()
        XCTAssertNil(cleanGraph[renderExtension.passID])
    }

    func testDefaultDepthClearValueTracksReverseZ() {
        let original = renderInfo.reverseZEnabled
        defer { renderInfo.reverseZEnabled = original }

        renderInfo.reverseZEnabled = false
        XCTAssertEqual(SceneRenderPassActions().depthClearValue, 1)

        renderInfo.reverseZEnabled = true
        XCTAssertEqual(SceneRenderPassActions().depthClearValue, 0)
    }

    func testSceneDescriptorIsCopiedAndConfiguredWithoutMutatingEngineDescriptor() throws {
        let source = try makeSceneDescriptor(label: "copy")
        source.colorAttachments[0].loadAction = .clear
        source.colorAttachments[0].storeAction = .dontCare
        source.depthAttachment.loadAction = .clear
        source.depthAttachment.storeAction = .dontCare
        let actions = SceneRenderPassActions(
            colorLoadAction: .load,
            colorStoreAction: .store,
            colorClearValue: MTLClearColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4),
            depthLoadAction: .load,
            depthStoreAction: .store,
            depthClearValue: 0.25
        )

        let copy = try XCTUnwrap(makeSceneRenderPassDescriptor(copying: source, actions: actions))

        XCTAssertFalse(copy === source)
        XCTAssertTrue(copy.colorAttachments[0].texture === source.colorAttachments[0].texture)
        XCTAssertTrue(copy.depthAttachment.texture === source.depthAttachment.texture)
        XCTAssertEqual(copy.colorAttachments[0].loadAction, .load)
        XCTAssertEqual(copy.colorAttachments[0].storeAction, .store)
        XCTAssertEqual(copy.depthAttachment.loadAction, .load)
        XCTAssertEqual(copy.depthAttachment.storeAction, .store)
        XCTAssertEqual(copy.depthAttachment.clearDepth, 0.25)
        XCTAssertEqual(source.colorAttachments[0].loadAction, .clear)
        XCTAssertEqual(source.colorAttachments[0].storeAction, .dontCare)
        XCTAssertEqual(source.depthAttachment.loadAction, .clear)
        XCTAssertEqual(source.depthAttachment.storeAction, .dontCare)
    }

    func testContextCreatesSceneEncoderAtCompatibleStage() throws {
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let context = makeRenderPassContext(commandBuffer: commandBuffer, stage: .beforeTransparency)
        let encoder = try XCTUnwrap(
            context.sceneRenderTargets.makeRenderCommandEncoder(label: "Extension Scene Draw")
        )
        XCTAssertEqual(encoder.label, "Extension Scene Draw")
        encoder.endEncoding()
    }

    func testSceneEncoderIsUnavailableAtIncompatibleStage() throws {
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let access = try makeSceneRenderTargetAccess(
            commandBuffer: commandBuffer,
            stage: .beforeOutput,
            descriptor: makeSceneDescriptor(label: "unsupported")
        )
        XCTAssertNil(access.makeRenderCommandEncoder())
    }

    func testSceneDescriptorRejectsMissingOrIncompatibleDepthTarget() throws {
        let missingDepth = try makeSceneDescriptor(label: "missing-depth")
        missingDepth.depthAttachment.texture = nil
        XCTAssertNil(makeSceneRenderPassDescriptor(copying: missingDepth, actions: .loadAndStore))

        let mismatchedDepth = try makeSceneDescriptor(label: "mismatched-depth", depthSize: 8)
        XCTAssertNil(makeSceneRenderPassDescriptor(copying: mismatchedDepth, actions: .loadAndStore))
    }

    func testSceneDescriptorRejectsResolveStoreActionsForSingleSampleTargets() throws {
        let source = try makeSceneDescriptor(label: "resolve")
        let actions = SceneRenderPassActions(colorStoreAction: .multisampleResolve)
        XCTAssertNil(makeSceneRenderPassDescriptor(copying: source, actions: actions))
    }

    func testPerEyeDescriptorsRetainTheirOwnTargets() throws {
        let left = try makeSceneDescriptor(label: "left")
        let right = try makeSceneDescriptor(label: "right")
        let leftCopy = try XCTUnwrap(makeSceneRenderPassDescriptor(copying: left, actions: .loadAndStore))
        let rightCopy = try XCTUnwrap(makeSceneRenderPassDescriptor(copying: right, actions: .loadAndStore))

        XCTAssertTrue(leftCopy.colorAttachments[0].texture === left.colorAttachments[0].texture)
        XCTAssertTrue(leftCopy.depthAttachment.texture === left.depthAttachment.texture)
        XCTAssertTrue(rightCopy.colorAttachments[0].texture === right.colorAttachments[0].texture)
        XCTAssertTrue(rightCopy.depthAttachment.texture === right.depthAttachment.texture)
        XCTAssertFalse(leftCopy.colorAttachments[0].texture === rightCopy.colorAttachments[0].texture)
        XCTAssertFalse(leftCopy.depthAttachment.texture === rightCopy.depthAttachment.texture)
    }

    private func makeSceneDescriptor(
        label: String,
        colorSize: Int = 4,
        depthSize: Int = 4
    ) throws -> MTLRenderPassDescriptor {
        let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: renderInfo.colorPipeline.working.sceneColor,
            width: colorSize,
            height: colorSize,
            mipmapped: false
        )
        colorDescriptor.usage = .renderTarget
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: renderInfo.depthPixelFormat,
            width: depthSize,
            height: depthSize,
            mipmapped: false
        )
        depthDescriptor.usage = .renderTarget

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: colorDescriptor))
        descriptor.colorAttachments[0].texture?.label = "\(label)-color"
        descriptor.depthAttachment.texture = try XCTUnwrap(renderInfo.device.makeTexture(descriptor: depthDescriptor))
        descriptor.depthAttachment.texture?.label = "\(label)-depth"
        return descriptor
    }
}
