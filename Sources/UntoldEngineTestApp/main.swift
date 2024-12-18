import MetalKit
import UntoldEngine

// GameScene is where you would initialize your game and write the game logic.
class GameScene {
    let redPlayer: EntityID
    let bluePlayer: EntityID
    let stadium: EntityID

    let path = [
        simd_float3(0.0, 0.0, 0.0),
        simd_float3(5.0, 0.0, 0.0),
        simd_float3(5.0, 0.0, 5.0),
        simd_float3(0.0, 0.0, 5.0),
    ]

    init() {
        // set camera to look at point
        camera.lookAt(
            eye: simd_float3(0.0, 7.0, 15.0), target: simd_float3(0.0, 0.0, 0.0),
            up: simd_float3(0.0, 1.0, 0.0)
        )

        // You can load the assets in bulk as shown here.

        // create an entity id for the stadium
        stadium = createEntity()

        // this function loads the usdc file and sets the mesh model to the entity
        setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdc")

        // create an entity id for the blue player
        bluePlayer = createEntity()

        // this function loads the usdc file and sets the mesh model to the entity
        setEntityMesh(entityId: bluePlayer, filename: "blueplayer", withExtension: "usdc")

        // translate the entity
        translateBy(entityId: bluePlayer, position: simd_float3(3.0, 0.0, 0.0))

        // let's create another entity Id
        redPlayer = createEntity()

        // load the usdc file and link the model to the entity
        setEntityMesh(entityId: redPlayer, filename: "redplayer", withExtension: "usdc", flip: false)

        // load and link the animation to the entity. You should give a name to the animation
        setEntityAnimations(entityId: redPlayer, filename: "running", withExtension: "usdc", name: "running")

        // set the animation to play. You reference the animaitons by name
        changeAnimation(entityId: redPlayer, name: "running")

        // enable physics/kinetics on the entity
        setEntityKinetics(entityId: redPlayer)

        // You can also set a directional light. Notice that you need to create an entity first.
        let sunEntity: EntityID = createEntity()

        // Then you create a directional light
        let sun = DirectionalLight()

        // and finally, you add the entity and the directional light to the ligthting system.
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)

        // Same logic goes when you want to create an point light.
        let pointEntity: EntityID = createEntity()

        var point = PointLight()

        point.position = simd_float3(1.0, 1.0, 0.0)

        lightingSystem.addPointLight(entityID: pointEntity, light: point)
    }

    func update(deltaTime: Float) {
        // Steer towards the z direction. The entity must have
        // a kinetic component.
        steerTo(entityId: redPlayer, targetPosition: simd_float3(0.0, 0.0, 5.0), maxSpeed: 2.0, deltaTime: deltaTime)

        // rotate character
        rotateBy(entityId: bluePlayer, angle: 1.0, axis: simd_float3(0.0, 1.0, 0.0))
    }

    func handleInput() {}
}

// AppDelegate: Boiler plate code -- Handles everything – Renderer, Metal setup, and GameScene initialization
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var renderer: UntoldRenderer!
    var gameScene: GameScene!

    func applicationDidFinishLaunching(_: Notification) {
        print("Launching Untold Engine v0.2")

        // Step 1. Create and configure the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Untold Engine v0.2"
        window.center()

        // Step 2. Initialize the renderer and connect metal content
        guard let renderer = UntoldRenderer.create() else {
            print("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

        renderer.initResources()

        // Step 3. Create the game scene and connect callbacks
        gameScene = GameScene()
        renderer.setupCallbacks(
            gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
            handleInput: { [weak self] in self?.gameScene.handleInput() }
        )

        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}

// Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

app.run()
