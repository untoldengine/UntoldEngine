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
#include "U4DBoundingAABB.h"

namespace U4DEngine {
    
    U4DCameraBasicFollow* U4DCameraBasicFollow::instance=0;
    
    U4DCameraBasicFollow::U4DCameraBasicFollow():motionAccumulator(0.0,0.0,0.0),trackBox(false),cameraBoundingBox(nullptr){
        
        
        
    }
    
    U4DCameraBasicFollow::~U4DCameraBasicFollow(){
        
        if(cameraBoundingBox!=nullptr){
            scheduler->unScheduleTimer(timer);
            delete scheduler;
            delete timer;
            delete cameraBoundingBox;
        }
    
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
            
            if (trackBox==true) {
                
                //do a linear interpolation to determine the vector to translate the camera. It will move at steps dt
                U4DVector3n translationBoxVector=previousBoundingPosition+(newBoundingPosition-previousBoundingPosition)*dt;

                cameraBoundingBox->translateTo(translationBoxVector);

                previousBoundingPosition=translationBoxVector;
            
                modelPosition=translationBoxVector;
            }
            
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

    void U4DCameraBasicFollow::setParametersWithBoxTracking(U4DModel *uModel, float uXOffset, float uYOffset, float uZOffset,U4DPoint3n uMinPoint, U4DPoint3n uMaxPoint){
        
        if(cameraBoundingBox==nullptr){
            
            setParameters(uModel, uXOffset, uYOffset, uZOffset);
            
            trackBox=true;

            cameraBoundingBox=new U4DBoundingAABB();

            cameraBoundingBox->computeBoundingVolume(uMinPoint, uMaxPoint);
            cameraBoundingBox->setVisibility(true);
            
            //Create the callback. Notice that you need to provide the name of the class
            scheduler=new U4DEngine::U4DCallback<U4DCameraBasicFollow>;
        
            //create the timer
            timer=new U4DEngine::U4DTimer(scheduler);

            //initialize the position of the bounding box
            U4DVector3n modelPos=model->getAbsolutePosition();

            cameraBoundingBox->translateTo(modelPos);
            previousBoundingPosition=modelPos;
            newBoundingPosition=previousBoundingPosition;

            //step 3. set up scheduler
            scheduler->scheduleClassWithMethodAndDelay(this, &U4DCameraBasicFollow::trackBoundingBox, timer,1.0, true);
            
        }
        
    }

    U4DBoundingAABB *U4DCameraBasicFollow::getBoundingBox(){
        return cameraBoundingBox;
    }

    //step 4. create a new method to test collision
    void U4DCameraBasicFollow::trackBoundingBox(){
            
        //set up a ray to get the point at h=1.0
        U4DEngine::U4DPoint3n pos=model->getAbsolutePosition().toPoint();
        U4DEngine::U4DVector3n rayDirection=model->getViewInDirection();
            
        U4DEngine::U4DPoint3n posY=pos+rayDirection.toPoint();
            

        //get the current boundary points of the aabb box
        U4DPoint3n m0=cameraBoundingBox->getMinBoundaryPoint();
        U4DPoint3n m1=cameraBoundingBox->getMaxBoundaryPoint();

        U4DEngine::U4DAABB aabbBox(m0,m1);
                
        //test if point is within the box
        if (!aabbBox.isPointInsideAABB(posY)) {
            
            //set the new position of the bounding box to the position of the model we are tracking
            newBoundingPosition=posY.toVector();
            
        }

    }

    void U4DCameraBasicFollow::pauseBoxTracking(){
        
        if (cameraBoundingBox!=nullptr) {
            trackBox=false;
            timer->setPause(true);
        }
        
    }

    void U4DCameraBasicFollow::resumeBoxTracking(){
        
        if (cameraBoundingBox!=nullptr) {
            trackBox=true;
            timer->setPause(false);
        }
        
    }
    
}
