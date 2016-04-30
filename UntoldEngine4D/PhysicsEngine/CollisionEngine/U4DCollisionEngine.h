//
//  U4DCollisionEngine.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/14/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
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
    
    class U4DCollisionEngine{
        
    private:
        
        U4DCollisionAlgorithm *collisionAlgorithm;
        U4DManifoldGeneration *manifoldGenerationAlgorithm;
        U4DBVHManager *boundaryVolumeHierarchyManager;
        U4DCollisionResponse *collisionResponse;
        std::vector<U4DBroadPhaseCollisionModelPair> collisionPairs;
        
    public:
        
        U4DCollisionEngine();
        
        ~U4DCollisionEngine();
        
        
        void setCollisionAlgorithm(U4DCollisionAlgorithm* uCollisionAlgorithm);
        
        void setManifoldGenerationAlgorithm(U4DManifoldGeneration* uManifoldGenerationAlgorithm);
        
        void setCollisionResponse(U4DCollisionResponse* uCollisionResponse);
        
        void setBoundaryVolumeHierarchyManager(U4DBVHManager* uBoundaryVolumeHierarchyManager);
        
        void detectBroadPhaseCollisions(float dt);
        
        void detectNarrowPhaseCollision(float dt);
        
        void addToBroadPhaseCollisionContainer(U4DDynamicModel* uModel);
        
        void update(float dt);
        
        void add(U4DDynamicModel *uModel);
        
        void remove(U4DDynamicModel *uModel);
        
        void clearContainers();
        
    };

}

#endif /* defined(__UntoldEngine__U4DCollisionEngine__) */
