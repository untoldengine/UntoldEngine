//
//  GameViewController.swift
//  UntoldEngine3D macOS
//
//  Created by Harold Serrano on 5/17/23.
//

import Cocoa
import MetalKit
/*
// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: EditorRenderer!
    var mtkView: MTKView!
    var controlKey:Bool=false
    var shiftKey:Bool=false
    var pinchGesture:NSMagnificationGestureRecognizer!
    var panGesture:NSPanGestureRecognizer!
    
    var initialPanLocation: CGPoint!
    var initialTwoPanLocation: CGPoint!
    var previousScale:CGFloat=1.0
    var maximumTapLength:Double=0.5
    
    var initialMouseLocation: NSPoint = NSPoint.zero
    let panDistanceThreshold: Float = 20.0
    
    var initialExtrudePosition:NSPoint=NSPoint.zero
    let thresholdDistance: Float = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let metalView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        mtkView=metalView
        
        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        mtkView.colorPixelFormat = .rgba16Float
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false
        
        guard let newRenderer = EditorRenderer(mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        
        //Only apply this for the Editor.
        colorPicker.deactivate()
        
        let ta = NSTrackingArea(rect: CGRect.zero, options: [.activeAlways, .inVisibleRect, .mouseMoved], owner: self, userInfo: nil)
        self.view.addTrackingArea(ta)
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { (theEvent) -> NSEvent? in
                if theEvent.modifierFlags.contains(.shift) {
                    if theEvent.keyCode == 56 { // this is Shif key pressed
                        self.shiftKey=true
                    }
                }
                else {
                    if theEvent.keyCode == 56 { // this is Shif key released
                        self.shiftKey=false
                    }
                }
            
            if theEvent.modifierFlags.contains(.control) {
                if theEvent.keyCode == 59 { // this is control key pressed
                    self.controlKey=true
                }
            }
            else {
                if theEvent.keyCode == 59 { // this is control key released
                    self.controlKey=false
                }
            }
            
                
            
                return theEvent
            }
        
        
        //Detect keys
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
//                    guard let keyCode = KeyCode(rawValue: event.keyCode) else {
//                        return event
//                    }
                    
            switch event.keyCode {
                        
            case 123: //left arrow
                extrudePlane(extrutionSign: -1.0)
            case 124: //right arrow
                extrudePlane(extrutionSign: 1.0)
            case 125: //down arrow
                extrudePlane(extrutionSign: -1.0)
            case 126: //up arrow
                extrudePlane(extrutionSign: 1.0)
                
            case KeyCode.A.rawValue:
                        // Handle the "A" key press here
                        voxelAction = .add
                        self.addVoxelButton.state = .on
                        self.removeVoxelButton.state = .off
                        self.paintVoxelButton.state = .off
            case KeyCode.S.rawValue:
                        // Handle the "S" key press here
                        voxelAction = .remove
                        self.addVoxelButton.state = .off
                        self.removeVoxelButton.state = .on
                        self.paintVoxelButton.state = .off
                        
            case KeyCode.C.rawValue:
                        // Handle the "C" key press here
                        voxelAction = .color
                        self.addVoxelButton.state = .off
                        self.removeVoxelButton.state = .off
                        self.paintVoxelButton.state = .on
            case KeyCode.U.rawValue:
                        // Handle the "U" key press here
                        undoOperation()
            case KeyCode.R.rawValue:
                        // Handle the "R" key press here
                        redoOperation()
                    //case .X:
                        
                        
                        
//                    case .Q:
//                        undoOperation()
//                    case .W:
//                        redoOperation()
//                    case .E:
//
            default:
                print("nothing")
            }
                    
            return event
        }
        
        pinchGesture=NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        
        panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        
        mtkView.addGestureRecognizer(pinchGesture)
        mtkView.addGestureRecognizer(panGesture)
        
    }
    
    @IBAction func OpenVoxelData(_ sender: Any) {
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        guard openPanel.runModal() == NSApplication.ModalResponse.OK,
            let fileURL = openPanel.url else {
                return
        }
    
        if let voxelDataArray: [VoxelData] = readArrayOfStructsFromFile(filePath: fileURL.lastPathComponent, directoryURL: fileURL.deletingLastPathComponent()) {
            
            deserializer(dataArray: voxelDataArray)
            
        } else {
            print("Failed to read the array of structs from the file.")
        }
        
    }
    
    
    @IBAction func SaveVoxelData(_ sender: Any) {
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        
        guard savePanel.runModal() == NSApplication.ModalResponse.OK,
            let fileURL = savePanel.url else {
                return
        }
        
        renderer.serializeVoxels(filePath: fileURL.lastPathComponent, directoryURL: fileURL.deletingLastPathComponent())
    }
    
    @IBAction func removeAllVoxels(_ sender: Any) {
        renderer.removeAllVoxels()
    }
    
    @IBOutlet weak var addVoxelButton: NSButton!
    
    @IBOutlet weak var removeVoxelButton: NSButton!
    
    @IBOutlet weak var paintVoxelButton: NSButton!
    
    @IBAction func addvoxel(_ sender: Any) {
        voxelAction = .add
        
        removeVoxelButton.state = .off
        paintVoxelButton.state = .off
        rougnessVoxelButton.state = .off
        metallicVoxelBuffon.state = .off
    }
    
    
    @IBAction func removevoxel(_ sender: Any) {
        voxelAction = .remove
        addVoxelButton.state = .off
        paintVoxelButton.state = .off
        rougnessVoxelButton.state = .off
        metallicVoxelBuffon.state = .off
    }
    
    
    @IBAction func colorchange(_ sender: Any) {
        voxelAction = .color
        
        removeVoxelButton.state = .off
        addVoxelButton.state = .off
        rougnessVoxelButton.state = .off
        metallicVoxelBuffon.state = .off
    }
    
    
    @IBOutlet weak var colorPicker: NSColorWell!
    
    
    @IBAction func colorPickerChanger(_ sender: NSColorWell) {
        
        let selectedColor = sender.color
        // Perform the desired logic with the selectedColor
        var red:CGFloat=0
        var green:CGFloat=0
        var blue:CGFloat=0
        var alpha:CGFloat=0
        
        selectedColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let newColor:simd_float3=simd_float3(Float(red),Float(green),Float(blue))
        
        if newColor == colorSelected{
            return
        }
        
        previousColorSelected=colorSelected
        
        colorSelected=newColor
        
    }
    
    
    @IBAction func RoughnessSlider(_ sender: Any) {
        
        if let slider = sender as? NSSlider {
        // Get the slider's current value
        let sliderValue = slider.doubleValue
        RoughnessValue.doubleValue=sliderValue
        RoughnessValue.stringValue = String(format: "%.2f", sliderValue)
        
        previousRoughnessSelected=roughnessSelected
        roughnessSelected=Float(sliderValue)
        }
        
    }
    
    
    @IBOutlet weak var RoughnessValue: NSTextField!
    
    
    @IBOutlet weak var MetallicValue: NSTextField!
    
    
    
    @IBAction func MetallicSlider(_ sender: Any) {
        
        if let slider = sender as? NSSlider {
        // Get the slider's current value
        let sliderValue = slider.doubleValue
        MetallicValue.doubleValue=sliderValue
        MetallicValue.stringValue = String(format: "%.2f", sliderValue)
            
        previousMetallicSelected=metallicSelected
        metallicSelected=Float(sliderValue)
        }
        
    }
    
    @IBAction func ApplyRoughness(_ sender: Any) {
        voxelAction = .roughness
        addVoxelButton.state = .off
        removeVoxelButton.state = .off
        paintVoxelButton.state = .off
        metallicVoxelBuffon.state = .off
    }
    
    @IBOutlet weak var rougnessVoxelButton: NSButton!
    
    
    
    @IBAction func LightXPosition(_ sender: Any) {
        
        if let slider = sender as? NSSlider {
        // Get the slider's current value
        let sliderValue = slider.doubleValue
            lightingSystem.dirLight.direction.x=Float(sliderValue);
        }
        
        
    }
    
    
    @IBAction func LightYPosition(_ sender: Any) {
        
        if let slider = sender as? NSSlider {
        // Get the slider's current value
        let sliderValue = slider.doubleValue
            lightingSystem.dirLight.direction.y=Float(sliderValue);
        }
    }
    
    
    @IBAction func LightZPosition(_ sender: Any) {
        
        if let slider = sender as? NSSlider {
        // Get the slider's current value
        let sliderValue = slider.doubleValue
            lightingSystem.dirLight.direction.z=Float(sliderValue);
        }
    }
    
    
    @IBAction func ApplyMetallic(_ sender: Any) {
        
        voxelAction = .metallic
        addVoxelButton.state = .off
        removeVoxelButton.state = .off
        paintVoxelButton.state = .off
        rougnessVoxelButton.state = .off
        
    }
    
    @IBOutlet weak var metallicVoxelBuffon: NSButton!
    
    
    
    
    @objc func handlePan(_ gestureRecognizer:NSPanGestureRecognizer){
            
        let currentPanLocation=gestureRecognizer.translation(in: mtkView)
        let absLocation=gestureRecognizer.location(in: mtkView)
        let overlayLocation = gestureRecognizer.location(in: mtkView)
        
        var sliderHit = false
        if(mtkView==nil) {
            return
        };
        for subview in mtkView.subviews {
        if subview is NSSlider && subview.frame.contains(overlayLocation) {
            // Touch is within a slider's bounds, return early to let the slider handle it
                sliderHit = true
                break
            }
        }
        
        if sliderHit {
            // Disable the pan gesture to let the slider handle the event
            gestureRecognizer.isEnabled = false
            gestureRecognizer.isEnabled = true // Re-enable it after the touch event is handled
            return
        }
        
        if(gestureRecognizer.state == .began){
            
            //store the initial touch location
            initialPanLocation=currentPanLocation
            initialMouseLocation=currentPanLocation
            //let the orbit offset
            controller.setOrbitOffset(uTargetOffset: length(camera.localPosition))
        }
        
        if(gestureRecognizer.state == .changed){
            //print("changing pan")
            //Calculate the deltas from the initial touch location
            var deltaX=currentPanLocation.x-initialPanLocation.x
            var deltaY=currentPanLocation.y-initialPanLocation.y
            
            if(abs(deltaX)<abs(deltaY)){
                deltaX=0.0
            }else{
                deltaY=0.0
                deltaX = -1.0*deltaX
            }

            if(abs(deltaX)<=1.0){
                deltaX=0.0
            }

            if(abs(deltaY)<=1.0){
                deltaY=0.0
            }
            
            // Add your code for touch moved here
            let delta:simd_float2 = simd_float2(Float(deltaX*0.005),Float(deltaY*0.005))
            camera.orbitAround(delta)
            
            initialPanLocation=currentPanLocation
        }
        
        if(gestureRecognizer.state == .ended){
            let diff:Float=simd_length(simd_float2(Float(currentPanLocation.x-initialMouseLocation.x),Float(currentPanLocation.y-initialMouseLocation.y)))
            
            //sometimes, there can be a small movement from the user as he/she finishes panning and clicks to add voxel. This section allows the user to add a voxel if there is such small delta
            if(diff < panDistanceThreshold){
                
                getAllVoxelsInBox(uMouseLocation: simd_float2(Float(currentPanLocation.x),Float(currentPanLocation.y)))
                
            }
            //Reset the initial location
            initialPanLocation=nil
        }
        
    }
    
    @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {
     
        let currentScale = gestureRecognizer.magnification

            if gestureRecognizer.state == .began {
                // store the initial scale
                previousScale = currentScale
            } else if gestureRecognizer.state == .changed {
                //determine the direction of the pinch
                let scaleDiff=currentScale-previousScale
                var delta:simd_float3=3.0*simd_float3(0.0,0.0,Float(1.0)*Float(scaleDiff))
        
                controller.moveCameraAlongAxis(uDelta: delta)
                
                previousScale=currentScale
            } else if gestureRecognizer.state == .ended {
                previousScale=1.0
            }
    }
    override func flagsChanged(with event: NSEvent) {
        
        if event.modifierFlags.contains(.shift){
            
        }
    }
    
    
    override func mouseUp(with:NSEvent){
        
        let position:CGPoint=with.locationInWindow
        
        getAllVoxelsInBox(uMouseLocation: simd_float2(Float(position.x),Float(position.y)))
        
    }
    
    func distanceBetweenPoints(_ point1: NSPoint, _ point2: NSPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return hypot(dx, dy)
    }
    
    
    override func scrollWheel(with:NSEvent){
        
        var deltaX:Double=with.scrollingDeltaX
        var deltaY:Double=with.scrollingDeltaY

        if(abs(deltaX)<abs(deltaY)){
            deltaX=0.0
        }else{
            deltaY=0.0
            deltaX = -1.0*deltaX
        }

        if(abs(deltaX)<=1.0){
            deltaX=0.0
        }

        if(abs(deltaY)<=1.0){
            deltaY=0.0
        }

        var delta:simd_float3=0.01*simd_float3(Float(deltaX),0.0,Float(deltaY))

        if(deltaX != 0.0 || deltaY != 0.0){

            if shiftKey{
                delta=0.01*simd_float3(0.0,Float(deltaY),0.0)
                controller.moveCameraAlongAxis(uDelta: delta)
            }
            controller.moveCameraAlongAxis(uDelta: delta)
        }
        
    }
    override func mouseMoved(with: NSEvent) {
        
        if(selectionMode == .multipleselectionmoving || selectionMode == .multipleselectionstart){ return }
        let position:NSPoint=with.locationInWindow
        
        shootRay(uMouseLocation: simd_float2(Float(position.x),Float(position.y)))
        
    }
    override func mouseDragged(with:NSEvent){

        
    }
    override func rightMouseDown(with event: NSEvent) {
        let position:NSPoint=event.locationInWindow
        initialExtrudePosition=position
        if(selectionMode == .multipleselectionmoving || selectionMode == .extrude){
            
            getHighlightBoxNormal(uMouseLocation: simd_float2(Float(position.x),Float(position.y)))
            selectionMode = .extrude
            return
        }
        
        selectionMode = .multipleselectionstart
        shootRay(uMouseLocation: simd_float2(Float(position.x),Float(position.y)))
    }
    
    
    override func rightMouseDragged(with event: NSEvent) {
        let position:NSPoint=event.locationInWindow
        
        if selectionMode == .extrude{
            
            var delta=event.deltaX
            var distance:Float=Float(abs(position.x-initialExtrudePosition.x))
            
            if planeToExtrude.y == 1.0 || planeToExtrude.y == -1.0{
            
                delta = event.deltaY
                distance=Float(abs(position.y-initialExtrudePosition.y))
                
            }else if planeToExtrude.x == 1.0 || planeToExtrude.x == -1.0{
                delta *= -1.0
            }

            var signValue:Float=1.0
            
            if delta >= 0.0{
            
                signValue = -1.0
            }
            
            if distance > thresholdDistance && delta != 0.0{
                extrudePlane(extrutionSign: signValue)
                initialExtrudePosition=position
            }
            
            
            return
        }
        
        selectionMode = .multipleselectionmoving
        shootRay(uMouseLocation: simd_float2(Float(position.x),Float(position.y)))
        
    }
    
//    override func rightMouseDown(with event: NSEvent) {
//        //set the camera offset used for camera orbit
//
//
//        controller.setOrbitOffset(uTargetOffset: length(camera.localPosition))
//    }
    
//    override func rightMouseDragged(with event: NSEvent) {
//        var deltaX = event.deltaX
//        var deltaY = event.deltaY
//
//        if(abs(deltaX)<abs(deltaY)){
//            deltaX=0.0
//        }else{
//            deltaY=0.0
//            deltaX = -1.0*deltaX
//        }
//
//        if(abs(deltaX)<=1.0){
//            deltaX=0.0
//        }
//
//        if(abs(deltaY)<=1.0){
//            deltaY=0.0
//        }
//
//        if shiftKey==true{
//            var delta:simd_float2 = simd_float2(Float(deltaX),Float(-deltaY))
//            controller.panTilt(uDelta: &delta)
//            return
//        }
//        var delta:simd_float2 = simd_float2(Float(deltaX*0.005),Float(deltaY*0.005))
//        camera.orbitAround(delta)
//
//
//    }
    
}
*/


 //  Created by Harold Serrano on 5/17/23.
 //

 import Cocoa
 import MetalKit

 // Our macOS specific view controller
 class GameViewController: NSViewController {
     
     //var renderer: Renderer!
     var gameScene:GameScene!
     var mtkView: MTKView!
     var controlKey:Bool=false
     var shiftKey:Bool=false
     
     var pinchGesture:NSMagnificationGestureRecognizer!
     var panGesture:NSPanGestureRecognizer!
     
     var initialPanLocation: CGPoint!
     var initialTwoPanLocation: CGPoint!
     var previousScale:CGFloat=1.0
     var maximumTapLength:Double=0.5
     
     var initialMouseLocation: NSPoint = NSPoint.zero
     let panDistanceThreshold: Float = 20.0
     
     
     override func viewDidLoad() {
         super.viewDidLoad()
         
         guard let metalView = self.view as? MTKView else {
             print("View attached to GameViewController is not an MTKView")
             return
         }
         
         mtkView=metalView
         
         gameScene=GameScene(mtkView)
         
         pinchGesture=NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
         
         panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
         
         mtkView.addGestureRecognizer(pinchGesture)
         mtkView.addGestureRecognizer(panGesture)
         
         
         NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
                    
             controller.keyPressed(event.keyCode)
             
             return event
         }
         
         NSEvent.addLocalMonitorForEvents(matching: .keyUp) { (event) -> NSEvent? in
                    
             controller.keyReleased(event.keyCode)
             
             return event
         }
     }
     
     override func flagsChanged(with event: NSEvent) {
         
         if event.modifierFlags.contains(.shift){
             
         }
     }
     
     
     override func mouseUp(with:NSEvent){
         
     }
     
//     override func keyUp(with event: NSEvent) {
//         
//     }
//     
//     override func keyDown(with event: NSEvent) {
//         controller.keyPressed(event.keyCode)
//     }
     
     override func scrollWheel(with:NSEvent){
         
             var deltaX:Double=with.scrollingDeltaX
             var deltaY:Double=with.scrollingDeltaY
     
             if(abs(deltaX)<abs(deltaY)){
                 deltaX=0.0
             }else{
                 deltaY=0.0
                 deltaX = -1.0*deltaX
             }
     
             if(abs(deltaX)<=1.0){
                 deltaX=0.0
             }
     
             if(abs(deltaY)<=1.0){
                 deltaY=0.0
             }
     
             var delta:simd_float3=0.01*simd_float3(Float(deltaX),0.0,Float(deltaY))
     
             if(deltaX != 0.0 || deltaY != 0.0){
     
                 if shiftKey{
                     delta=0.01*simd_float3(0.0,Float(deltaY),0.0)
                     controller.moveCameraAlongAxis(uDelta: delta)
                 }
                 controller.moveCameraAlongAxis(uDelta: delta)
             }
         
     }
     
     @IBAction func LightXPosition(_ sender: Any) {
         
         if let slider = sender as? NSSlider {
         // Get the slider's current value
         let sliderValue = slider.doubleValue
             lightingSystem.dirLight.direction.x=Float(sliderValue);
         }
         
         
     }
     
     
     @IBAction func LightYPosition(_ sender: Any) {
         
         if let slider = sender as? NSSlider {
         // Get the slider's current value
         let sliderValue = slider.doubleValue
             lightingSystem.dirLight.direction.y=Float(sliderValue);
         }
     }
     
     
     @IBAction func LightZPosition(_ sender: Any) {
         
         if let slider = sender as? NSSlider {
         // Get the slider's current value
         let sliderValue = slider.doubleValue
             lightingSystem.dirLight.direction.z=Float(sliderValue);
         }
     }
     
     
     @objc func handlePan(_ gestureRecognizer:NSPanGestureRecognizer){
             
         let currentPanLocation=gestureRecognizer.translation(in: mtkView)
         let absLocation=gestureRecognizer.location(in: mtkView)
         let overlayLocation = gestureRecognizer.location(in: mtkView)
         
         var sliderHit = false
         if(mtkView==nil) {
             return
         };
         for subview in mtkView.subviews {
         if subview is NSSlider && subview.frame.contains(overlayLocation) {
             // Touch is within a slider's bounds, return early to let the slider handle it
                 sliderHit = true
                 break
             }
         }
         
         if sliderHit {
             // Disable the pan gesture to let the slider handle the event
             gestureRecognizer.isEnabled = false
             gestureRecognizer.isEnabled = true // Re-enable it after the touch event is handled
             return
         }
         
         if(gestureRecognizer.state == .began){
             
             //store the initial touch location
             initialPanLocation=currentPanLocation
             initialMouseLocation=currentPanLocation
             //let the orbit offset
             controller.setOrbitOffset(uTargetOffset: length(camera.localPosition))
         }
         
         if(gestureRecognizer.state == .changed){
             //print("changing pan")
             //Calculate the deltas from the initial touch location
             var deltaX=currentPanLocation.x-initialPanLocation.x
             var deltaY=currentPanLocation.y-initialPanLocation.y
             
             if(abs(deltaX)<abs(deltaY)){
                 deltaX=0.0
             }else{
                 deltaY=0.0
                 deltaX = -1.0*deltaX
             }

             if(abs(deltaX)<=1.0){
                 deltaX=0.0
             }

             if(abs(deltaY)<=1.0){
                 deltaY=0.0
             }
             
             // Add your code for touch moved here
             let delta:simd_float2 = simd_float2(Float(deltaX*0.005),Float(deltaY*0.005))
             camera.orbitAround(delta)
             
             initialPanLocation=currentPanLocation
         }
         
         if(gestureRecognizer.state == .ended){
             let diff:Float=simd_length(simd_float2(Float(currentPanLocation.x-initialMouseLocation.x),Float(currentPanLocation.y-initialMouseLocation.y)))
             
             //sometimes, there can be a small movement from the user as he/she finishes panning and clicks to add voxel. This section allows the user to add a voxel if there is such small delta
             if(diff < panDistanceThreshold){
                                 
             }
             //Reset the initial location
             initialPanLocation=nil
         }
         
     }
     
     @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {
      
         let currentScale = gestureRecognizer.magnification

             if gestureRecognizer.state == .began {
                 // store the initial scale
                 previousScale = currentScale
             } else if gestureRecognizer.state == .changed {
                 //determine the direction of the pinch
                 let scaleDiff=currentScale-previousScale
                 var delta:simd_float3=3.0*simd_float3(0.0,0.0,Float(1.0)*Float(scaleDiff))
         
                 controller.moveCameraAlongAxis(uDelta: delta)
                 
                 previousScale=currentScale
             } else if gestureRecognizer.state == .ended {
                 previousScale=1.0
             }
     }
     
     

 }


