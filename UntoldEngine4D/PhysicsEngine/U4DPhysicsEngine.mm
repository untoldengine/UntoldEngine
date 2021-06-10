//
//  BodyForceRegistry.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/23/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DPhysicsEngine.h"
#include "U4DIntegrator.h"
#include "U4DGravityForceGenerator.h"
#include "U4DDynamicAction.h"

namespace U4DEngine {
    
    U4DPhysicsEngine::U4DPhysicsEngine(){

    }

    U4DPhysicsEngine::~U4DPhysicsEngine(){

    }
        
    void U4DPhysicsEngine::update(float dt){
        
    }

    #pragma mark-update All external Forces
    void U4DPhysicsEngine::updatePhysicForces(U4DDynamicAction *uAction,float dt){
        
        
        if (uAction->getAwake()) {
            
            //add all the forces for that body
            gravityForce.updateForce(uAction, dt);
            
            if (uAction->getModelHasCollided()) {
                
                //determine resting forces
                restingForces.updateForce(uAction, dt);
                
            }
            
            dragForce.updateForce(uAction,dt);
            
            //Integrate
            integrate(uAction, dt);
        }
        
        //determine energy condition of the model
        uAction->computeModelKineticEnergy(dt);
        
        //clear all forces and moments
        uAction->clearForce();
        uAction->clearMoment();
        
    }

    #pragma mark-integrate
    void U4DPhysicsEngine::integrate(U4DDynamicAction *uAction,float dt){
        
        integrator->integrate(uAction, dt);
    }

    #pragma mark-set Integrator
    void U4DPhysicsEngine::setIntegrator(U4DIntegrator *uIntegrator){
        
        integrator=uIntegrator;
        
    }    

}
