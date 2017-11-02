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
#include "U4DParticleSystem.h"
#include "Earth.h"

GameLogic::GameLogic(){
    
    
    
}

GameLogic::~GameLogic(){
    
   
}

void GameLogic::update(double dt){
    

}

void GameLogic::init(){
    
    
}

void GameLogic::removeModels(){
    
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    //for(int i=0;i<1;i++){
        
        
        earth->removeChild(modelCube[0]);
        
        delete modelCube[0];
        
        modelCube[0]=nullptr;
        
    //}
    
}

void GameLogic::initModels(){
    
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    //for(int i=0;i<1;i++){
        
        modelCube[0]=new ModelAsset();
        
        modelCube[0]->init("Cube", "blenderscript.u4d");
        
        modelCube[0]->translateTo(0.0, 0.0, 0);
        
        earth->addChild(modelCube[0]);
        
    //}
    
}

void GameLogic::receiveTouchUpdate(void *uData){
    
        TouchInputMessage touchInputMessage=*(TouchInputMessage*)uData;
        
        switch (touchInputMessage.touchInputType) {
            case actionButtonA:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                
                    
                    std::cout<<"pressed"<<std::endl;
                    initModels();
                
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
            case actionButtonB:
                
            {
                if (touchInputMessage.touchInputData==buttonPressed) {
                    
                    removeModels();
                    
                }else if(touchInputMessage.touchInputData==buttonReleased){
                    
                    
                }
            }
                
                break;
                
            case actionJoystick:
                
            {
                if (touchInputMessage.touchInputData==joystickActive) {
                    
                    U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
                    
                    U4DEngine::U4DVector3n view=camera->getViewInDirection();
                    
                    view*=-1.0;
                    
                    camera->translateBy(view);
                   
                    
                }else if(touchInputMessage.touchInputData==joystickInactive){
                    
                    
                }
            }
                
                break;
                
            default:
                break;
        }
        
    
    
}


