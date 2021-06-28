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
#include "U4DProfilerManager.h"
#include "U4DRenderManager.h"
#include "U4DModel.h"

#include "U4DKineticDictionary.h"
#include "U4DVisibilityDictionary.h"
#include "U4DScriptBindModel.h"
#include "U4DScriptInstanceManager.h"

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
    void U4DEntityManager::render(id <MTLCommandBuffer> uCommandBuffer){
    
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
        
        profilerManager->startProfiling("Final Pass Render");
        
        U4DEntity* child=rootEntity;
    
        while (child!=NULL) {
            
            if(child->isRoot()){
                
                child->absoluteSpace=child->localSpace;
        
            }else{
                
                child->absoluteSpace=child->localSpace*child->parent->absoluteSpace;
               
            }
     
            //child->render(uRenderEncoder);
            
            //sort the entities
            //renderManager->sortEntity(child);
            child->updateAllUniforms();
            child=child->next;
        
        }
        
        renderManager->render(uCommandBuffer,rootEntity); 
        
        profilerManager->stopProfiling();
    }
    


    #pragma mark-update
    //update
    void U4DEntityManager::update(float dt){
        
        U4DKineticDictionary *kineticDictionary=U4DKineticDictionary::sharedInstance();
        std::vector<std::string> kineticBehaviorsContainer;
        
        //set the root entity
        U4DEntity* child=rootEntity;
        while (child!=NULL) {

            if (child->getEntityType()==U4DEngine::MODEL) {
                kineticBehaviorsContainer.push_back(child->getName());
            }

            child=child->next;
        }
        
        //BROAD PHASE COLLISION STARTS
        
        U4DProfilerManager *profilerManager=U4DProfilerManager::sharedInstance();
        
        profilerManager->startProfiling("Collision");
        
        for(auto n:kineticBehaviorsContainer){
            
            U4DDynamicAction *kineticBehavior=kineticDictionary->getKineticBehavior(n);
            
            if (kineticBehavior!=nullptr) {
                
                if(kineticBehavior->isCollisionBehaviorEnabled()==true){

                    //add child to collision bhv manager tree
                    loadIntoCollisionEngine(kineticBehavior);

                }
            }
        }
        

        //Only compute collision if there are more than 1 models with collision behaviors
        if (collisionEngine->getNumberOfModelsInContainer()>1) {
            
            //compute the broad phase collision
            collisionEngine->detectBroadPhaseCollisions(dt);
             
             //BROAD PHASE COLLISION STARTS ENDS
             
             //NARROW COLLISION STAGE STARTS
             
             //compute collision detection
             collisionEngine->detectNarrowPhaseCollision(dt);
            
             
             //NARROW COLLISION STAGE ENDS
        }
             
         //clean up all collision containers
         collisionEngine->clearContainers();
            
        
        profilerManager->stopProfiling();
        
        //update the positions
        
        profilerManager->startProfiling("Update");
        
        U4DScriptBindModel *scriptBindModel=U4DScriptBindModel::sharedInstance();
        U4DScriptInstanceManager *scriptInstanceManager=U4DScriptInstanceManager::sharedInstance();
        
        child=rootEntity;
        
        while (child!=NULL) {
            
            child->update(dt);
            //child->updateAllUniforms();
            
            if(scriptInstanceManager->modelScriptInstanceExist(child->getScriptID())){
                scriptBindModel->update(child->getScriptID(), dt);
            }
            
            child=child->next;
        }

        profilerManager->stopProfiling();
        
        //update the physics
        profilerManager->startProfiling("Physics");
        
        for(auto n:kineticBehaviorsContainer){
            
            U4DDynamicAction *kineticBehavior=kineticDictionary->getKineticBehavior(n);
            
            if (kineticBehavior!=nullptr) {
                
                if(kineticBehavior->isKineticsBehaviorEnabled()==true){

                    //add child to collision bhv manager tree
                    loadIntoPhysicsEngine(kineticBehavior, dt);

                }
            }
            
        }
        
        profilerManager->stopProfiling();
        
        //update the camera
        U4DCamera *camera=U4DCamera::sharedInstance();
        camera->update(dt);
        
        //clean everything up
        for(auto n:kineticBehaviorsContainer){
            
            U4DDynamicAction *kineticBehavior=kineticDictionary->getKineticBehavior(n);
            
            if (kineticBehavior!=nullptr) {
                
                kineticBehavior->cleanUp();
            }
            
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
            U4DVisibilityDictionary *visibleDict=U4DVisibilityDictionary::sharedInstance();
            
            //set the root entity
            U4DEntity* child=rootEntity;

            //1. load the models into a bvh tree

            while (child!=NULL) {

                
                U4DModel *model=visibleDict->getVisibleModel(child->getName());
                
                if (model!=nullptr) {
                    
                    loadIntoVisibilityManager(model);
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
    
    void U4DEntityManager::loadIntoCollisionEngine(U4DDynamicAction* uModel){
        
        collisionEngine->addToBroadPhaseCollisionContainer(uModel);
        
    }
    
    void U4DEntityManager::loadIntoPhysicsEngine(U4DDynamicAction* uModel,float dt){
        
        physicsEngine->updatePhysicForces(uModel,dt);
        
    }
    
    void U4DEntityManager::loadIntoVisibilityManager(U4DModel* uModel){
        
        uModel->setModelVisibility(false);
        
        visibilityManager->addModelToTreeContainer(uModel);
        
    }
    
    void U4DEntityManager::changeVisibilityInterval(float uValue){
        
        visibilityManager->changeVisibilityInterval(uValue);
        
    }
    
}

