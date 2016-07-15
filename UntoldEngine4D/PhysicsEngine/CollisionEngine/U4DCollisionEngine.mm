//
//  U4DCollisionEngine.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DCollisionEngine.h"
#include "Constants.h"
#include "CommonProtocols.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DGJKAlgorithm.h"
#include "U4DEPAAlgorithm.h"
#include "U4DCollisionResponse.h"
#include "U4DDynamicModel.h"
#include "U4DBVHManager.h"

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
        
        for (auto n:collisionPairs) {
            
            U4DDynamicModel *model1=n.model1;
            U4DDynamicModel *model2 =n.model2;
            
            if (collisionAlgorithm->collision(model1, model2, dt)) {
                
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

                    //if collision occurred then
                    model1->setModelHasCollided(true);
                    model2->setModelHasCollided(true);
                    
                    
                }else{
                    std::cout<<"Contact Manifold were not found"<<std::endl;
                
                }
                
            }
                
        }
       
    }
    
    void U4DCollisionEngine::clearContainers(){
        
        boundaryVolumeHierarchyManager->clearContainers();
        collisionPairs.clear();
        
    }

}
