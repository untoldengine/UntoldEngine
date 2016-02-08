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
#include "U4DGJKAlgorithm.h"
#include "U4DEPAAlgorithm.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    U4DEntityManager::U4DEntityManager(){
        
        //set the collision manager
        collisionEngine=new U4DCollisionEngine();
        
        //set the physics engine
        physicsEngine=new U4DPhysicsEngine();
        
        //set the integrator method
        integratorMethod=new U4DRungaKuttaMethod();
        physicsEngine->setIntegrator(integratorMethod);
        
        //set collision detection method
        collisionAlgorithm=new U4DGJKAlgorithm();
        collisionEngine->setCollisionAlgorithm(collisionAlgorithm);
        
        //set contact manifold method
        manifoldGenerationAlgorithm=new U4DEPAAlgorithm();
        collisionEngine->setManifoldGenerationAlgorithm(manifoldGenerationAlgorithm);
        
        
    };

    U4DEntityManager::~U4DEntityManager(){

        delete collisionEngine;
        delete physicsEngine;
        delete integratorMethod;

    };


    void U4DEntityManager::setRootEntity(U4DVisibleEntity* uRootEntity){
        
        rootEntity=uRootEntity;
        
    }

    void U4DEntityManager::setGravity(U4DVector3n& uGravity){
        
        physicsEngine->setGravity(uGravity);
        
    }

    #pragma mark-draw
    //draw
    void U4DEntityManager::draw(){
        
        U4DEntity* child=rootEntity;
        
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                child->absoluteSpace=child->localSpace;
        
                child->getShadows();
                
            }else{
                
                child->absoluteSpace=child->localSpace*child->parent->absoluteSpace;
                
            }
     
                child->draw();
            
            
            //    ONLY FOR DEBUGGING PURPOSES
                U4DStaticModel *model=dynamic_cast<U4DStaticModel*>(child);
            
                if (model) {
                
                    if (model->getBroadPhaseBoundingVolumeVisibility()==true) {
                        
                        model->getBroadPhaseBoundingVolume()->draw();
                        
                    }
                }
            
            //END ONLY FOR DEBUGGING PURPOSES
            
            
            child=child->next;
        }
        
    }


    #pragma mark-update
    //update
    void U4DEntityManager::update(float dt){
        

        //update the positions
        U4DEntity* child=rootEntity;
        
        //update the collision for each model
        child=rootEntity;
        
        
        while (child!=NULL) {
            
            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);
            
            if (model) {
                
                    if(model->isCollisionEnabled()==true){
                        
                        //add child to collision tree
                        collisionEngine->addToCollisionContainer(model);
                        
                    }
            }
            
            child=child->next;
        }
        
        //compute collision detection
        collisionEngine->detectCollisions(dt);
       
        //update the physics
        child=rootEntity;
        while (child!=NULL) {
            
            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);
            
            if (model) {
            
                if (model->isPhysicsApplied()==true) {
                    
                    physicsEngine->updatePhysicForces(model, dt);
                    
                }
                
            }
            
            child=child->next;
        }
       
    
        //update the positions
        child=rootEntity;
        
        while (child!=NULL) {
            
            child->update(dt);
            
            child=child->next;
        }
        
    }
    
    
}

