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
#include "U4DControllerInterface.h"
#include "U4DSceneManager.h"
#include "SandboxScene.h"
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
    
    // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
    //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
    //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
    //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
    //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
    //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
    //   that we think our renderer can consistently maintain.
    metalView.preferredFramesPerSecond = 30;
    
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
    
    //set device OS type
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::DEVICEOSTYPE deviceOSType=U4DEngine::deviceOSMACX;
    
    director->setDeviceOSType(deviceOSType);
    
    // notifications for controller (dis)connect
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasConnected:) name:GCControllerDidConnectNotification object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(controllerWasDisconnected:) name:GCControllerDidDisconnectNotification object:nil];
    
    //tracking area used to detect if mouse is within window
    
    trackingArea=[[NSTrackingArea alloc] initWithRect:metalView.frame options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:metalView userInfo:nil];
    
    [metalView addTrackingArea:trackingArea];
    
    //display screen backing change notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenScaleFactorChanged:) name:NSWindowDidChangeBackingPropertiesNotification object:nil];
    
    //If using the keyboard, then set it to false. If using a controller then set it to true
    director->setGamePadControllerPresent(false);

}

- (void)viewDidAppear {
    
    [super viewDidAppear];
    
    //get screen backing scale
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    float contentScale = [[[NSApplication sharedApplication] mainWindow] backingScaleFactor];
    director->setScreenScaleFactor(contentScale);
    
    //call the scene manager
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

    //initialize the scene for your game
    SandboxScene *sandboxScene=new SandboxScene();
    
    sceneManager->changeScene(sandboxScene);
    
}

- (void)screenScaleFactorChanged:(NSNotification *)notification {
    
    float contentScale = [[[NSApplication sharedApplication] mainWindow] backingScaleFactor];
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    director->setScreenScaleFactor(contentScale);
}

- (void)controllerWasConnected:(NSNotification *)notification {
    
    // a controller was connected
    GCController *controller = (GCController *)notification.object;
    
    U4DEngine::U4DLogger *logger=U4DEngine::U4DLogger::sharedInstance();
    
    if (controller.extendedGamepad!=nil) {

        logger->log("Controller has an Extended gamepad");

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
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();

    if (profile!=nil && gameController!=nullptr) {

        profile.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element)
        {
            
            gameController->getUserInputData(gamepad, element);
            

        };

    }else{

        logger->log("Game Controller profile is null");

    }
    
}

- (void)flagsChanged:(NSEvent *)theEvent{
    
    NSUInteger flags = [[NSApp currentEvent] modifierFlags];
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();

    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
            
        if (flags & NSEventModifierFlagShift)
        {
            //shift key pressed
            if(theEvent.keyCode==56){
                 
                gameController->getUserInputData(U4DEngine::macShiftKey, U4DEngine::macKeyPressed);
                
            }

        }else{
            //shift key released
            if(theEvent.keyCode==56){
                
                gameController->getUserInputData(U4DEngine::macShiftKey, U4DEngine::macKeyReleased);
                
            }
        }
        
    }
    
    
}

- (void)keyDown:(NSEvent *)theEvent
{
   
    unichar character = [[theEvent characters] characterAtIndex:0];
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
        
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
            
            gameController->getUserInputData(U4DEngine::macArrowKey, U4DEngine::macArrowKeyActive, padAxis);
            
        }else{
            
            gameController->getUserInputData(character, U4DEngine::macKeyPressed);
            
        }
        
    }
    
}

- (void)keyUp:(NSEvent *)theEvent
{
 
    unichar character = [[theEvent characters] characterAtIndex:0];
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
        
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
            
            gameController->getUserInputData(U4DEngine::macArrowKey, U4DEngine::macArrowKeyReleased, padAxis);
            
        }else{
            
            gameController->getUserInputData(character, U4DEngine::macKeyReleased);
            
        }
        
    }
    
}

- (void)mouseEntered:(NSEvent *)theEvent {
    
}

- (void)mouseMoved:(NSEvent *)theEvent {
    
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();

    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    //get mouse location
    NSPoint mouseMovePos = [theEvent locationInWindow];
    
    int xDelta;
    int yDelta;

    //get the mouse delta movement
    CGGetLastMouseDelta(&xDelta, &yDelta);
    
    U4DEngine::U4DVector2n mouseLocation(mouseMovePos.x,mouseMovePos.y);
    
    U4DEngine::U4DVector2n mouseDeltaLocation(xDelta,yDelta);

    if(gameController!=nullptr){
        
        //if game current scene mouse not anchored
        if(!currentScene->getAnchorMouse()){
            
            gameController->getUserInputData(U4DEngine::mouse, U4DEngine::mouseActive, mouseLocation);
            
        }else{
            
            //else if current scene mouse locked
            
            //The following snippets are required to anchor the mouse cursor to the center of the screen
            
            //get the center position of the view
            NSPoint d=NSMakePoint(metalView.frame.origin.x+metalView.frame.size.width/2, metalView.frame.origin.y+metalView.frame.size.height/2);

            NSRect sp = [[[NSApplication sharedApplication] mainWindow] convertRectToScreen:NSMakeRect(d.x, d.y, 0.0, 0.0)];

            //move the cursor back to the center
            // CGAssociateMouseAndMouseCursorPosition(false);
            CGWarpMouseCursorPosition(CGPointMake(sp.origin.x, sp.origin.y));
            //CGAssociateMouseAndMouseCursorPosition(true);
            
            gameController->getUserInputData(U4DEngine::mouse, U4DEngine::mouseActiveDelta, mouseDeltaLocation);
            
        }

    }
    
}

- (void)mouseExited:(NSEvent *)theEvent {
    
    
}

- (void)mouseDragged:(NSEvent *)theEvent {
 
    NSPoint mouseDownPos = [theEvent locationInWindow];

    U4DEngine::U4DVector2n mouseLocation(mouseDownPos.x,mouseDownPos.y);
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
        gameController->getUserInputData(U4DEngine::mouseLeftButton, U4DEngine::mouseButtonDragged, mouseLocation);
        
    }
    
}

- (void)mouseDown:(NSEvent *)theEvent {
    
    NSPoint mouseDownPos = [theEvent locationInWindow];

    U4DEngine::U4DVector2n mouseLocation(mouseDownPos.x,mouseDownPos.y);
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
            
        gameController->getUserInputData(U4DEngine::mouseLeftButton, U4DEngine::mouseButtonPressed, mouseLocation);
        
    }
    
    
}

- (void)mouseUp:(NSEvent *)theEvent {
    
    NSPoint mouseUpPos = [theEvent locationInWindow];

    U4DEngine::U4DVector2n mouseLocation(mouseUpPos.x,mouseUpPos.y);
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();
    
    if(gameController!=nullptr){
        
        gameController->getUserInputData(U4DEngine::mouseLeftButton, U4DEngine::mouseButtonReleased, mouseLocation);
        
    }
    

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



