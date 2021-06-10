//
//  U4DRestingForces.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/30/16.
//  Copyright © 2016 Untold Engine Studios. All rights reserved.
//

#include "U4DRestingForcesGenerator.h"
#include "U4DModel.h"
#include <vector>

namespace U4DEngine {
    
    U4DRestingForcesGenerator::U4DRestingForcesGenerator(){
        
    }
    
    U4DRestingForcesGenerator::~U4DRestingForcesGenerator(){
        
    }
    
    void U4DRestingForcesGenerator::updateForce(U4DDynamicAction *uAction, float dt){
        
        generateNormalForce(uAction);
            
    }
    
    void U4DRestingForcesGenerator::generateNormalForce(U4DDynamicAction *uAction){
        
        //get normal collision vector
        U4DVector3n contactCollisionNormal=uAction->getCollisionNormalFaceDirection();
        
        //get mass of model
        float mass=uAction->getMass();
        
        //calculate the normal force at each contact point
        U4DVector3n normalForce(0.0,0.0,0.0);
        
        //normalize plane
        contactCollisionNormal.normalize();
        
        //normalize gravity vector
        U4DVector3n normGravity=uAction->getGravity();
        normGravity.normalize();
        
        //get the dot product
        float normalDotGravity=contactCollisionNormal.dot(normGravity);
        
        normalForce=uAction->getGravity()*mass*normalDotGravity;
        
        if (normalDotGravity>0) {
            normalForce*=-1.0;
        }

        uAction->addForce(normalForce);
        
    }
    
    void U4DRestingForcesGenerator::generateTorqueForce(U4DDynamicAction *uAction){
        
        //get center of mass
        U4DVector3n centerOfMass=uAction->getCenterOfMass()+uAction->model->getAbsolutePosition();

        //get contact points
        std::vector<U4DVector3n> contactManifold=uAction->getCollisionContactPoints();

        //get mass
        float mass=uAction->getMass();
        
        //calculate torque
        U4DVector3n torque(0.0,0.0,0.0);
        
        for(auto n:contactManifold){
            
            //get the radius from the contact manifold to the center of mass
            U4DVector3n radius=centerOfMass-n;
            
            torque+=(radius).cross(uAction->getGravity()*mass);
        }
        
        uAction->addMoment(torque);
       
    }
    
}
