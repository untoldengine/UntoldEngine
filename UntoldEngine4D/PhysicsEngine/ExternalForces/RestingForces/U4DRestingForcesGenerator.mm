//
//  U4DRestingForces.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#include "U4DRestingForcesGenerator.h"
#include <vector>

namespace U4DEngine {
    
    U4DRestingForcesGenerator::U4DRestingForcesGenerator(){
        
    }
    
    U4DRestingForcesGenerator::~U4DRestingForcesGenerator(){
        
    }
    
    void U4DRestingForcesGenerator::updateForce(U4DDynamicModel *uModel, U4DVector3n& uGravity, float dt){
        
        if (uModel->getEquilibrium()==true) {
            
            generateNormalForce(uModel, uGravity);
            
        }else{
            
            generateNormalForce(uModel, uGravity);
            generateTorqueForce(uModel, uGravity);
            
        }
        
    }
    
    void U4DRestingForcesGenerator::generateNormalForce(U4DDynamicModel *uModel, U4DVector3n& uGravity){
        
        //get normal collision vector
        U4DVector3n contactCollisionNormal=uModel->getCollisionNormalFaceDirection();
        
        //get mass of model
        float mass=uModel->getMass();
        
        //get center of mass
        U4DVector3n centerOfMass=uModel->getCenterOfMass()+uModel->getAbsolutePosition();
        
        //calculate the normal force at each contact point
        U4DVector3n normalForce(0.0,0.0,0.0);
        
        float angle=uGravity.angle(contactCollisionNormal);
        
        normalForce=uGravity*mass*cos(angle)*-1.0;
        
        uModel->addForce(normalForce);
        
    }
    
    void U4DRestingForcesGenerator::generateTorqueForce(U4DDynamicModel *uModel, U4DVector3n& uGravity){
        
        //get center of mass
        U4DVector3n centerOfMass=uModel->getCenterOfMass()+uModel->getAbsolutePosition();

        //get contact points
        std::vector<U4DVector3n> contactManifold=uModel->getCollisionContactPoints();

        //get mass
        float mass=uModel->getMass();
        
        //calculate torque
        U4DVector3n torque(0.0,0.0,0.0);
        
        for(auto n:contactManifold){
            
            //get the radius from the contact manifold to the center of mass
            U4DVector3n radius=centerOfMass-n;
            
            torque+=(radius).cross(uGravity*mass);
        }
        
        //average the torque
        
        if (contactManifold.size()!=0) {
            torque/=contactManifold.size();
        }
        
        uModel->addMoment(torque);
       
    }
    
}