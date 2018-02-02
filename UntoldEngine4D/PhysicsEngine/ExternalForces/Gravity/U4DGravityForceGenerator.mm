//
//  GravityForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DGravityForceGenerator.h"
#include "U4DVector3n.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    U4DGravityForceGenerator::U4DGravityForceGenerator(){
        
        
    }

    U4DGravityForceGenerator::~U4DGravityForceGenerator(){
        
    }

    void U4DGravityForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){
        
        U4DVector3n force=uModel->getGravity()*uModel->getMass();
        
        uModel->addForce(force);
        
        
    }


}
