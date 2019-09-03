//
//  GameViewController.m
//  Untold4D iOS
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
#include "MainScene.h"

@implementation GameViewController{
    
    MTKView *metalView;
    
    U4DRenderer *renderer;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    metalView=(MTKView *)self.view;
    
    metalView.device=MTLCreateSystemDefaultDevice();
    
    metalView.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
    
    if(!metalView.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
    }
    
    renderer = [[U4DRenderer alloc] initWithMetalKitView:metalView];
    
    if(!renderer)
    {
        NSLog(@"Renderer failed initialization");
        return;
    }
    metalView.multipleTouchEnabled=YES;
    
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
    
    U4DEngine::DEVICEOSTYPE deviceOSType=U4DEngine::deviceOSIOS;
    
    director->setDeviceOSType(deviceOSType);
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    //get screen backing scale
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    float contentScale = metalView.contentScaleFactor;
    director->setScreenScaleFactor(contentScale);
    
    //initialize the scene for your game
    MainScene *mainScene=new MainScene();
    mainScene->init();
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        float xPosition=(touchPosition.x-self.view.bounds.size.width/2)/(self.view.bounds.size.width/2);
        float yPosition=(self.view.bounds.size.height/2-touchPosition.y)/(self.view.bounds.size.height/2);
        
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        U4DEngine::U4DVector2n point(xPosition,yPosition);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchBegan(touchPoints);
        
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    
    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        float xPosition=(touchPosition.x-self.view.bounds.size.width/2)/(self.view.bounds.size.width/2);
        float yPosition=(self.view.bounds.size.height/2-touchPosition.y)/(self.view.bounds.size.height/2);
        
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        U4DEngine::U4DVector2n point(xPosition,yPosition);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchEnded(touchPoints);
        
    }
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    
    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        float xPosition=(touchPosition.x-self.view.bounds.size.width/2)/(self.view.bounds.size.width/2);
        float yPosition=(self.view.bounds.size.height/2-touchPosition.y)/(self.view.bounds.size.height/2);
        
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        U4DEngine::U4DVector2n point(xPosition,yPosition);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchMoved(touchPoints);
        
    }
}


@end

