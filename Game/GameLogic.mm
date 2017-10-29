//
//  GameLogic.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "GameLogic.h"

#include "U4DControllerInterface.h"
#include "GameController.h"
#include "U4DButton.h"
#include "U4DJoyStick.h"
#include "CommonProtocols.h"
#include "U4DCamera.h"



GameLogic::GameLogic(){
    
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    
}

void GameLogic::init(){
    
    
    
}

void GameLogic::setModelAsset(ModelAsset *uModelAsset){
    
    modelAsset0=uModelAsset;
    
}

void GameLogic::receiveTouchUpdate(void *uData){
    
        TouchInputMessage touchInputMessage=*(TouchInputMessage*)uData;
        
        switch (touchInputMessage.touchInputType) {
            case actionButtonA:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
//                    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
//
//                    U4DEngine::U4DVector3n view=camera->getViewInDirection();
//
//                    view*=1.0;
//
//                    camera->translateBy(view);
                    
                    modelAsset0->startParticleSystem();
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
            case actionButtonB:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
//                    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
//
//                    U4DEngine::U4DVector3n view=camera->getViewInDirection();
//
//                    view*=-1.0;
//
//                    camera->translateBy(view);
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
                
            case actionJoystick:
                
            {
                if (touchInputMessage.touchInputData==joystickActive) {
                    
                    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
                    
                    U4DEngine::U4DVector3n view=camera->getViewInDirection();
                    
                    view*=1.0;
                    
                    camera->translateBy(view);
                   
                    
                }else if(touchInputMessage.touchInputData==joystickInactive){
                    
                    
                }
            }
                
                break;
                
            default:
                break;
        }
        
    
    
}


