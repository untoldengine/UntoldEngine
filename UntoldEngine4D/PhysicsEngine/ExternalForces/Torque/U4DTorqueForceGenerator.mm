//
//  U4DTorqueForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/17/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#include "U4DTorqueForceGenerator.h"

namespace U4DEngine {
    
    U4DTorqueForceGenerator::U4DTorqueForceGenerator(){
        
        
    }
    
    U4DTorqueForceGenerator::~U4DTorqueForceGenerator(){
        
    }
    
    void U4DTorqueForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){
        
        uModel->getAbsolutePosition().show();
        
        //get center of mass
        U4DVector3n centerOfMass=uModel->getCenterOfMass();
        centerOfMass.show();
        //get contact point
        U4DVector3n contactPoint=uModel->getCollisionContactPoint();
        
        //get gravity
        U4DVector3n gravity(0,-10,0);
        
        //get mass
        float mass=uModel->getMass();
        
        
        //calculate the torque for each vertex about center of mass
        
        for (auto vertex:uModel->getConvexHullVertices()) {
            
            U4DVector3n radius=centerOfMass-vertex;
            
            //calculate torque
            U4DVector3n torque=(gravity*mass).cross(radius);
       
            std::cout<<"Torque"<<std::endl;
            torque.show();
            
            uModel->addMoment(torque);
        }
        
    }
    
    void U4DTorqueForceGenerator::setTorque(U4DVector3n& uTorque){
        
        torque=uTorque;
        
    }
    
    U4DVector3n U4DTorqueForceGenerator::getTorque(){
        
        return torque;
        
    }
    
}
