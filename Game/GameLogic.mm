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
    
    earth->removeChild(particleSystem);
    
    delete particleSystem;
    
}

void GameLogic::initModels(){
    
    Earth *earth=dynamic_cast<Earth*>(getGameWorld());
    
    U4DEngine::PARTICLESYSTEMDATA dustParticleData;
    
    dustParticleData.particleStartColor=U4DEngine::U4DVector3n(0.2,0.2,0.2);
    //dustParticleData.particleStartColorVariance=U4DVector3n(0.5,0.5,0.5);
    dustParticleData.particleEndColor=U4DEngine::U4DVector3n(0.9,0.9,0.9);
    
    dustParticleData.particlePositionVariance=U4DEngine::U4DVector3n(0.5,0.5,0.5);
    
    dustParticleData.particleEmitAngle=U4DEngine::U4DVector3n(90.0,0.0,90.0);
    dustParticleData.particleEmitAngleVariance=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    
    dustParticleData.particleSpeed=2.0;
    dustParticleData.particleLife=2.0;
    dustParticleData.texture="particle.png";
    dustParticleData.emitContinuously=true;
    dustParticleData.numberOfParticlesPerEmission=1.0;
    dustParticleData.emissionRate=0.1;
    dustParticleData.maxNumberOfParticles=200;
    dustParticleData.gravity=U4DEngine::U4DVector3n(0.0,0.0,0.0);
    dustParticleData.particleSystemType=U4DEngine::LINEAREMITTER;
    dustParticleData.enableNoise=true;
    dustParticleData.noiseDetail=4.0;
    dustParticleData.enableAdditiveRendering=false;
    dustParticleData.particleSize=1.0;
    
    
    particleSystem=new U4DEngine::U4DParticleSystem();
    particleSystem->init(dustParticleData);
    
    earth->addChild(particleSystem);
    
    particleSystem->play();
    
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


