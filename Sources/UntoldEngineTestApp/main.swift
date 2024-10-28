import UntoldEngine
import MetalKit

// The GameScene class creates the Untold Engine Renderer and kicks off the game logic 

class GameScene{

    var renderer:UntoldRenderer!

    // main entity 
    var bluecar:EntityID!

    // camera follow parameters 
    var targetPosition:simd_float3=simd_float3(0.0,0.0,0.0)
    var offset:simd_float3=simd_float3(0.0,2.0,5.0)
    var smoothSpeed:Float=1.0 

    // opponent car parameters 
    var redcar:EntityID!
    var redCarVelocity:simd_float3=simd_float3(0.0,0.0,0.0)
    var redCarTargetPosition:simd_float3=simd_float3(-1.0,0.0,-230.0)
    var redCarMaxSpeed:Float=Float.random(in:15...25) 
    var redCarArrivalRadius:Float=2.0
    var redCarDeltaTime:Float=0.1

    var speedChangeInterval:Float=1.0 
    var timeSinceSpeedChanged:Float=0.0 


    init(_ metalView:MTKView){
        
        //set up the renderer
        guard let defaultDevice=MTLCreateSystemDefaultDevice() else {
            
            print("Metal is not supported on this device")
            return
            
        }
        
        metalView.device=defaultDevice
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.colorPixelFormat = .rgba16Float
        metalView.preferredFramesPerSecond = 60
        metalView.framebufferOnly = false
        
        guard let newRenderer = UntoldRenderer(metalView) else{
            print("The Untold Engine cannot be initialized")
            return
        }
        
        
        renderer = newRenderer
        renderer.mtkView(metalView, drawableSizeWillChange: metalView.drawableSize)
        
        metalView.delegate = renderer
        
        // sets the callbacks for updates and input-handling 
        renderer.gameUpdateCallback = {[weak self] deltaTime in
            self?.update(deltaTime)
        }
        
        renderer.handleInputCallback = {[weak self] in
            self?.handleInput() 
        }

    // set camera to look at point 
    camera.lookAt(
      eye: simd_float3(0.0, 6.0, 35.0), target: simd_float3(0.0, 2.0, 0.0),
      up: simd_float3(0.0, 1.0, 0.0))
        
        // You can load the assets in bulk as shown here. In this instance, racetrack contains multiple assets which do not require an entity id to be assigned.  
        loadBulkScene(filename: "racetrack", withExtension: "usdc")

        // You can also load the assets individually.   
        loadScene(filename: "bluecar", withExtension: "usdc")
        loadScene(filename: "redcar", withExtension: "usdc")

        //set entity for the blue car 
        bluecar=createEntity()
        
        // links the mesh in the bluecar.usdc file to the entity "bluecar"
        addMeshToEntity(entityId:bluecar, name:"bluecar")

        // translate the entity 
        translateTo(entityId:bluecar,position:simd_float3(1.0,0.0,20.0))


        // let's create another entity 
        redcar = createEntity()

        // Again, link the mesh to the entity "redcar"
        addMeshToEntity(entityId:redcar, name:"redcar")

        // And translate the entity 
        translateTo(entityId:redcar,position:simd_float3(-1.0,0.0,20.0))

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

    func update(_ deltaTime:Float){
        movementSystem.update(entityId: bluecar, deltaTime: 0.01)
        updateCameraFollow()
        updateOpponentMovement(entityId: redcar,dt: 0.01)
   }

    func handleInput(){


    }


    // Implements a simple camera follow algorithm
    func updateCameraFollow(){

        // gameMode is started/stopped by pressing the "l" key in your keyboard
        if gameMode == false {
            return
        }

        var cameraPosition:simd_float3=camera.getPosition()
        
        targetPosition=getPosition(entityId: bluecar)

        var desiredPosition:simd_float3=targetPosition+offset
 
        cameraPosition=lerp(start:cameraPosition,end:desiredPosition,t:smoothSpeed)

        camera.translateTo(cameraPosition.x,cameraPosition.y,cameraPosition.z)
    }

    func lerp(start:simd_float3,end:simd_float3,t:Float)->simd_float3{
         return start*(1.0-t)+end*t
    }

    
    func updateOpponentMovement(entityId:EntityID,dt:Float){
       

        if gameMode == false {
            return
        }

        timeSinceSpeedChanged += Float(TimeInterval(dt))


        //change speed randomly every few seconds 
        if timeSinceSpeedChanged >= speedChangeInterval{

            redCarMaxSpeed = Float.random(in: 19...45)
            timeSinceSpeedChanged = 0.0 //reset time
        }

        var redCarPosition=getPosition(entityId: entityId)
        
        //close enough
        if length(redCarTargetPosition-redCarPosition)<0.1{
            return 
        }

        var toTarget:simd_float3=redCarTargetPosition-redCarPosition

        var distance:Float=length(toTarget)

        //calculate the desired speed based on how close the car is to the target
        
        var desiredSpeed:Float 

        if(distance<redCarArrivalRadius){
            desiredSpeed = redCarMaxSpeed*(distance/redCarArrivalRadius)
        }else{
            desiredSpeed = redCarMaxSpeed
        }
        
        //calculate the desired velocity 
        var desiredVelocity=normalize(toTarget)*desiredSpeed

        //steering force:
        var steering:simd_float3=desiredVelocity-redCarVelocity

        //Euler integration to update position and velocity
        redCarVelocity=redCarVelocity+steering*dt    //v=v+a*t  
        redCarPosition=redCarPosition+redCarVelocity*dt  //x=x+v*t 

        translateTo(entityId: entityId, position: redCarPosition)

    }

}

// boiler plate class to set up the gameview controller. It initializes the Game Scene and inputs  
class GameViewController:NSViewController{

    var gameScene:GameScene!

    var mtkView:MTKView!
    var pinchGesture:NSMagnificationGestureRecognizer!
    var panGesture:NSPanGestureRecognizer!
    var clickGesture:NSClickGestureRecognizer!

    var initialPanLocation: CGPoint!
    var initialTwoPanLocation: CGPoint!
    var previousScale:CGFloat=1.0
    var initialModelPanLocation: CGPoint!
    var modelDraggedVertically:Bool = false

    var loadScene_button:NSButton!
    var positionZ_slider:NSSlider!

    var visualEffectView: NSVisualEffectView!
    var tabView: NSTabView!

    override func loadView(){
        //create a MTKView 
        self.view = MTKView(frame: NSRect(x:0,y:0,width: 800,height: 600))

    }

    override func viewDidLoad(){

        super.viewDidLoad()

        guard let metalView=self.view as? MTKView else{
                
                print("View attached to GameviewController is not an MTKView");
                return
            }

        mtkView=metalView

        // starts off the game scene 
        gameScene=GameScene(mtkView)

        enableKeyDetection()


        pinchGesture=NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

         panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

         clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
         clickGesture.buttonMask=0x2 //represents the right mouse
         mtkView.addGestureRecognizer(pinchGesture)
         mtkView.addGestureRecognizer(panGesture)
         mtkView.addGestureRecognizer(clickGesture)


        // Ensure the view is set as the first responder after setup
        DispatchQueue.main.async {
            self.view.window?.makeFirstResponder(self)
        }

    }


    
    override func viewDidAppear() {
        super.viewDidAppear()
        self.view.window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {

         inputSystem.handlePinchGesture(gestureRecognizer, in: mtkView)

     }


    @objc func handlePan(_ gestureRecognizer:NSPanGestureRecognizer){
        inputSystem.handlePanGesture(gestureRecognizer, in: mtkView)
    }

    @objc func handleClick(_ gestureRecognizer:NSClickGestureRecognizer){

    }

    override func scrollWheel(with:NSEvent){
        inputSystem.handleMouseScroll(with)
     }


    override func flagsChanged(with event: NSEvent) {

         if event.modifierFlags.contains(.shift){

         }
     }
    
    func enableKeyDetection(){

         NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { (theEvent) -> NSEvent? in
                 if theEvent.modifierFlags.contains(.shift) {
                     if theEvent.keyCode == 56 { // this is Shif key pressed
                  
                        inputSystem.keyState.shiftPressed=true
                     }
                 }
                 else {
                     if theEvent.keyCode == 56 { // this is Shif key released
                         inputSystem.keyState.shiftPressed=false
                     }
                 }

             if theEvent.modifierFlags.contains(.control) {
                 if theEvent.keyCode == 59 { // this is control key pressed
                     inputSystem.keyState.ctrlPressed=true
                 }
             }
             else {
                 if theEvent.keyCode == 59 { // this is control key released
                     inputSystem.keyState.ctrlPressed=false
                 }
             }
    
        return theEvent
       
       }


        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in

             //if gameMode==false {return nil}

             inputSystem.keyPressed(event.keyCode)

             // Return nil to mark the event as handled
             return nil
         }

         NSEvent.addLocalMonitorForEvents(matching: .keyUp) { (event) -> NSEvent? in

             inputSystem.keyReleased(event.keyCode)

             // Return nil to mark the event as handled
             return nil
         }

         // Adding a local monitor for mouse down events
         NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { (event) -> NSEvent? in

             inputSystem.mouseDown(event)

             return event
         }

         // Adding a local monitor for mouse dragged events
         NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { (event) -> NSEvent? in

             inputSystem.mouseMoved(simd_float2(Float(event.deltaX),Float(event.deltaY)))

             return event
         }

         // Adding a local monitor for mouse up events
         NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { (event) -> NSEvent? in

             inputSystem.mouseUp(event)
             return event
         }

    }

}


// Setup code to create a Metal window,
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var gameViewController:GameViewController!

     func applicationDidFinishLaunching(_ notification: Notification) {
        print("Entering app did finish app")
        //create a window for your amazing game 

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        gameViewController = GameViewController()
        window.contentViewController = gameViewController

        window.center()
        //show the window 
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(gameViewController)
        window.title = "Untold Engine v2.0"


        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}



//Entry point 

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate


app.run()





