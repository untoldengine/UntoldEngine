//
//  MyCharacter.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "MyCharacter.h"
#include "UserCommonProtocols.h"
#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"


void MyCharacter::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
     
        anim=new U4DEngine::U4DAnimation(this);
        enableCollisionBehavior();
        enableKineticsBehavior();
        translateTo(0.0,3.0,0.0);
        initCoefficientOfRestitution(0.5);
        
        if (loadAnimationToModel(anim, "walking", uBlenderFile)) {
            
            replay=0;
            
        }
        
    }
    
    
}

void MyCharacter::update(double dt){
   
    
    if (replay==0) {
        //anim->start();
        replay=1;
    }
    
   
}

void MyCharacter::changeState(void* uState){
    
    kGameEntityState state=*static_cast<kGameEntityState*>(uState);
    
    switch (state) {
        case kRotating:
            std::cout<<"Rotating"<<std::endl;
            
            break;
            
        case kWalking:
            std::cout<<"Walking"<<std::endl;
            
            break;
            
        case kJumping:
            std::cout<<"Jumping"<<std::endl;
            
            break;
            
        default:
            break;
    }
    
}



