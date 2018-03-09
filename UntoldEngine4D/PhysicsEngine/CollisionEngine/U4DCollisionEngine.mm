//
//  U4DCollisionEngine.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DCollisionEngine.h"
#include "Constants.h"
#include "CommonProtocols.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DGJKAlgorithm.h"
#include "U4DCollisionResponse.h"
#include "U4DSHAlgorithm.h"
#include "U4DDynamicModel.h"
#include "U4DBVHManager.h"
#include "U4DLogger.h"

namespace U4DEngine {
    
    U4DCollisionEngine::U4DCollisionEngine(){};

    U4DCollisionEngine::~U4DCollisionEngine(){};
    
    void U4DCollisionEngine::update(float dt){
        
    }

    void U4DCollisionEngine::setCollisionAlgorithm(U4DCollisionAlgorithm* uCollisionAlgorithm){
        
        collisionAlgorithm=uCollisionAlgorithm;
        
    }
    
    void U4DCollisionEngine::setManifoldGenerationAlgorithm(U4DManifoldGeneration* uManifoldGenerationAlgorithm){
        
        manifoldGenerationAlgorithm=uManifoldGenerationAlgorithm;
        
    }
    
    void U4DCollisionEngine::setCollisionResponse(U4DCollisionResponse* uCollisionResponse){
        
        collisionResponse=uCollisionResponse;
        
    }
    
    void U4DCollisionEngine::setBoundaryVolumeHierarchyManager(U4DBVHManager* uBoundaryVolumeHierarchyManager){
        
        boundaryVolumeHierarchyManager=uBoundaryVolumeHierarchyManager;
        
    }

    void U4DCollisionEngine::addToBroadPhaseCollisionContainer(U4DDynamicModel* uModel){
        
        boundaryVolumeHierarchyManager->addModelToTreeContainer(uModel);
        
    }
    
    void U4DCollisionEngine::detectBroadPhaseCollisions(float dt){
        
        //build bvh tree
        boundaryVolumeHierarchyManager->buildBVH();
        
        //determine collisions
        boundaryVolumeHierarchyManager->startCollision();
        
        //retrieve collision pairs
        collisionPairs=boundaryVolumeHierarchyManager->getBroadPhaseCollisionPairs();
        
    }

    void U4DCollisionEngine::detectNarrowPhaseCollision(float dt){
        
        U4DLogger *logger=U4DLogger::sharedInstance();
        
        for (auto n:collisionPairs) {
            
            U4DDynamicModel *model1=n.model1;
            U4DDynamicModel *model2 =n.model2;
            
            if (model1->getAwake() || model2->getAwake()) {
                
                if (collisionAlgorithm->collision(model1, model2, dt)) {
                    
                    //if collision occurred then
                    model1->setModelHasCollided(true);
                    model2->setModelHasCollided(true);
                    
                    //add to collision list
                    model1->addToCollisionList(model2);
                    model2->addToCollisionList(model1);
                    
                    if (model1->getIsCollisionSensor()||model2->getIsCollisionSensor()) {
                        
                        //reset the time of impact since these models are only collision sensors
                        model1->setTimeOfImpact(1.0);
                        model2->setTimeOfImpact(1.0);
                        
                    }else{
                        
                        //get collision response information
                        
                        //create a collision node to contain all the collision information
                        COLLISIONMANIFOLDONODE collisionNode;
                        
                        collisionNode.collisionClosestPoint=collisionAlgorithm->getClosestCollisionPoint();
                        collisionNode.normalCollisionVector=collisionAlgorithm->getContactCollisionNormal();
                        
                        //Manifold Generation Algorithm
                        //Get the Normal collision plane manifold information
                        manifoldGenerationAlgorithm->determineCollisionManifold(model1, model2, collisionAlgorithm->getCurrentSimpleStruct(), collisionNode);
                        
                        //Get the collision contacts (Manifold) information
                        if(manifoldGenerationAlgorithm->determineContactManifold(model1, model2, collisionAlgorithm->getCurrentSimpleStruct(),collisionNode)){
                            
                            //collision Response
                            collisionResponse->collisionResolution(model1, model2,collisionNode);
                            
                        }else{
                            
                            logger->log("Contact Manifold were not found");
                            
                        }
                        
                    }
                    
                }
                
            }
            
                
        }
       
    }
    
    void U4DCollisionEngine::clearContainers(){
        
        boundaryVolumeHierarchyManager->clearContainers();
        collisionPairs.clear();
        
    }

}
