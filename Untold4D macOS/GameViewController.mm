//
//  GameViewController.m
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#import "GameViewController.h"
#import "U4DRenderer.h"
#import "U4DDirector.h"
#import "U4DLights.h"
#import "U4DCamera.h"
#include "U4DTouches.h"
#include "U4DLogger.h"
#include "U4DVector2n.h"
#include "MainScene.h"
#include "CommonProtocols.h"

@implementation GameViewController
{
    MTKView *metalView;
    
    U4DRenderer *renderer;
    
    NSTrackingArea *trackingArea;
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    metalView=(MTKView *)self.view;
    
    metalView.device=MTLCreateSystemDefaultDevice();
    
    metalView.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
    
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
    
    // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
    //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
    //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
    //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
    //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
    //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
    //   that we think our renderer can consistently maintain.
    metalView.preferredFramesPerSecond = 60;
    
    //set device OS type
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::DEVICEOSTYPE deviceOSType=U4DEngine::deviceOSMACX;
    
    director->setDeviceOSType(deviceOSType);
    
    // notifications for controller (dis)connect
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    
    //tracking area used to detect if mouse is within window
    
    trackingArea=[[NSTrackingArea alloc] initWithRect:metalView.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:metalView userInfo:nil];
    
    [metalView addTrackingArea:trackingArea];
    
    //If using the keyboard, then set it to false. If using a controller then set it to true
    director->setGamePadControllerPresent(false);

}

- (void)viewDidAppear {
    
    [super viewDidAppear];
    
    //initialize the scene for your game
    MainScene *mainScene=new MainScene();
    mainScene->init();
}

- (void)controllerWasConnected:(NSNotification *)notification {
    
    // a controller was connected
    GCController *controller = (GCController *)notification.object;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    
    if (controller.extendedGamepad!=nil) {

        logger->log("Controller has an Extended gamepad");

    }else if (controller.gamepad!=nil){
        
        logger->log("Controller has a standard profile");
        
    }
    
    logger->log("Controller is connected");
    
    [self registerControllerInput];
    
}

- (void)controllerWasDisconnected:(NSNotification *)notification {
    
    // a controller was disconnected
    //GCController *controller = (GCController *)notification.object;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    
    logger->log("Controller is disconnected");
    
}

- (void)registerControllerInput {
    // register block for input change detection
    
    GCController *controller=[GCController controllers][0];
    
    GCExtendedGamepad *profile=controller.extendedGamepad;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    
    if (profile!=nil) {
        
        profile.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element)
        {
            U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
            
            //set up the element profiles
            U4DEngine::GAMEPADELEMENT padButtonAElement=U4DEngine::padButtonA;
            U4DEngine::GAMEPADELEMENT padButtonBElement=U4DEngine::padButtonB;
            U4DEngine::GAMEPADELEMENT padButtonXElement=U4DEngine::padButtonX;
            U4DEngine::GAMEPADELEMENT padButtonYElement=U4DEngine::padButtonY;
            U4DEngine::GAMEPADELEMENT padLeftThumbstickElement=U4DEngine::padLeftThumbstick;
            U4DEngine::GAMEPADELEMENT padRightThumbstickElement=U4DEngine::padRightThumbstick;
            U4DEngine::GAMEPADELEMENT padLeftTriggerElement=U4DEngine::padLeftTrigger;
            U4DEngine::GAMEPADELEMENT padRightTriggerElement=U4DEngine::padRightTrigger;
            U4DEngine::GAMEPADELEMENT padLeftShoulderElement=U4DEngine::padLeftShoulder;
            U4DEngine::GAMEPADELEMENT padRightShoulderElement=U4DEngine::padRightShoulder;
            U4DEngine::GAMEPADELEMENT padDPadUpButtonElement=U4DEngine::padDPadUpButton;
            U4DEngine::GAMEPADELEMENT padDPadDownButtonElement=U4DEngine::padDPadDownButton;
            U4DEngine::GAMEPADELEMENT padDPadLeftButtonElement=U4DEngine::padDPadLeftButton;
            U4DEngine::GAMEPADELEMENT padDPadRightButtonElement=U4DEngine::padDPadRightButton;
            
            //set up the actions
            U4DEngine::GAMEPADACTION padButtonPressedAction=U4DEngine::padButtonPressed;
            U4DEngine::GAMEPADACTION padButtonReleasedAction=U4DEngine::padButtonReleased;
            U4DEngine::GAMEPADACTION padThumbstickMovedAction=U4DEngine::padThumbstickMoved;
            U4DEngine::GAMEPADACTION padThumbstickReleasedAction=U4DEngine::padThumbstickReleased;
            
            // left trigger
            if (gamepad.leftTrigger == element && gamepad.leftTrigger.isPressed) {
                
                director->padPressBegan(padLeftTriggerElement,padButtonPressedAction);
                
            }else if(gamepad.leftTrigger == element && !gamepad.leftTrigger.isPressed){
                
                director->padPressEnded(padLeftTriggerElement,padButtonReleasedAction);
                
            }
            
            // right trigger
            if (gamepad.rightTrigger == element && gamepad.rightTrigger.isPressed) {
                
                director->padPressBegan(padRightTriggerElement,padButtonPressedAction);
                
            }else if(gamepad.rightTrigger == element && !gamepad.rightTrigger.isPressed){
                
                director->padPressEnded(padRightTriggerElement,padButtonReleasedAction);
            }
            
            // left shoulder button
            if (gamepad.leftShoulder == element && gamepad.leftShoulder.isPressed) {
                
                director->padPressBegan(padLeftShoulderElement,padButtonPressedAction);
                
            }else if(gamepad.leftShoulder == element && !gamepad.leftShoulder.isPressed){
                
                director->padPressEnded(padLeftShoulderElement,padButtonReleasedAction);
            }
            
            // right shoulder button
            if (gamepad.rightShoulder == element && gamepad.rightShoulder.isPressed) {
                
                director->padPressBegan(padRightShoulderElement,padButtonPressedAction);
                
            }else if(gamepad.rightShoulder == element && !gamepad.rightShoulder.isPressed){
                
                director->padPressEnded(padRightShoulderElement,padButtonReleasedAction);
                
            }
            
            // A button
            if (gamepad.buttonA == element && gamepad.buttonA.isPressed) {
                
                director->padPressBegan(padButtonAElement,padButtonPressedAction);
                
            }else if(gamepad.buttonA == element && !gamepad.buttonA.isPressed){
                
                director->padPressEnded(padButtonAElement,padButtonReleasedAction);
                
            }
            
            // B button
            if (gamepad.buttonB == element && gamepad.buttonB.isPressed) {
                
                director->padPressBegan(padButtonBElement,padButtonPressedAction);
                
            }else if(gamepad.buttonB == element && !gamepad.buttonB.isPressed){
                
                director->padPressEnded(padButtonBElement,padButtonReleasedAction);
                
            }
            
            // X button
            if (gamepad.buttonX == element && gamepad.buttonX.isPressed) {
                
                director->padPressBegan(padButtonXElement,padButtonPressedAction);
                
            }else if(gamepad.buttonX == element && !gamepad.buttonX.isPressed){
                
                director->padPressEnded(padButtonXElement,padButtonReleasedAction);
                
            }
            
            // Y button
            if (gamepad.buttonY == element && gamepad.buttonY.isPressed) {
                
                director->padPressBegan(padButtonYElement,padButtonPressedAction);
                
            }else if(gamepad.buttonY == element && !gamepad.buttonY.isPressed){
                
                director->padPressEnded(padButtonYElement,padButtonReleasedAction);
                
            }
            
            // d-pad
            if (gamepad.dpad == element) {
                
                if (gamepad.dpad.up.isPressed) {
                    
                    director->padPressBegan(padDPadUpButtonElement,padButtonPressedAction);
                    
                }else if(!gamepad.dpad.up.isPressed){
                 
                    director->padPressEnded(padDPadUpButtonElement,padButtonReleasedAction);
                }
                
                if (gamepad.dpad.down.isPressed) {
                    
                    director->padPressBegan(padDPadDownButtonElement,padButtonPressedAction);
                    
                }else if(!gamepad.dpad.down.isPressed){
                    
                    director->padPressEnded(padDPadDownButtonElement,padButtonReleasedAction);
                    
                }
                
                if (gamepad.dpad.left.isPressed) {
                    
                    director->padPressBegan(padDPadLeftButtonElement,padButtonPressedAction);
                    
                }else if(!gamepad.dpad.left.isPressed){
                    
                    director->padPressEnded(padDPadLeftButtonElement,padButtonReleasedAction);
                    
                }
                
                if (gamepad.dpad.right.isPressed) {
                    
                    director->padPressBegan(padDPadRightButtonElement,padButtonPressedAction);
                    
                }else if(!gamepad.dpad.right.isPressed){
                    
                    director->padPressEnded(padDPadRightButtonElement,padButtonReleasedAction);
                    
                }
                
            }
            
            // left stick
            if (gamepad.leftThumbstick == element) {
                
                if (gamepad.leftThumbstick.up.isPressed || gamepad.leftThumbstick.down.isPressed || gamepad.leftThumbstick.left.isPressed || gamepad.leftThumbstick.right.isPressed) {
                    
                    U4DEngine::U4DPadAxis padAxis(gamepad.leftThumbstick.xAxis.value,gamepad.leftThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padLeftThumbstickElement, padThumbstickMovedAction, padAxis);
                    
                }else if(!gamepad.leftThumbstick.up.isPressed && !gamepad.leftThumbstick.down.isPressed && !gamepad.leftThumbstick.left.isPressed && !gamepad.leftThumbstick.right.isPressed){
                    
                    U4DEngine::U4DPadAxis padAxis(gamepad.leftThumbstick.xAxis.value,gamepad.leftThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padLeftThumbstickElement, padThumbstickReleasedAction, padAxis);
                    
                }
                
            }
            
            // right stick
            if (gamepad.rightThumbstick == element) {
                
                if (gamepad.rightThumbstick.up.isPressed || gamepad.rightThumbstick.down.isPressed || gamepad.rightThumbstick.left.isPressed || gamepad.rightThumbstick.right.isPressed) {
                    
                    U4DEngine::U4DPadAxis padAxis(gamepad.rightThumbstick.xAxis.value,gamepad.rightThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padRightThumbstickElement, padThumbstickMovedAction, padAxis);
                    
                }else if(!gamepad.rightThumbstick.up.isPressed && !gamepad.rightThumbstick.down.isPressed && !gamepad.rightThumbstick.left.isPressed && !gamepad.rightThumbstick.right.isPressed){
                    
                    U4DEngine::U4DPadAxis padAxis(gamepad.rightThumbstick.xAxis.value,gamepad.rightThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padRightThumbstickElement, padThumbstickReleasedAction, padAxis);
                    
                }
                
            }
            
        };
        
    }else{
        
        logger->log("Game Controller profile is null");
        
    }
    
}

- (void)flagsChanged:(NSEvent *)theEvent{
    
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    
    U4DEngine::KEYBOARDELEMENT shiftKey=U4DEngine::macShiftKey;
    
    U4DEngine::KEYBOARDACTION keyPressed=U4DEngine::macKeyPressed;
    U4DEngine::KEYBOARDACTION keyReleased=U4DEngine::macKeyReleased;
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    if (flags & NSEventModifierFlagShift)
    {
        //shift key pressed
        if(theEvent.keyCode==56){
             director->macKeyPressBegan(shiftKey, keyPressed);
        }
        
    }else{
        //shift key released
        if(theEvent.keyCode==56){
            director->macKeyPressEnded(shiftKey, keyReleased);
        }
    }
    
}

- (void)keyDown:(NSEvent *)theEvent
{
   
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    unichar character = [[theEvent characters] characterAtIndex:0];
    
    U4DEngine::KEYBOARDELEMENT keyA=U4DEngine::macKeyA;
    U4DEngine::KEYBOARDELEMENT keyD=U4DEngine::macKeyD;
    U4DEngine::KEYBOARDELEMENT keyW=U4DEngine::macKeyW;
    U4DEngine::KEYBOARDELEMENT keyS=U4DEngine::macKeyS;
    
    U4DEngine::KEYBOARDELEMENT spaceKey=U4DEngine::macSpaceKey;
    
    U4DEngine::KEYBOARDACTION keyPressed=U4DEngine::macKeyPressed;
    
    U4DEngine::KEYBOARDELEMENT arrowKey=U4DEngine::macArrowKey;
    U4DEngine::KEYBOARDACTION arrowKeyActive=U4DEngine::macArrowKeyActive;
    
    
    if(character=='a' || character=='A'){
        director->macKeyPressBegan(keyA, keyPressed);
        
    }
    
    if(character=='d' || character=='D'){
        director->macKeyPressBegan(keyD, keyPressed);
        
    }
    
    if(character=='w' || character=='W'){
        director->macKeyPressBegan(keyW, keyPressed);
        
    }
    
    if(character=='s' || character=='S'){
        director->macKeyPressBegan(keyS, keyPressed);
        
    }
    
    if(character==' '){
        director->macKeyPressBegan(spaceKey, keyPressed);
    }
    
    if(character==NSUpArrowFunctionKey || character==NSDownArrowFunctionKey || character==NSLeftArrowFunctionKey || character==NSRightArrowFunctionKey){
        
        U4DEngine::U4DVector2n padAxis;
        
        if (character==NSUpArrowFunctionKey) {
            padAxis=U4DEngine::U4DVector2n(0.0,1.0);
            
        }else if(character==NSDownArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(0.0,-1.0);
            
        }else if(character==NSLeftArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(-1.0,0.0);
            
        }else if(character==NSRightArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(1.0,0.0);
        }
        
        director->macArrowKeyActive(arrowKey, arrowKeyActive, padAxis);
        
    }
    
}

- (void)keyUp:(NSEvent *)theEvent
{
 
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    unichar character = [[theEvent characters] characterAtIndex:0];
    
    U4DEngine::KEYBOARDELEMENT keyA=U4DEngine::macKeyA;
    U4DEngine::KEYBOARDELEMENT keyD=U4DEngine::macKeyD;
    U4DEngine::KEYBOARDELEMENT keyW=U4DEngine::macKeyW;
    U4DEngine::KEYBOARDELEMENT keyS=U4DEngine::macKeyS;
    
    U4DEngine::KEYBOARDELEMENT spaceKey=U4DEngine::macSpaceKey;
    
    U4DEngine::KEYBOARDACTION keyReleased=U4DEngine::macKeyReleased;
    
    U4DEngine::KEYBOARDELEMENT arrowKey=U4DEngine::macArrowKey;
    U4DEngine::KEYBOARDACTION arrowKeyReleased=U4DEngine::macArrowKeyReleased;
    
    if(character=='a' || character=='A'){
        director->macKeyPressEnded(keyA, keyReleased);
        
    }
    
    if(character=='d' || character=='D'){
        director->macKeyPressEnded(keyD, keyReleased);
        
    }
    
    if(character=='w' || character=='W'){
        director->macKeyPressEnded(keyW, keyReleased);
        
    }
    
    if(character=='s' || character=='S'){
        director->macKeyPressEnded(keyS, keyReleased);
        
    }
    
    if(character==' '){
        director->macKeyPressEnded(spaceKey, keyReleased);
    }
    
    if(character==NSUpArrowFunctionKey || character==NSDownArrowFunctionKey || character==NSLeftArrowFunctionKey || character==NSRightArrowFunctionKey){
        
        U4DEngine::U4DVector2n padAxis;
        
        if (character==NSUpArrowFunctionKey) {
            padAxis=U4DEngine::U4DVector2n(0.0,1.0);
            
        }else if(character==NSDownArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(0.0,-1.0);
            
        }else if(character==NSLeftArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(-1.0,0.0);
            
        }else if(character==NSRightArrowFunctionKey){
            
            padAxis=U4DEngine::U4DVector2n(1.0,0.0);
        }
        
        padAxis*=-1.0;
        
        director->macArrowKeyActive(arrowKey, arrowKeyReleased, padAxis);
        
    }
    
}

- (void)mouseEntered:(NSEvent *)theEvent {
    
}

- (void)mouseMoved:(NSEvent *)theEvent {
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();

    U4DEngine::MOUSEELEMENT mouseCursorElement=U4DEngine::mouseCursor;
    U4DEngine::MOUSEACTION mouseCursorMoved=U4DEngine::mouseCursorMoved;

    NSPoint mouseDownPos = [theEvent locationInWindow];

    float xPosition=(mouseDownPos.x-metalView.frame.size.width/2)/(metalView.frame.size.width/2);
    float yPosition=(mouseDownPos.y-metalView.frame.size.height/2)/(metalView.frame.size.height/2);
    
    U4DEngine::U4DVector2n mouseLocation(xPosition,yPosition);
    
    director->macMouseMoved(mouseCursorElement, mouseCursorMoved,mouseLocation);
    
}

- (void)mouseExited:(NSEvent *)theEvent {
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::MOUSEELEMENT mouseCursorElement=U4DEngine::mouseCursor;
    U4DEngine::MOUSEACTION mouseCursorExited=U4DEngine::mouseCursorExited;
    
    NSPoint mouseDownPos = [theEvent locationInWindow];
    
    float xPosition=(mouseDownPos.x-metalView.frame.size.width/2)/(metalView.frame.size.width/2);
    float yPosition=(mouseDownPos.y-metalView.frame.size.height/2)/(metalView.frame.size.height/2);
    
    U4DEngine::U4DVector2n mouseLocation(xPosition,yPosition);
    
    director->macMouseExited(mouseCursorElement, mouseCursorExited,mouseLocation);
    
}

- (void)mouseDragged:(NSEvent *)theEvent {
 
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::MOUSEELEMENT mouseLeftButtonElement=U4DEngine::mouseLeftButton;
    U4DEngine::MOUSEACTION mouseButtonDragged=U4DEngine::mouseButtonDragged;
    
    NSPoint mouseDownPos = [theEvent locationInWindow];
    
    U4DEngine::U4DVector2n mouseLocation(mouseDownPos.x,mouseDownPos.y);
    
    director->macMouseDragged(mouseLeftButtonElement, mouseButtonDragged,mouseLocation);
    
}

- (void)mouseDown:(NSEvent *)theEvent {
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::MOUSEELEMENT mouseLeftButtonElement=U4DEngine::mouseLeftButton;
    U4DEngine::MOUSEACTION mouseButtonPressed=U4DEngine::mouseButtonPressed;
    
    NSPoint mouseDownPos = [theEvent locationInWindow];
    
    U4DEngine::U4DVector2n mouseLocation(mouseDownPos.x,mouseDownPos.y);
    
    director->macMousePressBegan(mouseLeftButtonElement, mouseButtonPressed,mouseLocation);
    
}

- (void)mouseUp:(NSEvent *)theEvent {
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::MOUSEELEMENT mouseLeftButtonElement=U4DEngine::mouseLeftButton;
    U4DEngine::MOUSEACTION mouseButtonReleased=U4DEngine::mouseButtonReleased;
    
    director->macMousePressEnded(mouseLeftButtonElement, mouseButtonReleased);

}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)didReceiveMemoryWarning
{
    // [super didReceiveMemoryWarning];
    
}

@end



