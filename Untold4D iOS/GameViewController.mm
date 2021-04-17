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
#import "U4DCamera.h"
#include "U4DTouches.h"
#include "U4DLogger.h"
#include "U4DVector2n.h"
#include "U4DControllerInterface.h"
#include "U4DSceneManager.h"
#include "SandboxScene.h"
#include "LevelOneScene.h"
#include "CommonProtocols.h"

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
    
    // Indicate that we would like the view to call our -[AAPLRender drawInMTKView:] 60 times per
    //   second.  This rate is not guaranteed: the view will pick a closest framerate that the
    //   display is capable of refreshing (usually 30 or 60 times per second).  Also if our renderer
    //   spends more than 1/60th of a second in -[AAPLRender drawInMTKView:] the view will skip
    //   further calls until the renderer has returned from that long -[AAPLRender drawInMTKView:]
    //   call.  In other words, the view will drop frames.  So we should set this to a frame rate
    //   that we think our renderer can consistently maintain.
    metalView.preferredFramesPerSecond = 60;
    
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
    
    //call the scene manager
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();

    //initialize the scene for your game
    //SandboxScene *sandboxScene=new SandboxScene();
    LevelOneScene *levelOneScene=new LevelOneScene();
    
    sceneManager->changeScene(levelOneScene);
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();

    if(gameController!=nullptr){

        for (UITouch *myTouch in touches) {

            CGPoint touchPosition = [myTouch locationInView: [myTouch view]];

            U4DEngine::U4DVector2n position(touchPosition.x,touchPosition.y);

            gameController->getUserInputData(U4DEngine::ioTouch, U4DEngine::ioTouchesBegan, position);

        }

    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();

    if(gameController!=nullptr){

        for (UITouch *myTouch in touches) {
            CGPoint touchPosition = [myTouch locationInView: [myTouch view]];

            U4DEngine::U4DVector2n position(touchPosition.x,touchPosition.y);

            //send the points to the U4DController
            gameController->getUserInputData(U4DEngine::ioTouch, U4DEngine::ioTouchesEnded, position);

        }

    }

    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    U4DEngine::U4DControllerInterface *gameController=currentScene->getGameController();

    if(gameController!=nullptr){

        for (UITouch *myTouch in touches) {
            CGPoint touchPosition = [myTouch locationInView: [myTouch view]];

            U4DEngine::U4DVector2n position(touchPosition.x,touchPosition.y);


            //send the points to the U4DController
            gameController->getUserInputData(U4DEngine::ioTouch, U4DEngine::ioTouchesMoved, position);

        }

    }

}


@end

