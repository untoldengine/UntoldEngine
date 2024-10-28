import UntoldEngine
import MetalKit



class GameScene{

    var renderer:UntoldRenderer!
    var player0:EntityID!

    init(_ metalView:MTKView){
        
        //set up the renderer here
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
        
        //callbacks to be updated
        
        renderer.gameUpdateCallback = {[weak self] deltaTime in
            self?.update(deltaTime)
        }
        
        renderer.handleInputCallback = {[weak self] in
            self?.handleInput() 
        }

        
        //load scene 
        loadScene(filename: "player1",withExtension: "usdc")
        loadScene(filename: "Plane" , withExtension: "usdc")
        loadScene(filename: "player2", withExtension: "usdc")
        loadBulkScene(filename: "trees", withExtension: "usdc")

        //set entity
        player0=createEntity()
       
        addMeshToEntity(entityId:player0,name:"soccer_player_0")   
        

        let player1:EntityID=createEntity()
        addMeshToEntity(entityId:player1,name:"soccer_player_1")

        translateTo(entityId: player1,position: simd_float3(3.0,0.0,0.0))

        let floorEntity:EntityID=createEntity()
        addMeshToEntity(entityId:floorEntity, name: "Plane")


        //Set lights 
        let sunEntity:EntityID=createEntity()

        let sun:DirectionalLight = DirectionalLight()

        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)

        //set point light 
        let pointEntity:EntityID=createEntity()

        var point:PointLight = PointLight()
        point.position=simd_float3(1.0,1.0,0.0)
        lightingSystem.addPointLight(entityID: pointEntity , light: point )

}

    func update(_ deltaTime:Float){
        movementSystem.update(player0, 0.01)
    }

    func handleInput(){


    }

}

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

        setupUI()
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

 private func setupUI() {

    // Create and configure the button
        loadScene_button = createButton(
            title: "Load Scene",
            relativeX: 0.1,
            relativeY: 0.95,
            width: 150,
            height: 50,
            target: self,
            action: #selector(loadUSD)
        )

        // Create and configure the slider
        positionZ_slider = createSlider(
            minValue: 0.0,
            maxValue: 100.0,
            initialValue: 50.0,
            relativeX: 0.5,
            relativeY: 0.3,
            width: 100,
            height: 20,
            target: self,
            action: #selector(sliderValueChanged)
        )

        self.view.addSubview(loadScene_button)
        //self.view.addSubview(positionZ_slider)

        /* setupVisualEffectView()
        setupTabView() */
}

    // Button factory function
    private func createButton(
        title: String,
        relativeX: CGFloat,
        relativeY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        target: AnyObject,
        action: Selector
    ) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        let x = relativeX * view.frame.width - width / 2
        let y = relativeY * view.frame.height - height / 2
        button.frame = NSRect(x: x, y: y, width: width, height: height)
        button.bezelStyle = .rounded
        return button
    }

    // Slider factory function
    private func createSlider(
        minValue: Double,
        maxValue: Double,
        initialValue: Double,
        relativeX: CGFloat,
        relativeY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        target: AnyObject,
        action: Selector
    ) -> NSSlider {
        let slider = NSSlider(value: initialValue, minValue: minValue, maxValue: maxValue, target: target, action: action)
        let x = relativeX * view.frame.width - width / 2
        let y = relativeY * view.frame.height - height / 2
        slider.frame = NSRect(x: x, y: y, width: width, height: height)
        slider.isContinuous = true
        return slider
    }

    private func setupVisualEffectView() {
        // Create a VisualEffectView with a blur effect
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar  // Blur style
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active  // Ensure it's always visible

        // Set the frame and add it to the main view
        visualEffectView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        self.view.addSubview(visualEffectView)
    }

    private func setupTabView() {
        // Create an NSTabView
        tabView = NSTabView()
        tabView.frame = NSRect(x: 10, y: 10, width: 380, height: 280)

        // Create the "Transforms" tab
        let transformsTab = NSTabViewItem(identifier: "Transforms")
        transformsTab.label = "Transforms"
        transformsTab.view = createLabel(withText: "Transforms Settings", frame: NSRect(x: 10, y: 10, width: 360, height: 40))

        // Create the "Lights" tab
        let lightsTab = NSTabViewItem(identifier: "Lights")
        lightsTab.label = "Lights"
        lightsTab.view = createLabel(withText: "Lights Settings", frame: NSRect(x: 10, y: 10, width: 360, height: 40))

        // Add the tabs to the tab view
        tabView.addTabViewItem(transformsTab)
        tabView.addTabViewItem(lightsTab)

        // Add the tab view to the visual effect view
        visualEffectView.addSubview(tabView)
    }

    private func createLabel(withText text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.alignment = .center
        return label
    }

    // Handle button click
    @objc private func loadUSD() {

    let openPanel = NSOpenPanel()
         openPanel.canChooseFiles = true
         openPanel.canChooseDirectories = false
         openPanel.allowsMultipleSelection = false

         guard openPanel.runModal() == NSApplication.ModalResponse.OK,
             let fileURL = openPanel.url else {
                 return
         }

    //load all assets
    print("Loading USD")
    loadScene(filename:fileURL, withExtension: fileURL.pathExtension)


    }

    // Handle slider value change
    @objc private func sliderValueChanged(_ sender: NSSlider) {
        print("Slider value: \(sender.doubleValue)")
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





