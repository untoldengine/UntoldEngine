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


void MyCharacter::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
     
        walking=new U4DEngine::U4DAnimation(this);
        bow=new U4DEngine::U4DAnimation(this);
        //enableCollisionBehavior();
        //enableKineticsBehavior();
        //translateTo(0.0,3.0,0.0);
        //initCoefficientOfRestitution(0.5);
        if (loadAnimationToModel(bow, "bow", uBlenderFile)) {
            
        }
        
        if (loadAnimationToModel(walking, "walking", uBlenderFile)) {
            
        }
        
        
        
    }
    
    
}

void MyCharacter::update(double dt){
   
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
        case kRotating:
            
            break;
            
        case kWalking:
            
            setAnimation(walking);
            
            break;
            
        case kBow:
            
            setAnimation(bow);
            
            break;
            
        default:
            
            break;
    }
    
    if (getAnimation()!=NULL) {
        
        playAnimation();
        
    }
    
}



