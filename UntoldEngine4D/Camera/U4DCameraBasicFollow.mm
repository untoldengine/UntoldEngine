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
    
    U4DCameraBasicFollow::U4DCameraBasicFollow():motionAccumulator(0.0,0.0,0.0){
        
        
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
            
            //translate the camera to the offset
            U4DVector3n offsetPosition(xOffset, yOffset, zOffset);
            
            U4DVector3n cameraPosition=modelPosition+offsetPosition;
            
            //smooth out the motion of the camera by using a Recency Weighted Average.
            //The RWA keeps an average of the last few values, with more recent values being more
            //significant. The bias parameter controls how much significance is given to previous values.
            //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
            //A bias of 1 ignores the new value altogether.
            float biasMotionAccumulator=0.2;
            
            motionAccumulator=motionAccumulator*biasMotionAccumulator+cameraPosition*(1.0-biasMotionAccumulator);
            
            camera->translateTo(motionAccumulator);
            
            //rotate to the model location
            camera->viewInDirection(modelPosition);
            
        }
        
    }
    
    void U4DCameraBasicFollow::setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset){
        
        model=uModel;
        xOffset=uXOffset;
        yOffset=uYOffset;
        zOffset=uZOffset; //offset behind model
        
    }
    
}
