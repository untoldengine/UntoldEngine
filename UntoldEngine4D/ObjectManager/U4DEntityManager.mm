//
//  ObjectManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DEntityManager.h"
#include "U4DEntity.h"
#include "U4DGravityForceGenerator.h"
#include "U4DControllerInterface.h"
#include "U4DVisibleEntity.h"
#include "U4DDragForceGenerator.h"
#include "U4DCollisionEngine.h"
#include "U4DPhysicsEngine.h"
#include "U4DEulerMethod.h"
#include "U4DRungaKuttaMethod.h"
#include "U4DWorld.h"
#include "U4DBoundingVolume.h"

namespace U4DEngine {
    
U4DEntityManager::U4DEntityManager(){
    
    //set the collision manager
    collisionEngine=new U4DCollisionEngine();
    
    //set the physics engine
    physicsEngine=new U4DPhysicsEngine();
    
    //set the integrator method
    integratorMethod=new U4DRungaKuttaMethod();
    physicsEngine->setIntegrator(integratorMethod);
    
};

U4DEntityManager::~U4DEntityManager(){

    delete collisionEngine;
    delete physicsEngine;
    delete integratorMethod;

};


void U4DEntityManager::setRootEntity(U4DVisibleEntity* uRootEntity){
    
    rootEntity=uRootEntity;
    
}

void U4DEntityManager::setPhysicsProperties(){
    
    U4DWorld *world=(U4DWorld*)rootEntity;
    
    U4DVector3n gravity=world->getGravity();
    
    physicsEngine->setGravity(gravity);
    
}

#pragma mark-draw
//draw
void U4DEntityManager::draw(){
    
    //Collisions draw
    
    //collisionEngine->draw();
   
    U4DEntity* child=rootEntity;
    
    while (child!=NULL) {
        
        if(child->isRoot()){
            
            child->absoluteSpace=child->localSpace;
    
            child->getShadows();
            
        }else{
            
            child->absoluteSpace=child->localSpace*child->parent->absoluteSpace;
            
        }
 
            child->draw();
        
        
        
        child=child->next;
    }
    
}


#pragma mark-update
//update
void U4DEntityManager::update(float dt){
    
    //update the positions
    U4DEntity* child=rootEntity;
    
    while (child!=NULL) {
        
        child->update(dt);
        
        child=child->next;
    }
   
    //update the collision for each model
    child=rootEntity;
    while (child!=NULL) {
        
        U4DModel *model=(U4DModel*)child;
        
        if (model->getEntityType()==MODEL) {
            
            if(model->isCollisionApplied()==true){
                
                U4DMatrix3n modelOrientation=model->getAbsoluteMatrixOrientation();
                U4DVector3n modelPosition=model->getAbsolutePosition();
                
                //provide orientation and position for OBB
                model->narrowPhaseBoundingVolume->center=modelPosition;
                model->narrowPhaseBoundingVolume->orientation=modelOrientation;
                
                //add child to collision tree
                collisionEngine->addToCollisionContainer((U4DDynamicModel*)child);
                
            }
            
        }
        
        child=child->next;
    }
    
    //compute collision detection
    collisionEngine->detectCollisions(dt);
    /*
    
    
    
    //update the physics
    child=rootEntity;
    while (child!=NULL) {
        
        U4DModel *model=(U4DModel*)child;
        
        if (model->isPhysicsApplied()==true) {
            
            physicsEngine->updatePhysicForces((U4DDynamicModel*)child, dt);
            
        }
        
        child=child->next;
    }
    */
    
}

/*
#pragma mark-apply physics to object
//apply physics
void U4DEntityManager::applyPhysicsToObject(U4DDynamicModel* uBody){
    
    //add(uBody); //add physics to object
}

#pragma mark-apply collision
void U4DEntityManager::applyCollision(U4DDynamicModel* uBody){
    
    //send the body to the collision engine so that it produces the geometry
    collisionEngine->applyCollisionDetection(uBody);
}

#pragma mark-apply gravity to object
//apply gravity to object
void U4DEntityManager::applyGravityToObject(U4DDynamicModel* uBody){
    
    physicsEngine->add(uBody, applyGravity);
   
}

#pragma mark-apply damping to object
//apply damping to object
void U4DEntityManager::applyDampingToObject(U4DDynamicModel *uBody){
    
    physicsEngine->add(uBody, applyDrag);
    
}

#pragma mark-apply external force to body

//apply external force on body
void U4DEntityManager::applyExternalForce(U4DCollisionData& uCollisionData){
    

}
*/

}

