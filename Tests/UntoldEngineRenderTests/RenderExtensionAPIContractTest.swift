import Metal
import simd
@testable import UntoldEngine
import XCTest

final class RenderExtensionAPIContractTest: XCTestCase {
    func testCameraStateRetainsExplicitPerEyeValues() {
        var view = matrix_identity_float4x4
        view.columns.3 = SIMD4<Float>(-2, -3, -4, 1)
        var projection = matrix_identity_float4x4
        projection.columns.0.x = 2
        let viewProjection = simd_mul(projection, view)
        let state = RenderExtensionCameraState(
            viewMatrix: view,
            projectionMatrix: projection,
            viewProjectionMatrix: viewProjection,
            worldPosition: SIMD3<Float>(2, 3, 4)
        )

        XCTAssertEqual(state.viewMatrix, view)
        XCTAssertEqual(state.projectionMatrix, projection)
        XCTAssertEqual(state.viewProjectionMatrix, viewProjection)
        XCTAssertEqual(state.worldPosition, SIMD3<Float>(2, 3, 4))
    }

    func testCameraStateIdentityIsSafeContextDefault() {
        XCTAssertEqual(RenderExtensionCameraState.identity.viewMatrix, matrix_identity_float4x4)
        XCTAssertEqual(RenderExtensionCameraState.identity.projectionMatrix, matrix_identity_float4x4)
        XCTAssertEqual(RenderExtensionCameraState.identity.viewProjectionMatrix, matrix_identity_float4x4)
        XCTAssertEqual(RenderExtensionCameraState.identity.worldPosition, .zero)
    }

    func testCameraStateUsesDistinctPerEyeViewAndProjectionValues() {
        SceneRootTransform.shared.reset()
        var leftView = matrix_identity_float4x4
        leftView.columns.3.x = 0.03
        var rightView = matrix_identity_float4x4
        rightView.columns.3.x = -0.03
        var leftProjection = matrix_identity_float4x4
        leftProjection.columns.2.x = -0.02
        var rightProjection = matrix_identity_float4x4
        rightProjection.columns.2.x = 0.02

        let left = makeRenderExtensionCameraState(
            cameraViewMatrix: leftView,
            projectionMatrix: leftProjection
        )
        let right = makeRenderExtensionCameraState(
            cameraViewMatrix: rightView,
            projectionMatrix: rightProjection
        )

        XCTAssertEqual(left.viewMatrix, leftView)
        XCTAssertEqual(right.viewMatrix, rightView)
        XCTAssertEqual(left.projectionMatrix, leftProjection)
        XCTAssertEqual(right.projectionMatrix, rightProjection)
        XCTAssertNotEqual(left.viewProjectionMatrix, right.viewProjectionMatrix)
        XCTAssertEqual(left.worldPosition.x, -0.03, accuracy: 0.0001)
        XCTAssertEqual(right.worldPosition.x, 0.03, accuracy: 0.0001)
    }

    func testCameraStateAppliesSceneRootToViewAndWorldPosition() {
        SceneRootTransform.shared.position = SIMD3<Float>(5, 0, 0)
        SceneRootTransform.shared.updateIfNeeded()
        defer { SceneRootTransform.shared.reset() }

        let state = makeRenderExtensionCameraState(
            cameraViewMatrix: matrix_identity_float4x4,
            projectionMatrix: matrix_identity_float4x4
        )

        XCTAssertEqual(state.viewMatrix, SceneRootTransform.shared.matrix)
        XCTAssertEqual(state.worldPosition, SIMD3<Float>(-5, 0, 0))
    }

    func testRenderPipelineAccessLooksUpRegisteredPipelineAndObservesCleanup() {
        let pipelineID: RenderPipelineType = "test.api.contract.render.pipeline"
        let ownerID = "test.api.contract.owner"
        PipelineManager.shared.registerPipelines(ownerID: ownerID) { registry in
            registry.registerRenderPipeline(pipelineID) {
                RenderPipeline(success: true, name: "Contract Pipeline")
            }
        }
        defer { PipelineManager.shared.removePipelines(ownerID: ownerID) }

        let access = RenderPipelineAccess()
        XCTAssertEqual(access.pipeline(pipelineID)?.name, "Contract Pipeline")

        PipelineManager.shared.removePipelines(ownerID: ownerID)
        XCTAssertNil(access.pipeline(pipelineID))
    }

    func testRenderPipelineAccessReturnsNilForUnknownPipeline() {
        XCTAssertNil(RenderPipelineAccess().pipeline("test.api.contract.unknown"))
    }

    func testSceneRenderTargetAccessDefinesCompatibleSceneStages() {
        let supported: Set<RenderStage> = [
            .afterOpaqueLighting, .beforeTransparency, .afterTransparency, .beforePostProcess,
        ]

        for stage in RenderStage.allCases {
            XCTAssertEqual(
                SceneRenderTargetAccess.supports(stage), supported.contains(stage),
                "Unexpected scene-target compatibility for \(stage.rawValue)"
            )
        }
    }

    func testSceneRenderPassActionsDefaultToPreservingTargets() {
        let actions = SceneRenderPassActions.loadAndStore

        XCTAssertEqual(actions.colorLoadAction, .load)
        XCTAssertEqual(actions.colorStoreAction, .store)
        XCTAssertEqual(actions.depthLoadAction, .load)
        XCTAssertEqual(actions.depthStoreAction, .store)
    }
}

private final class LifecycleTrackingRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    var updates: [(Float, UInt64)] = []
    var fixedUpdates: [(Float, UInt64)] = []
    var resourcesDidLoadCount = 0
    var willUnregisterCount = 0

    init(id: String) {
        self.id = id
    }

    func update(deltaTime: Float, context: EngineExtensionUpdateContext) {
        updates.append((deltaTime, context.frameIndex))
    }

    func fixedUpdate(deltaTime: Float, context: EngineExtensionUpdateContext) {
        fixedUpdates.append((deltaTime, context.frameIndex))
    }

    func resourcesDidLoad(_: RenderResourceAccess) {
        resourcesDidLoadCount += 1
    }

    func willUnregister() {
        willUnregisterCount += 1
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

final class RenderExtensionLifecycleHookTest: XCTestCase {
    override func tearDown() {
        RenderExtensionRegistry.shared.removeAll()
        super.tearDown()
    }

    func testUpdateAndFixedUpdateDispatchInRegistrationOrder() {
        let first = LifecycleTrackingRenderExtension(id: "test.lifecycle.first")
        let second = LifecycleTrackingRenderExtension(id: "test.lifecycle.second")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(first), .registered)
        XCTAssertEqual(RenderExtensionRegistry.shared.register(second), .registered)

        let context = EngineExtensionUpdateContext(
            viewport: SIMD2<Int>(640, 480),
            immersionStyle: .none,
            frameIndex: 42,
            currentEye: 0,
            isPrimaryEye: true
        )

        RenderExtensionRegistry.shared.updateExtensions(deltaTime: 0.25, context: context)
        RenderExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)

        XCTAssertEqual(first.updates.count, 1)
        XCTAssertEqual(second.updates.count, 1)
        XCTAssertEqual(first.updates[0].0, 0.25)
        XCTAssertEqual(second.updates[0].1, 42)
        XCTAssertEqual(first.fixedUpdates.count, 1)
        XCTAssertEqual(second.fixedUpdates.count, 1)
    }

    func testResourceAndUnregisterHooksDispatchToRegisteredExtensions() {
        let extensionInstance = LifecycleTrackingRenderExtension(id: "test.lifecycle.resources")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(extensionInstance), .registered)
        XCTAssertEqual(extensionInstance.resourcesDidLoadCount, 1)

        RenderExtensionRegistry.shared.notifyResourcesDidLoad()
        XCTAssertEqual(extensionInstance.resourcesDidLoadCount, 2)

        RenderExtensionRegistry.shared.unregister(id: extensionInstance.id)
        XCTAssertEqual(extensionInstance.willUnregisterCount, 1)
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(extensionInstance.id))
    }

    func testReplacementCallsWillUnregisterOnPreviousExtension() {
        let original = LifecycleTrackingRenderExtension(id: "test.lifecycle.replace")
        let replacement = LifecycleTrackingRenderExtension(id: "test.lifecycle.replace")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(original), .registered)
        XCTAssertEqual(RenderExtensionRegistry.shared.register(replacement), .registered)

        XCTAssertEqual(original.willUnregisterCount, 1)
        XCTAssertEqual(replacement.willUnregisterCount, 0)
    }
}

final class RenderExtensionCameraContextTest: BaseRenderSetup {
    func testPassContextCapturesActiveCameraAndCurrentEye() throws {
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let component = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let originalView = component.viewSpace
        let originalProjection = renderInfo.perspectiveSpace
        let originalFrameIndex = renderInfo.frameIndex
        let originalEye = renderInfo.currentEye
        let originalStereoMode = renderInfo.isXRStereoMode
        defer {
            component.viewSpace = originalView
            renderInfo.perspectiveSpace = originalProjection
            renderInfo.frameIndex = originalFrameIndex
            renderInfo.currentEye = originalEye
            renderInfo.isXRStereoMode = originalStereoMode
            SceneRootTransform.shared.reset()
        }

        SceneRootTransform.shared.reset()
        var eyeView = matrix_identity_float4x4
        eyeView.columns.3 = SIMD4<Float>(-1, -2, -3, 1)
        var eyeProjection = matrix_identity_float4x4
        eyeProjection.columns.0.x = 1.5
        component.viewSpace = eyeView
        renderInfo.perspectiveSpace = eyeProjection
        renderInfo.frameIndex = 77
        renderInfo.isXRStereoMode = true
        renderInfo.currentEye = 1

        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        let context = makeRenderPassContext(commandBuffer: commandBuffer, stage: .beforeTransparency)

        XCTAssertEqual(context.currentEye, 1)
        XCTAssertEqual(context.frameIndex, 77)
        XCTAssertFalse(context.isPrimaryEye)
        XCTAssertEqual(context.camera.viewMatrix, eyeView)
        XCTAssertEqual(context.camera.projectionMatrix, eyeProjection)
        XCTAssertEqual(context.camera.viewProjectionMatrix, simd_mul(eyeProjection, eyeView))
        XCTAssertEqual(context.camera.worldPosition, SIMD3<Float>(1, 2, 3))
    }
}
