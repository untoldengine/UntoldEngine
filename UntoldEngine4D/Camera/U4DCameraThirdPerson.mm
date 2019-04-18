//
//  U4DCameraThirdPerson.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DCameraThirdPerson.h"
#include "U4DModel.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DCameraThirdPerson* U4DCameraThirdPerson::instance=0;
    
    U4DCameraThirdPerson::U4DCameraThirdPerson():motionAccumulator(0.0,0.0,0.0){
        
        
    }
    
    U4DCameraThirdPerson::~U4DCameraThirdPerson(){
        
    }
    
    U4DCameraThirdPerson* U4DCameraThirdPerson::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DCameraThirdPerson();
            
        }
        
        return instance;
    }
    
    void U4DCameraThirdPerson::update(double dt){
        
        if (model!=nullptr) {
            
            U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
            
            U4DVector3n modelPosition=model->getAbsolutePosition();
            
            //get model view direction
            U4DVector3n modelViewDirection=model->getViewInDirection();
            
            //translate camera along the direction of the view direction of the model
            U4DVector3n newCameraPosition=modelPosition-modelViewDirection*zOffset;
            
            newCameraPosition.y=yOffset+modelPosition.y;
            
            //smooth out the motion of the camera by using a Recency Weighted Average.
            //The RWA keeps an average of the last few values, with more recent values being more
            //significant. The bias parameter controls how much significance is given to previous values.
            //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
            //A bias of 1 ignores the new value altogether.
            float biasMotionAccumulator=0.85;
            
            motionAccumulator=motionAccumulator*biasMotionAccumulator+newCameraPosition*(1.0-biasMotionAccumulator);
            
            camera->translateTo(motionAccumulator);
            
            camera->viewInDirection(modelPosition);
            
        }
        
    }
    
    void U4DCameraThirdPerson::setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset){
        
        model=uModel;
        xOffset=uXOffset;
        yOffset=uYOffset;
        zOffset=uZOffset; //offset behind model
        
    }
    
}
