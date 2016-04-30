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
        
        //add all the forces for that body
        
        gravityForce.updateForce(uModel, gravity, dt);
        
        
        //dragForce.updateForce(uModel,dt);
        
        //Integrate
        integrate(uModel, dt);
        
        //reset any collision information
        uModel->resetCollisionInformation();
        
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
        
        gravity=uGravity;
        
        
    }

    U4DVector3n U4DPhysicsEngine::getGravity(){
        
        return gravity;
        
    }
    

}
