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
#include "U4DRungaKuttaMethod.h"
#include "U4DWorld.h"
#include "U4DBoundingVolume.h"
#include "U4DGJKAlgorithm.h"
#include "U4DSHAlgorithm.h"
#include "U4DCollisionResponse.h"
#include "U4DBVHManager.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    U4DEntityManager::U4DEntityManager(){
        
        //set the collision manager
        collisionEngine=new U4DCollisionEngine();
        
        //set the physics engine
        physicsEngine=new U4DPhysicsEngine();
        
        U4DVector3n gravity(0,-10,0);
        physicsEngine->setGravity(gravity);
        
        //set the integrator method
        integratorMethod=new U4DRungaKuttaMethod();
        physicsEngine->setIntegrator(integratorMethod);
        
        
        //set the Broad Phase BVH Tree generation
        bvhTreeManager=new U4DBVHManager();
        collisionEngine->setBoundaryVolumeHierarchyManager(bvhTreeManager);
        
        //set narrow Phase collision detection method
        collisionAlgorithm=new U4DGJKAlgorithm();
        collisionEngine->setCollisionAlgorithm(collisionAlgorithm);
        
        //set contact manifold method
        manifoldGenerationAlgorithm=new U4DSHAlgorithm();
        collisionEngine->setManifoldGenerationAlgorithm(manifoldGenerationAlgorithm);
        
        //set the collision response
        collisionResponse=new U4DCollisionResponse();
        collisionEngine->setCollisionResponse(collisionResponse);
        
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
                    
                    if(model->getNarrowPhaseBoundingVolumeVisibility()==true){
                        model->getNarrowPhaseBoundingVolume()->draw();
                    }
                }
            
            //END ONLY FOR DEBUGGING PURPOSES
            
            
            child=child->next;
        }
        
    }


    #pragma mark-update
    //update
    void U4DEntityManager::update(float dt){
        

        //set the root entity
        U4DEntity* child=rootEntity;
        
        //BROAD PHASE COLLISION STARTS
        
        while (child!=NULL) {

            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);

            if (model) {
                
                    if(model->isCollisionBehaviorEnabled()==true){

                        //add child to collision bhv manager tree
                        collisionEngine->addToBroadPhaseCollisionContainer(model);

                    }
            }

            child=child->next;
        }

        collisionEngine->detectBroadPhaseCollisions(dt);
        
        //BROAD PHASE COLLISION STARTS ENDS
        

        //NARROW COLLISION STAGE STARTS
        
        //compute collision detection
        collisionEngine->detectNarrowPhaseCollision(dt);
       
        
        //NARROW COLLISION STAGE ENDS

        
        //clean up all collision containers
        collisionEngine->clearContainers();
        
        
        //update the physics
        child=rootEntity;
        while (child!=NULL) {
            
            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);
            
            if (model) {
            
                if (model->isKineticsBehaviorEnabled()==true) {
                    
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
        
        //clean everything up
        child=rootEntity;
        while (child!=NULL) {
            
            U4DDynamicModel *model=dynamic_cast<U4DDynamicModel*>(child);
            
            if (model) {
                
                //clear any collision information
                model->clearCollisionInformation();
                
                //reset time of impact
                model->resetTimeOfImpact();
                
                //reset equilibrium
                model->setEquilibrium(false);
                
                //set as non-collided
                model->setModelHasCollided(false);
                
            }
            
            child=child->next;
        }
        
        
    }
    
    
}

