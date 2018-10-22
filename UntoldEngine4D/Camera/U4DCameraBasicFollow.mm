//
//  U4DCameraBasicFollow.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DCameraBasicFollow.h"

#include "U4DModel.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DCameraBasicFollow* U4DCameraBasicFollow::instance=0;
    
    U4DCameraBasicFollow::U4DCameraBasicFollow(){
        
        
    }
    
    U4DCameraBasicFollow::~U4DCameraBasicFollow(){
        
    }
    
    U4DCameraBasicFollow* U4DCameraBasicFollow::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DCameraBasicFollow();
            
        }
        
        return instance;
    }
    
    void U4DCameraBasicFollow::update(double dt){
        
        if (model!=nullptr) {
            
            U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
            
            U4DVector3n modelPosition=model->getAbsolutePosition();
            
            //rotate to the model location
            camera->viewInDirection(modelPosition);
            
            //translate the camera to the offset
            U4DVector3n offsetPosition(xOffset, yOffset, zOffset);
            
            U4DVector3n cameraPosition=modelPosition+offsetPosition;
            
            camera->translateTo(cameraPosition);
            
        }
        
    }
    
    void U4DCameraBasicFollow::setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset){
        
        model=uModel;
        xOffset=uXOffset;
        yOffset=uYOffset;
        zOffset=uZOffset; //offset behind model
        
    }
    
}
