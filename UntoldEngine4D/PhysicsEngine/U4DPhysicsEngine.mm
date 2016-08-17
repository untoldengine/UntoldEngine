//
//  BodyForceRegistry.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DPhysicsEngine.h"
#include "U4DIntegrator.h"
#include "U4DGravityForceGenerator.h"
#include "U4DDynamicModel.h"

namespace U4DEngine {
    
    U4DPhysicsEngine::U4DPhysicsEngine(){

    }

    U4DPhysicsEngine::~U4DPhysicsEngine(){

    }
        
    void U4DPhysicsEngine::update(float dt){
        
    }

    #pragma mark-update All external Forces
    void U4DPhysicsEngine::updatePhysicForces(U4DDynamicModel *uModel,float dt){
        
        
        if (uModel->getAwake()) {
            
            //add all the forces for that body
            gravityForce.updateForce(uModel, dt);
            
            if (uModel->getModelHasCollided()) {
                
                //determine resting forces
                restingForces.updateForce(uModel, dt);
                
            }
            
            dragForce.updateForce(uModel,dt);
            
            if (uModel->getEquilibrium()) {
                
                U4DVector3n zero(0,0,0);
                uModel->setAngularVelocity(zero);
                uModel->clearMoment();
                
            }
            //Integrate
            integrate(uModel, dt);
        }
        
        //determine energy condition of the model
        uModel->computeModelKineticEnergy(dt);
        
        //clear all forces and moments
        uModel->clearForce();
        uModel->clearMoment();
        
    }

    #pragma mark-integrate
    void U4DPhysicsEngine::integrate(U4DDynamicModel *uModel,float dt){
        
        integrator->integrate(uModel, dt);
    }

    #pragma mark-set Integrator
    void U4DPhysicsEngine::setIntegrator(U4DIntegrator *uIntegrator){
        
        integrator=uIntegrator;
        
    }    

}
