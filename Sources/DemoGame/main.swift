import MetalKit
import UntoldEngine

// GameScene is where you would initialize your game and write the game logic.
class GameScene {
    // Declare entity IDs for the red player and ball
    let hollandPlayer: EntityID
    let ball: EntityID
    let playerSpeed: Float = 2.0

    init() {
        // Step 1: Configure the Camera
        camera.lookAt(
            eye: simd_float3(0.0, 7.0, 15.0), // Camera position
            target: simd_float3(0.0, 0.0, 0.0), // Look-at target
            up: simd_float3(0.0, 1.0, 0.0) // Up direction
        )

        // Step 2: Create a Stadium Entity
        let stadium = createEntity()
        setEntityMesh(entityId: stadium, filename: "soccerStadium", withExtension: "usdc")

        // Step 3: Create a Red Player Entity with Animation
        hollandPlayer = createEntity()
        setEntityMesh(entityId: hollandPlayer, filename: "hollandPlayer", withExtension: "usdc", flip: false)

        // Load animations for the red player
        setEntityAnimations(entityId: hollandPlayer, filename: "hollandRunningAnim", withExtension: "usdc", name: "hollandRunning")
        setEntityAnimations(entityId: hollandPlayer, filename: "hollandIdleAnim", withExtension: "usdc", name: "hollandIdle")

        // Start with the idle animation
        changeAnimation(entityId: hollandPlayer, name: "hollandIdle")

        // Enable physics for the red player
        setEntityKinetics(entityId: hollandPlayer)

        // Step 4: Create a Ball Entity
        ball = createEntity()
        setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdc")

        // Step 5: Assign the Ball as a Child of the Player
        setParent(childId: ball, parentId: hollandPlayer, offset: simd_float3(0.0, 0.6, 1.0))

        // Step 6: Create a Sun Entity for Directional Lighting
        let sunEntity: EntityID = createEntity()

        // Create the directional light instance
        let sun = DirectionalLight()

        // Add the light to the lighting system
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
    }

    func update(deltaTime: Float) {
        // Skip logic if not in game mode
        if gameMode == false {
            return
        }

        // Handle idle animation and physics pause
        if isWASDPressed() {
            changeAnimation(entityId: hollandPlayer, name: "hollandRunning")
            pausePhysicsComponent(entityId: hollandPlayer, isPaused: false)

        } else {
            changeAnimation(entityId: hollandPlayer, name: "hollandIdle")
            pausePhysicsComponent(entityId: hollandPlayer, isPaused: true)
            return
        }

        // Compute new position based on input
        var newPosition = getPosition(entityId: hollandPlayer)

        if inputSystem.keyState.wPressed {
            newPosition.z += 1.0
        }

        if inputSystem.keyState.sPressed {
            newPosition.z -= 1.0
        }

        if inputSystem.keyState.aPressed {
            newPosition.x -= 1.0
        }

        if inputSystem.keyState.dPressed {
            newPosition.x += 1.0
        }

        // Steer the player to the new position
        steerSeek(entityId: hollandPlayer, targetPosition: newPosition, maxSpeed: playerSpeed, deltaTime: deltaTime, turnSpeed: 5.0)

        // Rotate the ball around its local right axis
        rotateBy(entityId: ball, angle: 5.0, axis: getRightAxisVector(entityId: ball))
    }

    func handleInput() {
        // Skip logic if not in game mode
        if gameMode == false {
            return
        }
    }
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
