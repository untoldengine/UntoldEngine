//
//  U4DDragForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DDragForceGenerator.h"

namespace U4DEngine {
    
    U4DDragForceGenerator::U4DDragForceGenerator():k1(0.9),k2(0.7){
    
    }
    
    U4DDragForceGenerator::~U4DDragForceGenerator(){
    
    }
    
    void  U4DDragForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){

        U4DVector3n velocity;
        float dragCoeff;
        
        velocity=uModel->getVelocity();
        dragCoeff=velocity.magnitude();
        
        dragCoeff=k1*dragCoeff+k2*dragCoeff*dragCoeff;
        
        //calculate the final force and apply it
        velocity.normalize();
        velocity*=-dragCoeff;
        
        uModel->addForce(velocity);
        
        //moment
        U4DVector3n moment;
        float momentDragCoeff;
        
        moment=uModel->getAngularVelocity();
        momentDragCoeff=moment.magnitude();
        
        momentDragCoeff=k1*momentDragCoeff+k2*momentDragCoeff*momentDragCoeff;
        
        moment.normalize();
        moment*=-momentDragCoeff;
        moment.show("moment due to drag");
        uModel->addMoment(moment);
        
    }

}
