//
//  U4DCameraFirstPerson.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/21/18.
//  Copyright © 2018 Untold Engine Studios. All rights reserved.
//

#include "U4DCameraFirstPerson.h"
#include "U4DModel.h"
#include "U4DCamera.h"

namespace U4DEngine {
    
    U4DCameraFirstPerson* U4DCameraFirstPerson::instance=0;
    
    U4DCameraFirstPerson::U4DCameraFirstPerson():motionAccumulator(0.0,0.0,0.0){
        
    }
    
    U4DCameraFirstPerson::~U4DCameraFirstPerson(){
        
    }
    
    U4DCameraFirstPerson* U4DCameraFirstPerson::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DCameraFirstPerson();
            
        }
        
        return instance;
    }
    
    void U4DCameraFirstPerson::update(double dt){
        
        if (model!=nullptr) {
            
            U4DEngine::U4DCamera *camera=U4DEngine::U4DCamera::sharedInstance();
            
            U4DVector3n modelPosition=model->getAbsolutePosition();
            
            //get model view direction
            U4DVector3n modelViewDirection=model->getViewInDirection();
            
            //smooth out the motion of the camera by using a Recency Weighted Average.
            //The RWA keeps an average of the last few values, with more recent values being more
            //significant. The bias parameter controls how much significance is given to previous values.
            //A bias of zero makes the RWA equal to the new value each time is updated. That is, no average at all.
            //A bias of 1 ignores the new value altogether.
            float biasMotionAccumulator=0.2;
            
            motionAccumulator=motionAccumulator*biasMotionAccumulator+modelViewDirection*(1.0-biasMotionAccumulator);
            
            U4DVector3n newCameraDirection=motionAccumulator;
            
            //multiply the view direction vector by a large value to keep the model looking into the distance
            newCameraDirection*=10000.0;

            camera->viewInDirection(newCameraDirection);

            //translate camera along the direction of the view direction of the model
            U4DVector3n offsetVector(xOffset,yOffset,zOffset);

            U4DMatrix3n m=model->getAbsoluteMatrixOrientation();

            U4DVector3n n=m*offsetVector;

            U4DVector3n newCameraPosition=modelPosition+n;

            camera->translateTo(newCameraPosition);
            
        }
        
    }
    
    void U4DCameraFirstPerson::setParameters(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset){
        
        model=uModel;
        xOffset=uXOffset;
        yOffset=uYOffset;
        zOffset=uZOffset; //offset ahead of model
        
    }
    
}
