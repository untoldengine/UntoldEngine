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
        
        generateNormalForce(uModel, uGravity);
        
    }
    
    void U4DRestingForcesGenerator::generateNormalForce(U4DDynamicModel *uModel, U4DVector3n& uGravity){
        
        //get contact points
        std::vector<U4DVector3n> contactManifold=uModel->getCollisionContactPoints();
        
        //get normal collision vector
        U4DVector3n contactCollisionNormal=uModel->getCollisionNormalFaceDirection();
        
        float mass=uModel->getMass();

        //calculate the normal force at each contact point
        
        
        
//        float angle=gravity.angle(normalFaceDirection);
//
//        U4DVector3n normalForce=gravity*mass*cos(angle)*-1.0;
//
//        uModel->addForce(normalForce);
//        
    }
    
}