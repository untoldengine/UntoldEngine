//
//  U4DLight.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/10/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DLights.h"
#include "CommonProtocols.h"
#include "Constants.h"

namespace U4DEngine {
    
    U4DLights* U4DLights::instance=0;
    
    U4DLights::U4DLights(){
        
        setEntityType(LIGHT);
      
        //set default position
        translateTo(5.0,5.0,5.0);
        
        //view in direction of
        U4DVector3n origin(0,0,0);
        viewInDirection(origin);
        
    };
    
    U4DLights::~U4DLights(){
        
    };
    
    U4DLights* U4DLights::sharedInstance(){
        
        if (instance==0) {
            instance=new U4DLights();
        }
        
        return instance;
    }
    
    void U4DLights::viewInDirection(U4DVector3n& uDestinationPoint){
        
        
        U4DVector3n upVector(0,1,0);
        float oneEightyAngle=180.0;
        U4DVector3n entityPosition;
        
        entityPosition=getAbsolutePosition();
        
        
        //calculate the forward vector
        U4DVector3n forwardVector=uDestinationPoint-entityPosition;
        
        //calculate the angle
        float angle=getEntityForwardVector().angle(forwardVector);
        
        //calculate the rotation axis
        U4DVector3n rotationAxis=forwardVector.cross(getEntityForwardVector());
        
        //if angle is 180 it means that both vectors are pointing opposite to each other.
        //this means that there is no rotation axis. so set the Up Vector as the rotation axis
        
        if ((fabs(angle - oneEightyAngle) <= U4DEngine::zeroEpsilon * std::max(1.0f, std::max(angle, zeroEpsilon)))) {
            
            rotationAxis=upVector;
            angle=180.0;
            
        }
        
        rotationAxis.normalize();
        
        U4DQuaternion rotationQuaternion(angle,rotationAxis);
        
        rotateTo(rotationQuaternion);
        
        
    }

}
