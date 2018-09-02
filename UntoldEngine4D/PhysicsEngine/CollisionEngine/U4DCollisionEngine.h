//
//  U4DCollisionEngine.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DCollisionEngine__
#define __UntoldEngine__U4DCollisionEngine__

#include <iostream>
#include <vector>
#include "CommonProtocols.h"
#include "U4DBroadPhaseCollisionModelPair.h"

namespace U4DEngine {
    
    class U4DEntityManager;
    class U4DCollisionAlgorithm;
    class U4DManifoldGeneration;
    class U4DCollisionResponse;
    class U4DDynamicModel;
    class U4DBVHManager;
}

namespace U4DEngine {

    /**
     @ingroup physicsengine
     @brief The U4DCollisionEngine class is in charge of implemeting the collision engine operations
     */
    class U4DCollisionEngine{
        
    private:
        
        /**
         @brief Pointer to the collision algorithm
         */
        U4DCollisionAlgorithm *collisionAlgorithm;
        
        /**
         @brief Pointer to the collision manifold algorithm
         */
        U4DManifoldGeneration *manifoldGenerationAlgorithm;
        
        /**
         @brief Pointer to the boundary volume hierarchy manager
         */
        U4DBVHManager *boundaryVolumeHierarchyManager;
        
        /**
         @brief Pointer to the collision response class
         */
        U4DCollisionResponse *collisionResponse;
        
        /**
         @brief Container holding all 3D entities pairs that have collided
         */
        std::vector<U4DBroadPhaseCollisionModelPair> collisionPairs;
        
    public:
        
        /**
         @brief Constructor for the class
         */
        U4DCollisionEngine();
        
        /**
         @brief Destructor for the class
         */
        ~U4DCollisionEngine();
        
        /**
         @brief Method which sets the collision algorithm object to use
         
         @param uCollisionAlgorithm Pointer to the collision algorithm object
         */
        void setCollisionAlgorithm(U4DCollisionAlgorithm* uCollisionAlgorithm);
        
        /**
         @brief Method which set the collision manifold generation object to use
         
         @param uManifoldGenerationAlgorithm Pointer to the manifold generation object
         */
        void setManifoldGenerationAlgorithm(U4DManifoldGeneration* uManifoldGenerationAlgorithm);
        
        /**
         @brief Method which sets the collision response object to use
         
         @param uCollisionResponse Collision response object to use
         */
        void setCollisionResponse(U4DCollisionResponse* uCollisionResponse);
        
        /**
         @brief Method which sets the Boundary Volume Hierarchy manager
         
         @param uBoundaryVolumeHierarchyManager Boundary Volume Hierarchy manager
         */
        void setBoundaryVolumeHierarchyManager(U4DBVHManager* uBoundaryVolumeHierarchyManager);
        
        /**
         @brief Method which detects Broad-Phase collision
         
         @param dt Time-step value
         */
        void detectBroadPhaseCollisions(float dt);
        
        /**
         @brief Method which detects Narrow-Phase collision
         
         @param dt Time-step value
         */
        void detectNarrowPhaseCollision(float dt);
        
        /**
         @brief Method which adds the 3D entity to the BVH(Boundary Volume Hierarchy) scenegraph
         
         @param uModel 3D model entity
         */
        void addToBroadPhaseCollisionContainer(U4DDynamicModel* uModel);
        
        /**
         @brief Method which updates the state of the collision engine
         
         @param dt Time-step value
         */
        void update(float dt);
        
        /**
         @todo check if this is needed
         */
        void add(U4DDynamicModel *uModel);
        
        /**
         @todo check if this is needed
         */
        void remove(U4DDynamicModel *uModel);
        
        /**
         @brief Method which clears all scenegraphs and containers with 3D entities used during collision
         */
        void clearContainers();
        
    };

}

#endif /* defined(__UntoldEngine__U4DCollisionEngine__) */
