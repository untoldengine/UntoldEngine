#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    // MARK: - Resources

    /// #filePath anchors to this file at compile time, so the repo root is always
    /// 4 levels up: DemoUtils/ → Demos/ → Sources/ → repo root.
    public func demoResourcesURL() -> URL {
        let here = URL(fileURLWithPath: #filePath)
        return here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Tests/UntoldEngineRenderTests/Resources")
    }

    // MARK: - Engine Configuration

    public func configureDemoEngine(
        assetBasePath: URL? = nil,
        registerKeyboard: Bool = false,
        registerMouse: Bool = true
    ) {
        gameMode = true
        setSceneReady(false)
        if let basePath = assetBasePath {
            setEngine(.assetBasePath(basePath))
        }
        setRendering(.postProcessing(.enabled))
        setRendering(.antiAliasing(.fxaa))
        setRendering(.environment(.ibl(true)))
        setRendering(.environment(.visible(false)))
        if registerKeyboard {
            InputSystem.shared.registerKeyboardEvents()
        }
        if registerMouse {
            InputSystem.shared.registerMouseEvents()
        }
    }

    // MARK: - Camera

    @discardableResult
    public func makeDemoCamera(
        name: String = "Main Camera",
        eye: simd_float3,
        target: simd_float3 = .zero,
        orbitOffset: Float? = nil
    ) -> EntityID {
        let camera = createEntity()
        setEntityName(entityId: camera, name: name)
        createGameCamera(entityId: camera)
        cameraLookAt(entityId: camera, eye: eye, target: target, up: simd_float3(0, 1, 0))
        if let offset = orbitOffset {
            setOrbitOffset(entityId: camera, uTargetOffset: offset)
        }
        setCamera(.active(camera))
        return camera
    }

    // MARK: - Lighting

    @discardableResult
    public func makeDemoSunLight(
        name: String = "Sun",
        pitch: Float = -50.0,
        color: simd_float3 = simd_float3(1.0, 0.94, 0.86),
        intensity: Float = 1.5
    ) -> EntityID {
        let sun = createEntity()
        setEntityName(entityId: sun, name: name)
        createDirLight(entityId: sun)
        rotateTo(entityId: sun, angle: pitch, axis: simd_float3(1, 0, 0))
        setLight(entityId: sun, .color(color))
        setLight(entityId: sun, .intensity(intensity))
        setLight(entityId: sun, .directional(.active))
        return sun
    }
#endif
