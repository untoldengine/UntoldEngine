import UntoldEngine
import MetalKit



class GameScene{

    var renderer:UntoldRenderer!

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


        //load up model 


    }

    func update(_ deltaTime:Float){
        movementSystem.update(activeEntity, 0.01)
    }

    func handleInput(){}

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

             if gameMode==false {return nil}

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
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
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
        window.title = "Untold Engine"

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





