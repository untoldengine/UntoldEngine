//
//  U4DEulerMethod.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/6/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DEulerMethod.h"
#include "Constants.h"
#include "U4DTransformation.h"

namespace U4DEngine {
    
void U4DEulerMethod::integrate(U4DDynamicModel *uModel, float dt){
    
    //CALCULATE LINEAR POSITION
    
    //calculate the acceleration
    U4DVector3n acceleration=(uModel->getForce())*(1/uModel->getMass());
    
    //calculate the new velocity at time t+dt
    //yn+t=yn+dy/dx*dt
    //vnew=vorig+acceleration*deltaTime
    U4DVector3n vNew=uModel->getVelocity()+acceleration*dt;
    
    //calculate the new displacement at time t+dt
    U4DVector3n sNew=uModel->getLocalPosition() + vNew*dt;
    
    //update old velocity and displacement with the new ones
    
    uModel->translateTo(sNew);
    uModel->setVelocity(vNew);
    
    //CALCULATE ANGULAR POSITION
    
    U4DVector3n moment=uModel->getMoment();
    U4DMatrix3n momentOfInertiaTensor=uModel->getMomentOfInertiaTensor();
    U4DMatrix3n inverseMomentOfInertia=uModel->getInverseMomentOfInertiaTensor();
    
    //get the angular acceleration
    U4DVector3n angularAcceleration=inverseMomentOfInertia*(moment-(uModel->getAngularVelocity().cross(momentOfInertiaTensor*uModel->getAngularVelocity())));
    
    //get the angular velocity
    U4DVector3n angularVelocity=uModel->getAngularVelocity()+angularAcceleration*dt;
    
    //get the original orientation of the body
    U4DQuaternion orientation=uModel->getLocalSpaceOrientation();
    
    //calculate the new orientation
    orientation+=(orientation*angularVelocity)*(dt*0.5);
    
    float norm=orientation.norm();
    
    if (norm!=0) {
        
        orientation.normalize();
    }
    
    
    uModel->transformation->updateSpaceMatrixOrientation(orientation);
    
    /*
    //set the new orientation
    uModel->setLocalSpaceOrientation(orientation);
    //get the current translation
    U4DQuaternion t=uModel->getLocalSpace().getPureQuaternionPart();
    
    //rescale the proper translation (SEE DUAL QUATERNION)
    U4DQuaternion d=(t*uModel->getLocalSpaceOrientation())*0.5;
    
    uModel->setLocalSpacePosition(d);
    */
    
    
    //U4DVector3n v=uModel->getAngularVelocity()-uModel->getAngularVelocity()*0.2;
    U4DVector3n v=angularVelocity-uModel->getAngularVelocity()*0.2;
    uModel->setAngularVelocity(v);
    
    
    //clear all forces and moments
    uModel->clearForce();
    uModel->clearMoment();
    
}

}
