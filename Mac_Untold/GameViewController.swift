//
//  GameViewController.swift
//  UntoldEngine3D macOS
//
//  Created by Harold Serrano on 5/17/23.
//

import Cocoa
import MetalKit

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


