//
//  GameViewController.m
//  Untold4D macOS
//
//  Created by Harold Serrano on 2/6/18.
//  Copyright © 2018 Untold Game Studio. All rights reserved.
//

#import "GameViewController.h"
#import "U4DRenderer.h"
#import "U4DDirector.h"
#import "U4DLights.h"
#import "U4DCamera.h"
#include "U4DTouches.h"
#include "MainScene.h"
#include "CommonProtocols.h"

@implementation GameViewController
{
    MTKView *metalView;
    
    U4DRenderer *renderer;
    
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
    if (controller.extendedGamepad!=nil) {
        NSLog(@"Controller extended gamepad");
    }else if (controller.gamepad!=nil){
        NSLog(@"Controller is standard");
    }
    
    NSLog(@"Controller is connected");
    
    [self reactToInput];
    
}

- (void)controllerWasDisconnected:(NSNotification *)notification {
    
    // a controller was disconnected
    GCController *controller = (GCController *)notification.object;
    NSLog(@"Controller is disconnected");
    
}

- (void)reactToInput {
    // register block for input change detection
    
    GCController *controller=[GCController controllers][0];
    
    GCExtendedGamepad *profile=controller.extendedGamepad;
    
    if (profile!=nil) {
        
        profile.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element)
        {
            // left trigger
            if (gamepad.leftTrigger == element && gamepad.leftTrigger.isPressed) {
                NSLog(@"Left Trigger");
            }
            
            // right trigger
            if (gamepad.rightTrigger == element && gamepad.rightTrigger.isPressed) {
                NSLog(@"Right Trigger");
            }
            
            // left shoulder button
            if (gamepad.leftShoulder == element && gamepad.leftShoulder.isPressed) {
                NSLog(@"Left Shoulder Button");
            }
            
            // right shoulder button
            if (gamepad.rightShoulder == element && gamepad.rightShoulder.isPressed) {
                NSLog(@"Right Shoulder Button");
            }
            
            // A button
            if (gamepad.buttonA == element && gamepad.buttonA.isPressed) {
                
                U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
                
                U4DEngine::GAMEPADELEMENT padElement=U4DEngine::padButtonA;
                U4DEngine::GAMEPADACTION padAction=U4DEngine::padButtonPressed;
                
                director->padPressBegan(padElement,padAction);
                
            }else if(gamepad.buttonA == element && !gamepad.buttonA.isPressed){
                
                U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
                
                U4DEngine::GAMEPADELEMENT padElement=U4DEngine::padButtonA;
                U4DEngine::GAMEPADACTION padAction=U4DEngine::padButtonReleased;
                
                director->padPressEnded(padElement,padAction);
                
            }
            
            // B button
            if (gamepad.buttonB == element && gamepad.buttonB.isPressed) {
                NSLog(@"B Button");
            }
            
            // X button
            if (gamepad.buttonX == element && gamepad.buttonX.isPressed) {
                NSLog(@"X Button");
            }
            
            // Y button
            if (gamepad.buttonY == element && gamepad.buttonY.isPressed) {
                NSLog(@"Y Button");
            }
            
            // d-pad
            if (gamepad.dpad == element) {
                if (gamepad.dpad.up.isPressed) {
                    NSLog(@"D-Pad Up");
                }
                if (gamepad.dpad.down.isPressed) {
                    NSLog(@"D-Pad Down");
                }
                if (gamepad.dpad.left.isPressed) {
                    NSLog(@"D-Pad Left");
                }
                if (gamepad.dpad.right.isPressed) {
                    NSLog(@"D-Pad Right");
                }
            }
            
            // left stick
            if (gamepad.leftThumbstick == element) {
                
                if (gamepad.leftThumbstick.up.isPressed || gamepad.leftThumbstick.down.isPressed || gamepad.leftThumbstick.left.isPressed || gamepad.leftThumbstick.right.isPressed) {
                    
                    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
                    
                    U4DEngine::GAMEPADELEMENT padElement=U4DEngine::padLeftThumbstick;
                    U4DEngine::GAMEPADACTION padAction=U4DEngine::padThumbstickMoved;
                    U4DEngine::U4DPadAxis padAxis(gamepad.leftThumbstick.xAxis.value,gamepad.leftThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padElement, padAction, padAxis);
                    
                }else if(!gamepad.leftThumbstick.up.isPressed && !gamepad.leftThumbstick.down.isPressed && !gamepad.leftThumbstick.left.isPressed && !gamepad.leftThumbstick.right.isPressed){
                    
                    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
                    
                    U4DEngine::GAMEPADELEMENT padElement=U4DEngine::padLeftThumbstick;
                    U4DEngine::GAMEPADACTION padAction=U4DEngine::padThumbstickReleased;
                    U4DEngine::U4DPadAxis padAxis(gamepad.leftThumbstick.xAxis.value,gamepad.leftThumbstick.yAxis.value);
                    
                    director->padThumbStickMoved(padElement, padAction, padAxis);
                    
                }
                
//                if (gamepad.leftThumbstick.up.isPressed) {
//                    NSLog(@"Left Stick %f", gamepad.leftThumbstick.yAxis.value);
//                }
//                if (gamepad.leftThumbstick.down.isPressed) {
//                    NSLog(@"Left Stick %f", gamepad.leftThumbstick.yAxis.value);
//                }
//                if (gamepad.leftThumbstick.left.isPressed) {
//                    NSLog(@"Left Stick %f", gamepad.leftThumbstick.xAxis.value);
//                }
//                if (gamepad.leftThumbstick.right.isPressed) {
//                    NSLog(@"Left Stick %f", gamepad.leftThumbstick.xAxis.value);
//                }
                
            }
            
            // right stick
            if (gamepad.rightThumbstick == element) {
                if (gamepad.rightThumbstick.up.isPressed) {
                    NSLog(@"Right Stick %f", gamepad.rightThumbstick.yAxis.value);
                }
                if (gamepad.rightThumbstick.down.isPressed) {
                    NSLog(@"Right Stick %f", gamepad.rightThumbstick.yAxis.value);
                }
                if (gamepad.rightThumbstick.left.isPressed) {
                    NSLog(@"Right Stick %f", gamepad.rightThumbstick.xAxis.value);
                }
                if (gamepad.rightThumbstick.right.isPressed) {
                    NSLog(@"Right Stick %f", gamepad.rightThumbstick.xAxis.value);
                }
                
            }
            
        };
        
    }else{
        NSLog(@"Game Controller profile is null");
    }
    
}

- (void)didReceiveMemoryWarning
{
    // [super didReceiveMemoryWarning];
    
}

@end



