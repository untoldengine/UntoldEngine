//
//  Town.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/20/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "Town.h"
#include "CommonProtocols.h"
#include "U4DCamera.h"
#include "U4DDigitalAssetLoader.h"
#include "U4DAnimation.h"


void Town::init(const char* uName,float xPosition,float yPosition, float zPosition){
    
    U4DEngine::U4DDigitalAssetLoader *loader=U4DEngine::U4DDigitalAssetLoader::sharedInstance();
    
    if(loader->loadDigitalAssetFile("blenderscript.u4d")){
        
        loader->loadAssetToMesh(this,uName);
        
    }
   
    translateTo(xPosition,yPosition,zPosition);
    
    //rotateTo(0.0,0.0,40.0);
    
   
}

void Town::update(double dt){
    
}
