//
//  BodyForceRegistry.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DPhysicsEngine.h"
#include "U4DIntegrator.h"
#include "U4DEulerMethod.h"
#include "U4DGravityForceGenerator.h"

namespace U4DEngine {
    
U4DPhysicsEngine::U4DPhysicsEngine(){

}

U4DPhysicsEngine::~U4DPhysicsEngine(){

}

#pragma mark-update All external Forces
void U4DPhysicsEngine::updatePhysicForces(U4DDynamicModel *uModel,float dt){
    
    //add all the forces for that body
    
    gravityForce.updateForce(uModel,dt);
    
    impulseForce.updateForce(uModel,dt);
    
    //DO THE RESOLVE FORCE AND MOMENT Method HERE
    
    //Integrate
    integrate(uModel, dt);
    
    
 
}

#pragma mark-integrate
void U4DPhysicsEngine::integrate(U4DDynamicModel *uModel,float dt){
    
    integrator->integrate(uModel, dt);
}

#pragma mark-set Integrator
void U4DPhysicsEngine::setIntegrator(U4DIntegrator *uIntegrator){
    
    integrator=uIntegrator;
    
}

void U4DPhysicsEngine::setGravity(U4DVector3n& uGravity){
    
    gravityForce.setGravity(uGravity);
}

U4DVector3n U4DPhysicsEngine::getGravity(){
    
    return gravityForce.getGravity();
    
}

/* YOU MAY WANT TO CREATE A FORCE GENERATOR FOR THIS
void U4DPhysicsEngine::resolveForcesAndMoments(U4DDynamicModel *uModel,float dt){
    
    float gravityFactor=8.0;
    
    //if the model has not collided, then calculate the moments about center of mass
    
    if (uModel->collisionProperties.collided==false) {
      
    U4DVector3n gravityForce=getGravity()*uModel->getMass();
        
     //transform the vertices of the model
    U4DMatrix3n orientation=uModel->getAbsoluteMatrixOrientation();
    
    
    for (int i=0; i<uModel->massProperties.vertexDistanceFromCenterOfMass.size(); i++) {
        
        U4DVector3n vertex=uModel->massProperties.vertexDistanceFromCenterOfMass.at(i);
        
        vertex=orientation*(vertex);
        
        U4DVector3n torque=(vertex.cross(gravityForce))/gravityFactor;
        
        uModel->addMoment(torque);
    
    }
    
    //Normal Force calculation
    }else if (uModel->collisionProperties.collided==true) {

        
        U4DVector3n normalForce=getGravity()*uModel->getMass()*-1.0;
        
        if (uModel->getMotion()<motionEpsilon && uModel->getVelocity().magnitude()>velocityEpsilon) {
            
        
        //calculate the resultant moments
        for (int i=0; i<uModel->collisionProperties.contactForcePoints.contactPoints.size(); i++) {
            
            U4DVector3n torque=uModel->collisionProperties.contactForcePoints.contactPoints.at(i).cross(normalForce);
            
            uModel->addMoment(torque);
            
            U4DVector3n velocity=uModel->getVelocity();
            U4DVector3n angularVelocity=uModel->getAngularVelocity();
            
            velocity/=100.0;
            angularVelocity/=100.0;
            
            uModel->setVelocity(velocity);
            uModel->setAngularVelocity(angularVelocity);
            
        }
         
        }
            

        //set the normal force
        uModel->addForce(normalForce);
     
            
    }
    
}
*/

}
