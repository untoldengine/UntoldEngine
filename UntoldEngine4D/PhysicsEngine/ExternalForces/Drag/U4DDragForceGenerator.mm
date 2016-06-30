//
//  U4DDragForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DDragForceGenerator.h"

namespace U4DEngine {
    
    U4DDragForceGenerator::U4DDragForceGenerator():k1(0.05),k2(0.9){
    
    }
    
    U4DDragForceGenerator::~U4DDragForceGenerator(){
    
    }
    
    void  U4DDragForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){

        U4DVector3n linearDrag;
        float dragCoeff;
        
        linearDrag=uModel->getVelocity();
        dragCoeff=linearDrag.magnitude();
        
        dragCoeff=k1*dragCoeff+k2*dragCoeff*dragCoeff;
        
        //calculate the final force and apply it
        linearDrag.normalize();
        linearDrag*=-dragCoeff;
        
        uModel->addForce(linearDrag);
        
        //moment
        U4DVector3n angularDrag;
        float momentDragCoeff;
        
        angularDrag=uModel->getAngularVelocity();
        momentDragCoeff=angularDrag.magnitude();
          
        if (momentDragCoeff>10000) {
     
            std::cout<<"Moment went insane"<<std::endl;
        
        }
        
        momentDragCoeff=k1*momentDragCoeff+k2*momentDragCoeff*momentDragCoeff;
        
        angularDrag.normalize();
        angularDrag*=-momentDragCoeff;
        uModel->addMoment(angularDrag);
        
    }

}
