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


void MyCharacter::init(const char* uName,float xPosition,float yPosition, float zPosition){
    

    U4DEngine::U4DDigitalAssetLoader *loader=U4DEngine::U4DDigitalAssetLoader::sharedInstance();
    
    if(loader->loadDigitalAssetFile("blenderscript.u4d")){
        
        loader->loadAssetToMesh(this,uName);
       
    }
    
    //translateTo(xPosition,yPosition,zPosition);
   
    anim=new U4DEngine::U4DAnimation(this);
    
   loader->loadAnimationToMesh(anim,"ArmatureAction");
    
    replay=0;
    
    
    
}

void MyCharacter::update(double dt){
   
    if (replay==0) {
        anim->start();
        replay=1;
    }
  
    //U4DVector3n axisPosition(3,3,0);
    //U4DVector3n axisOrientation(0,0,1);
    
    //rotateAboutAxis(rotation,axisOrientation,axisPosition);
    //U4DQuaternion q(1,axis);
    
    //rotateTo(0,rotation,0);
    //rotation++;
    
    
}



