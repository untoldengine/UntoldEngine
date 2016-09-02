//
//  MyCharacter.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/26/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "MyCharacter.h"
#include "CommonProtocols.h"
#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"


void MyCharacter::init(const char* uName, const char* uBlenderFile){
    
    
    if (loadModel(uName, uBlenderFile)) {
     
        anim=new U4DEngine::U4DAnimation(this);
        
        if (loadAnimationToModel(anim, "ArmatureAction", uBlenderFile)) {
            setShader("gouraudShader");
            replay=0;
            translateTo(0.0,4.0,0.0);
        }
        
    }
    
    
}

void MyCharacter::update(double dt){
   
    if (replay==0) {
        anim->start();
        replay=1;
    }
    
    
}



