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
    
    self.gameScene.init(metalView);
    
    //tracking area used to detect if mouse is within window
    trackingArea=[[NSTrackingArea alloc] initWithRect:metalView.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:metalView userInfo:nil];
    
    [metalView addTrackingArea:trackingArea];

}

- (void)viewWillAppear{
    
    [super viewWillAppear];
    [self.view.window makeFirstResponder:metalView];
    [self.view.window center];

}

- (void)viewDidAppear {
    
    [super viewDidAppear];
    
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



