//
//  ViewController.m
//  UntoldEngine
//
//  Created by Harold Serrano on 6/1/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#import "ViewController.h"
#include "CommonProtocols.h"
#include "Constants.h"
#include "U4DDirector.h"
#include "U4DCamera.h"
#include "U4DTouches.h"
#include "MainScene.h"


@implementation ViewController

- (void)dealloc
{
    //[self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [_context release];
    
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] autorelease];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    
    view.context = self.context;
    
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
   
    self.preferredFramesPerSecond=60;
    
    [EAGLContext setCurrentContext:self.context];
    
    glEnable(GL_DEPTH_TEST);
    
    glViewport(0, 0, view.frame.size.height, view.frame.size.width);
    
   
    //set the camera
    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
    
    //set perspectiveMatrix
    camera->setCameraProjectionView(49.134f, view.frame.size.height/view.frame.size.width, 1.0f, 100.0f);
 
    
    //set orthographicView
    camera->setCameraOrthographicView(-1.0, 1.0, -1.0, 1.0, -1.0f, 1.0f);
    
    //load all the shaders
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    director->loadShaders();
    
    //record the display height and width
    director->setDisplayWidthHeight(view.frame.size.height, view.frame.size.width);
    
    //attach the game model to the director and initialize
    //gameLogic=new GameLogic();
    //director->setGameModel(gameLogic);
    
    //set the scene
    MainScene *scen1=new MainScene();
    
    //attach view to director
    //director->setUniverse(scen1);
   /*
    //Create the controller
    gameController=new GameController();
    
    U4DWorld &currentView=scen1->getView();

    gameController->setU4DView(&currentView);
    
    scen1->setController(gameController);
    
    //attach the gamemodel to the controller
    gameController->setU4DGameModel(gameLogic);
    
    gameLogic->init();
    gameController->init();
    */
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        //[self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}



#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    
    //call the update
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    director->update(self.timeSinceLastUpdate);
    
    //NSLog(@"Time Since Last Update%f",self.timeSinceLastUpdate);
    //NSLog(@"FPS %ld",(long)self.framesPerSecond);
    
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    director->draw();
   
}



- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
 
    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        //convert the point to openGL
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        U4DEngine::U4DVector2n point=director->pointToOpenGL(touchPosition.x, touchPosition.y);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchBegan(touchPoints);
        
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{

    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        //convert the point to openGL
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        U4DEngine::U4DVector2n point=director->pointToOpenGL(touchPosition.x, touchPosition.y);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchEnded(touchPoints);
        
    }
    
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    
    for (UITouch *myTouch in touches) {
        CGPoint touchPosition = [myTouch locationInView: [myTouch view]];
        
        //convert the point to openGL
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        U4DEngine::U4DVector2n point=director->pointToOpenGL(touchPosition.x, touchPosition.y);
        
        //make the points U4DTouches
        U4DEngine::U4DTouches touchPoints(point.x,point.y);
        
        //send the points to the U4DController
        director->touchMoved(touchPoints);
        
    }
}


@end
