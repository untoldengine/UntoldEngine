//
//  U4DNormalForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/13/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#include "U4DNormalForceGenerator.h"

namespace U4DEngine {
    
    U4DNormalForceGenerator::U4DNormalForceGenerator(){
        
        
    }
    
    U4DNormalForceGenerator::~U4DNormalForceGenerator(){
        
    }
    
    void U4DNormalForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){
        
        
        U4DVector3n gravity(0,-10,0);
        U4DVector3n normalDirection=uModel->getCollisionNormalDirection();
        
        normalForce=normalDirection*(normalDirection.dot(gravity*uModel->getMass()*-1.0));
        
        
        uModel->addForce(normalForce);
        
    }
    
    void U4DNormalForceGenerator::setNormalForce(U4DVector3n& uNormalForce){
        
        normalForce=uNormalForce;
        
    }
    
    U4DVector3n U4DNormalForceGenerator::getNormalForce(){
        
        return normalForce;
        
    }
    
}