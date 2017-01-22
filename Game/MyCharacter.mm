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
        enableKineticsBehavior();
        initCoefficientOfRestitution(0.0);
        U4DEngine::U4DVector3n viewDirectionVector(0,0,1);
        setEntityForwardVector(viewDirectionVector);
        translateTo(0.0, 3.0, 0.0);
        
        if (loadAnimationToModel(walking, "walking", uBlenderFile)) {
            
        }
        
        if (loadAnimationToModel(jump, "jump", uBlenderFile)) {
            
        }
        
        loadRenderingInformation();
        
    }
    
    
}

void MyCharacter::update(double dt){
   
    if (getState()==kRotating) {
        
        
        
        
    }else if(getState()==kWalking){
        
//        U4DEngine::U4DVector3n view=getViewInDirection()*dt;
//        
//        translateBy(view);
        
    }else if (getState()==kJump){
        
        
//        if (getIsAnimationUpdatingKeyframe()) {
//            
//            U4DEngine::U4DVector3n view=getViewInDirection();
//            U4DEngine::U4DVector3n jumpForce(view.x*50.0,100.0,view.z*50.0);
//            
//            applyForce(jumpForce);
//            
//        }
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
        case kRotating:
            
            break;
            
        case kWalking:
            
            //setAnimation(walking);
            
            
            break;
            
        case kJump:
            
            //setAnimation(jump);
            
            break;
            
        default:
            
            break;
    }
    
    if (getAnimation()!=NULL) {
        
        playAnimation();
        
    }
    
}



