import UntoldEngine
import MetalKit

// GameScene is where you would initialize your game and write the game logic. 
class GameScene {

    // entity which we will control with the WASD keys  
    var bluecar:EntityID!

    // camera follow parameters 
    var targetPosition:simd_float3=simd_float3(0.0,0.0,0.0)
    var offset:simd_float3=simd_float3(0.0,4.0,8.0)
    var smoothSpeed:Float=1.0 

    // opponent car parameters 
    var cars:[Car]=[]

    init() {

        // set camera to look at point 
        camera.lookAt(
          eye: simd_float3(0.0, 6.0, 35.0), target: simd_float3(0.0, 2.0, 0.0),
          up: simd_float3(0.0, 1.0, 0.0))
            
        // You can load the assets in bulk as shown here. 
        // In this instance, racetrack contains multiple assets which do not require an entity id to be assigned.  
        loadBulkScene(filename: "racetrack", withExtension: "usdc")

        // You can also load the assets individually.   
        loadScene(filename: "bluecar", withExtension: "usdc")
        loadScene(filename: "redcar", withExtension: "usdc")
        loadScene(filename: "yellowcar", withExtension: "usdc")
        loadScene(filename: "orangecar", withExtension: "usdc")


        //set entity for the blue car 
        bluecar=createEntity()
        
        // links the mesh in the bluecar.usdc file to the entity "bluecar"
        addMeshToEntity(entityId:bluecar, name:"bluecar")

        // translate the entity 
        translateTo(entityId:bluecar,position:simd_float3(2.5,0.75,20.0))

        //Create instances for each opponent car 
        let redCar:Car=Car(name:"redcar", position: simd_float3(-2.5,0.75,20.0))
        let yellowCar:Car=Car(name:"yellowcar", position: simd_float3(-2.5,0.75,10.0))
        let orangeCar:Car=Car(name:"redcar", position: simd_float3(2.5,0.75,10.0))

        cars.append(redCar)
        cars.append(yellowCar)
        cars.append(orangeCar)

        // You can also set a directional light. Notice that you need to create an entity first. 
        let sunEntity:EntityID=createEntity()

        // Then you create a directional light 
        let sun:DirectionalLight = DirectionalLight()

        // and finally, you add the entity and the directional light to the ligthting system. 
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)

        // Same logic goes when you want to create an point light.
        let pointEntity:EntityID=createEntity()

        var point:PointLight = PointLight()
        
        point.position=simd_float3(1.0,1.0,0.0)
        
        lightingSystem.addPointLight(entityID: pointEntity , light: point )

    }
    
    func update(_ deltaTime: Float) {

        moveCar(entityId:bluecar, dt: deltaTime)
        
        updateCameraFollow()

        for car in cars{
            car.update(dt: deltaTime)
        }


    }

    func handleInput() {

    }

    func moveCar(entityId: EntityID, dt: Float){

        if gameMode == false {
            return 
        }

        var speed:Float = 33.0
        var offset:Float = 3.5

        var position:simd_float3 = getPosition(entityId: entityId)

        var forward:simd_float3 = getForwardVector(entityId:entityId)

        let up: simd_float3 = simd_float3(0.0, 1.0, 0.0)

        var right: simd_float3 = cross(forward, up)
        
        right = normalize(right)

        if inputSystem.keyState.wPressed == true{
            position+=forward*speed*dt 
        }

        if inputSystem.keyState.sPressed == true{
            position-=forward*speed*dt 
        }

        if inputSystem.keyState.aPressed == true{
            position-=right*speed*dt 
        }

        if inputSystem.keyState.dPressed == true{
            position+=right*speed*dt 
        }

        translateTo(entityId:bluecar, position: position)
    }

    // Implements a simple camera follow algorithm which follows the bluecar 
    func updateCameraFollow(){

        // gameMode is started/stopped by pressing the "l" key in your keyboard
        if gameMode == false {
            return
        }

        var cameraPosition:simd_float3=camera.getPosition()
        
        targetPosition=getPosition(entityId: bluecar)

        targetPosition.x = 0.0
        let desiredPosition:simd_float3=targetPosition+offset
 
        cameraPosition=lerp(start:cameraPosition,end:desiredPosition,t:smoothSpeed)

        camera.translateTo(cameraPosition.x,cameraPosition.y,cameraPosition.z)
    }

    func lerp(start:simd_float3,end:simd_float3,t:Float)->simd_float3{
         return start*(1.0-t)+end*t
    }


}

// AppDelegate: Boiler plate code -- Handles everything – Renderer, Metal setup, and GameScene initialization
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var metalView: MTKView!
    var renderer: UntoldRenderer!
    var gameScene: GameScene!

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        print("Launching Untold Engine v0.2")

        // Create and configure the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        metalView = MTKView(frame: window.contentView!.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.colorPixelFormat = .rgba16Float
        metalView.preferredFramesPerSecond = 60
        metalView.framebufferOnly = false

        // Initialize the renderer and set it as the MTKView delegate
        renderer = UntoldRenderer(metalView)
        renderer?.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        metalView.delegate = renderer

        // Create the game scene
        gameScene = GameScene()

        // Connect renderer callbacks to the game scene
        renderer.gameUpdateCallback = { [weak self] deltaTime in
            self?.gameScene.update(deltaTime)
        }
        renderer.handleInputCallback = { [weak self] in
            self?.gameScene.handleInput()
        }

        // Set up window and display it
        window.contentView = metalView
        window.makeKeyAndOrderFront(nil)
        window.center()
        window.title = "Untold Engine v0.2"

        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate


app.run()





