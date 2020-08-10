//
//  ObjectManager.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 6/22/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
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
#include "U4DVisibilityManager.h"
#include "U4DCamera.h"
#include "U4DPlane.h"
#include "U4DDirector.h"

namespace U4DEngine {
    
    U4DEntityManager::U4DEntityManager(){
        
        //set the collision manager
        collisionEngine=new U4DCollisionEngine();
        
        //set the physics engine
        physicsEngine=new U4DPhysicsEngine();
        
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
        
        //set the visibility manager
        visibilityManager=new U4DVisibilityManager();
        
    };

    U4DEntityManager::~U4DEntityManager(){

        delete bvhTreeManager;
        delete collisionAlgorithm;
        delete manifoldGenerationAlgorithm;
        delete collisionResponse;
        delete visibilityManager;
        delete collisionEngine;
        delete physicsEngine;
        delete integratorMethod;

    };


    void U4DEntityManager::setRootEntity(U4DVisibleEntity* uRootEntity){
        
        rootEntity=uRootEntity;
        
    }

    #pragma mark-draw
    //draw
    void U4DEntityManager::render(id<MTLRenderCommandEncoder> uRenderEncoder){
    
        U4DEntity* child=rootEntity;
    
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                child->absoluteSpace=child->localSpace;
        
            }else{
                
                child->absoluteSpace=child->localSpace*child->parent->absoluteSpace;
               
            }
     
            child->render(uRenderEncoder);
        
            child=child->next;
        
        }
        
    }
    
    
    void U4DEntityManager::renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){
        
        U4DEntity* child=rootEntity;
        
        
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                child->absoluteSpace=child->localSpace;
                
            }else{
                
                child->absoluteSpace=child->localSpace*child->parent->absoluteSpace;
                
            }
            
            child->renderShadow(uRenderShadowEncoder, uShadowTexture);
            
            child=child->next;
        }

        
    }


    #pragma mark-update
    //update
    void U4DEntityManager::update(float dt){
        
        //update the camera
        U4DCamera *camera=U4DCamera::sharedInstance();
        camera->update(dt);
        
        //set the root entity
        U4DEntity* child=rootEntity;
        
        //BROAD PHASE COLLISION STARTS
        
        while (child!=NULL) {

            if (child->getEntityType()==U4DEngine::MODEL) {
                
                    if(child->isCollisionBehaviorEnabled()==true){

                        //add child to collision bhv manager tree
                        child->loadIntoCollisionEngine(this);

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
        
        //update the positions
        child=rootEntity;
        
        while (child!=NULL) {
            
            child->update(dt);
            
            child=child->next;
        }

        
        //update the physics
        child=rootEntity;
        while (child!=NULL) {
            
            if (child->getEntityType()==U4DEngine::MODEL) {
            
                if (child->isKineticsBehaviorEnabled()==true) {
                    
                    child->loadIntoPhysicsEngine(this, dt);
                    
                }
                
            }
            
            child=child->next;
        }
        
        //clean everything up
        child=rootEntity;
        while (child!=NULL) {
            
            if (child->getEntityType()==U4DEngine::MODEL) {
                
                //clear any collision information
                child->cleanUp();
                
            }
            
            child=child->next;
        }
        
        
    }
    
    void U4DEntityManager::determineVisibility(){
        
        //get the camera frustum planes
        U4DCamera *camera=U4DCamera::sharedInstance();
        std::vector<U4DPlane> frustumPlanes=camera->getFrustumPlanes();
        
        U4DDirector *director=U4DDirector::sharedInstance();
        
        director->setModelsWithinFrustum(false);
        
        if (visibilityManager->getPauseBVHBuild()) {
            
            //4. clear container
            visibilityManager->clearContainers();
            
            //set the root entity
            U4DEntity* child=rootEntity;
            
            //1. load the models into a bvh tree
            
            while (child!=NULL) {
                
                if (child->getEntityType()==U4DEngine::MODEL) {
                    
                        
                    //load the model into a bvh tree container
                    child->loadIntoVisibilityManager(this);
                    
                }
                
                child=child->next;
            }
            
            //2. build the bvh tree
            visibilityManager->buildBVH();
            
            //clear the pause bvh build flag
            visibilityManager->setPauseBVHFBuild(false);
            
            //start timer for next bvh computation
            visibilityManager->startTimerForNextBVHBuild();
            
            //3. determine the frustom culling
            visibilityManager->startFrustumIntersection(frustumPlanes);
        }
        
        
    }
    
    void U4DEntityManager::loadIntoCollisionEngine(U4DDynamicModel* uModel){
        
        collisionEngine->addToBroadPhaseCollisionContainer(uModel);
        
    }
    
    void U4DEntityManager::loadIntoPhysicsEngine(U4DDynamicModel* uModel,float dt){
        
        physicsEngine->updatePhysicForces(uModel,dt);
        
    }
    
    void U4DEntityManager::loadIntoVisibilityManager(U4DDynamicModel* uModel){
        
        uModel->setModelVisibility(false);
        
        visibilityManager->addModelToTreeContainer(uModel);
        
    }
    
    void U4DEntityManager::changeVisibilityInterval(float uValue){
        
        visibilityManager->changeVisibilityInterval(uValue);
        
    }
    
}

