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
     }
     
     override func flagsChanged(with event: NSEvent) {
         
         if event.modifierFlags.contains(.shift){
             
         }
     }
     
     
     override func mouseUp(with event: NSEvent){
         inputSystem.mouseUp(event)
     }
     
     override func mouseDown(with event: NSEvent) {
         inputSystem.mouseDown(event)
     }
     
     override func rightMouseUp(with event: NSEvent) {
         inputSystem.mouseUp(event)
     }
     
     override func rightMouseDown(with event: NSEvent) {
         inputSystem.mouseDown(event)
     }
     
     override func mouseMoved(with event: NSEvent) {
         print("mouse moving")
     }
     
     override func rightMouseDragged(with event: NSEvent) {
         
     }
     
     override func mouseDragged(with event: NSEvent) {
         
         inputSystem.mouseMoved(simd_float2(Float(event.deltaX),Float(event.deltaY)))
     }

     
     override func scrollWheel(with:NSEvent){
         inputSystem.handleMouseScroll(with)
     }
     
     
     @objc func handlePan(_ gestureRecognizer:NSPanGestureRecognizer){
             
         inputSystem.handlePanGesture(gestureRecognizer, in: mtkView)
//         if gameMode==true {return}
//         
//         let currentPanLocation=gestureRecognizer.translation(in: mtkView)
//         
//         if(gestureRecognizer.state == .began){
//             
//             //store the initial touch location
//             initialPanLocation=currentPanLocation
//             //let the orbit offset
//             camera.setOrbitOffset(uTargetOffset: length(camera.localPosition))
//         }
//         
//         if(gestureRecognizer.state == .changed){
//             //Calculate the deltas from the initial touch location
//             var deltaX=currentPanLocation.x-initialPanLocation.x
//             var deltaY=currentPanLocation.y-initialPanLocation.y
//             
//             if(abs(deltaX)<abs(deltaY)){
//                 deltaX=0.0
//             }else{
//                 deltaY=0.0
//                 deltaX = -1.0*deltaX
//             }
//
//             if(abs(deltaX)<=1.0){
//                 deltaX=0.0
//             }
//
//             if(abs(deltaY)<=1.0){
//                 deltaY=0.0
//             }
//             
//             // Add your code for touch moved here
//             let delta:simd_float2 = simd_float2(Float(deltaX),Float(deltaY))
//             inputSystem.mouseMoved(delta)
//             
//             
//             initialPanLocation=currentPanLocation
//         }
//         
//         if(gestureRecognizer.state == .ended){
//             
//             //Reset the initial location
//             initialPanLocation=nil
//         }
         
     }
     
     @objc func handlePinch(_ gestureRecognizer: NSMagnificationGestureRecognizer) {
      
         inputSystem.handlePinchGesture(gestureRecognizer, in: mtkView)
//         if gameMode==true {return}
//         
//         let currentScale = gestureRecognizer.magnification
//
//             if gestureRecognizer.state == .began {
//                 // store the initial scale
//                 previousScale = currentScale
//             } else if gestureRecognizer.state == .changed {
//                 //determine the direction of the pinch
//                 let scaleDiff=currentScale-previousScale
//                 let delta:simd_float3=3.0*simd_float3(0.0,0.0,Float(1.0)*Float(scaleDiff))
//         
//                 camera.moveCameraAlongAxis(uDelta: delta)
//                 
//                 previousScale=currentScale
//             } else if gestureRecognizer.state == .ended {
//                 previousScale=1.0
//             }
     }
     
     

 }


