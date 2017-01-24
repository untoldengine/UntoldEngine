//
//  MyCharacter.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "MyCharacter.h"

#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"
#include "Missile.h"
#include "U4DWorld.h"

MyCharacter::MyCharacter():joyStickData(0.0,0.0,0.0){
    
}

MyCharacter::~MyCharacter(){
    
}

void MyCharacter::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
     
        walking=new U4DEngine::U4DAnimation(this);
        jump=new U4DEngine::U4DAnimation(this);
        
        setState(kNull);
       enableCollisionBehavior();
        //enableKineticsBehavior();
        //initCoefficientOfRestitution(0.0);
        U4DEngine::U4DVector3n viewDirectionVector(0,0,-1);
        setEntityForwardVector(viewDirectionVector);
        //translateTo(0.0, 2.0, 0.0);
        
//        if (loadAnimationToModel(walking, "walking", uBlenderFile)) {
//            
//        }
//        
//        if (loadAnimationToModel(jump, "jump", uBlenderFile)) {
//            
//        }
        
        loadRenderingInformation();
        
    }
    
    
}

void MyCharacter::update(double dt){
   
    if(getState()==kTraveling){
            
            U4DEngine::U4DVector3n view=getViewInDirection()*dt;
            translateBy(view);
    }
    
}

void MyCharacter::setState(GameEntityState uState){
    entityState=uState;
}

GameEntityState MyCharacter::getState(){
    return entityState;
}

void MyCharacter::changeState(GameEntityState uState){
    
    removeAnimation();
    
    setState(uState);
    
    switch (uState) {
            
        case kTraveling:
        
            break;
        
        case kShoot:
            
            //shoot missile
            shoot();
            
            break;
            
        default:
            
            break;
    }
    
    if (getAnimation()!=NULL) {
        
        playAnimation();
        
    }
    
}


void MyCharacter::shoot(){
    
    Missile *missile=new Missile();
    
    missile->init("bullet", "bulletscript.u4d");
    
    U4DEngine::U4DVector3n view=getViewInDirection();
    U4DEngine::U4DVector3n pos=getAbsolutePosition();
    
    missile->translateTo(pos);
    
    missile->setEntityForwardVector(view);
    
    //get the world
    //U4DEngine::U4DWorld *world=dynamic_cast<U4DEngine::U4DWorld*>(getRootParent());
    
    U4DEngine::U4DEntity *world=getRootParent();
    
    world->addChild(missile);
    
    missile->setState(kShoot);
    
}



