//
//  GravityForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DGravityForceGenerator.h"


namespace U4DEngine {
    
    U4DGravityForceGenerator::U4DGravityForceGenerator(){
        
        
    }

    U4DGravityForceGenerator::~U4DGravityForceGenerator(){
        
    }

    void U4DGravityForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){
        
        U4DVector3n force=gravity*uModel->getMass();
        uModel->addForce(force);
        
        
    }

    void U4DGravityForceGenerator::setGravity(U4DVector3n& uGravity){
        
        gravity=uGravity;
        
    }

    U4DVector3n U4DGravityForceGenerator::getGravity(){
        
        return gravity;
        
    }

}
