//
//  GameViewController.m
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#import "GameViewController.h"
#import "U4DRenderer.h"
#include "U4DCamera.h"
#include "U4DController.h"

extern U4DEngine::U4DCamera camera;
extern U4DEngine::U4DController controller;

@implementation GameViewController
{
    MTKView *metalView;
    
    U4DRenderer *renderer;
    
    NSTrackingArea *trackingArea;
    
    bool shiftKey;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    metalView=(MTKView *)self.view;
    
    metalView.device=MTLCreateSystemDefaultDevice();
    
    metalView.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
    metalView.depthStencilPixelFormat=MTLPixelFormatDepth32Float;
    
    // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
    //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
    //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
    //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
    //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
    //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
    //   that we think our renderer can consistently maintain.
    metalView.preferredFramesPerSecond = 120;
    
    metalView.autoResizeDrawable=YES;
    
    if(!metalView.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }
    
    renderer = [[U4DRenderer alloc] initWithMetalKitView:metalView];
    
    if(!renderer)
    {
        NSLog(@"Renderer failed initialization");
        return;
    }
    
    [renderer mtkView:metalView drawableSizeWillChange:metalView.bounds.size];
    
    metalView.delegate = renderer;
    
//    //set device OS type
//    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
//
//    U4DEngine::DEVICEOSTYPE deviceOSType=U4DEngine::deviceOSMACX;
//
//    director->setDeviceOSType(deviceOSType);
    
    // notifications for controller (dis)connect
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
//    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    
    //tracking area used to detect if mouse is within window
    
    trackingArea=[[NSTrackingArea alloc] initWithRect:metalView.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:metalView userInfo:nil];
    
    [metalView addTrackingArea:trackingArea];
    
    //display screen backing change notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenScaleFactorChanged:) name:NSWindowDidChangeBackingPropertiesNotification object:nil];
    

    
}

- (void)viewWillAppear{
    
    [super viewWillAppear];
    [self.view.window makeFirstResponder:metalView];
    [self.view.window center];

}

- (void)viewDidAppear {
    
    [super viewDidAppear];
    
   
  

}

- (void)screenScaleFactorChanged:(NSNotification *)notification {
    

}

- (void)controllerWasConnected:(NSNotification *)notification {
    

    
}

- (void)controllerWasDisconnected:(NSNotification *)notification {
    

}

- (void)registerControllerInput {
    
    
}

- (void)flagsChanged:(NSEvent *)theEvent{
    
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];

    if (flags & NSEventModifierFlagShift)
    {
        //shift key pressed
        if(theEvent.keyCode==56){
            shiftKey=true;
        }

    }else{
        //shift key released
        if(theEvent.keyCode==56){
            shiftKey=false;
        }
    }
    
}

- (void)keyDown:(NSEvent *)theEvent
{

}

- (void)keyUp:(NSEvent *)theEvent
{
 

    
}

- (void)mouseEntered:(NSEvent *)theEvent {
    
}

- (void)mouseMoved:(NSEvent *)theEvent {
    
    

}

- (void)mouseExited:(NSEvent *)theEvent {
    
    
}

- (void)rightMouseDragged:(NSEvent*)event {

    float xDelta = [event deltaX];
    float yDelta = [event deltaY];

    simd::float2 mouseLocation { static_cast<float>( xDelta ), static_cast<float>( yDelta ) };

    controller.orbitCamera( mouseLocation );
}

- (void)mouseDragged:(NSEvent *)theEvent {
    float xDelta = [theEvent deltaX];
    float yDelta = [theEvent deltaY];

    simd::float2 delta { static_cast<float>( xDelta ), static_cast<float>( yDelta ) };

    controller.flyCamera( delta );
   
}

- (void)rightMouseDown:(NSEvent *)theEvent{
    
    controller.setOrbitTarget( simd::length(camera.localPosition) );
        
}

- (void)rightMouseUp:(NSEvent *)theEvent{
    

}

- (void)mouseDown:(NSEvent *)theEvent {
    

}

- (void)mouseUp:(NSEvent *)theEvent {
    

}

- (void)scrollWheel:(NSEvent *)theEvent{
    
    double wheelx=[theEvent scrollingDeltaX];
    double wheely=[theEvent scrollingDeltaY];
    
    if(std::abs(wheelx)<std::abs(wheely)){
        wheelx=0.0;
    }else{
        wheely=0.0;
        wheelx*=-1.0;
    }
    
    if(std::abs(wheelx) <= 1.0) wheelx=0.0;
    if(std::abs(wheely) <= 1.0) wheely=0.0;
    
    simd::float2 wheelDelta{(float)wheelx,(float)wheely};
    
    if(wheelx != 0.0 || wheely !=0.0){
        if(shiftKey){
            controller.dollyTrackBoom(simd::float3{0.0,wheelDelta.y,0.0}*0.01);
        }else{
            controller.dollyTrackBoom(simd::float3{-wheelDelta.x,0.0,wheelDelta.y}*0.01);
        }
        
    }
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    // [super didReceiveMemoryWarning];
    
}

@end



