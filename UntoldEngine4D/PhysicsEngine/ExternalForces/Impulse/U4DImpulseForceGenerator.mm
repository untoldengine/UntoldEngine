//
//  U4DImpulseForceGenerator.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DImpulseForceGenerator.h"

namespace U4DEngine {
    
U4DImpulseForceGenerator::U4DImpulseForceGenerator(){
    
    
}

U4DImpulseForceGenerator::~U4DImpulseForceGenerator(){
    
    
}

void  U4DImpulseForceGenerator::updateForce(U4DDynamicModel *uModel, float dt){
    
    impulseTime=dt;
    
    U4DVector3n velocityBody;
    U4DVector3n angularVelocityBody;
    
    //Clear all forces
    uModel->clearForce();
    uModel->clearMoment();
    
    //get the contact point and line of action
    
    U4DVector3n contactPoint=uModel->collisionProperties.contactManifoldInformation.contactPoint;
    U4DVector3n lineOfAction=uModel->collisionProperties.contactManifoldInformation.lineOfAction;
    
    //get the velocity model
    /*
     r=contact point
     vp=v+(wxr)
     */
    
    U4DVector3n Vp=uModel->getVelocity()+(uModel->getAngularVelocity().cross(contactPoint));
    
    float inverseMass=1.0/uModel->massProperties.mass;
    
    /*
     
     See page 115 in Physics for game developers
     
     |J|=-(Vr*n)(e+1)/[1/m +n*((rxn)/I)xr]
     
     */
    
    
    float j=-1*(Vp.dot(lineOfAction))*(uModel->coefficientOfRestitution+1)/(inverseMass+lineOfAction.dot(uModel->getInverseMomentOfInertiaTensor()*(contactPoint.cross(lineOfAction)).cross(contactPoint)));
    
    
    
    /*
     
     V1after=V1before+(|J|n)/m
     
     */
    
    velocityBody+=uModel->getVelocity()+(lineOfAction*j)/uModel->massProperties.mass;
    
    
    
    /*
     
     w1after=w1before+(rx|j|n)/I
     */
    
    
    angularVelocityBody+=uModel->getAngularVelocity()+uModel->getInverseMomentOfInertiaTensor()*(contactPoint.cross(lineOfAction*j));
    
    uModel->setVelocity(velocityBody);
    
    uModel->setAngularVelocity(angularVelocityBody);
    
    
    //determine if the motion of the body is too low and set body to sleep
    float currentMotion=velocityBody.magnitudeSquare()+angularVelocityBody.magnitudeSquare();
    
    uModel->setMotion(currentMotion,impulseTime);
    
}

}