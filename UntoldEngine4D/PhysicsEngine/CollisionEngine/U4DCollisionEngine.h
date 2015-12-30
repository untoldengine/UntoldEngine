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
#include "U4DEntityManager.h"
#include "U4DCollisionAlgorithm.h"
#include "U4DManifoldGeneration.h"
#include "U4DDynamicModel.h"
#include <vector>

namespace U4DEngine {
    
    class U4DEntityManager;
}

namespace U4DEngine {
    
    class U4DCollisionEngine{
        
    private:
        
        U4DCollisionAlgorithm *collisionAlgorithm;
        U4DManifoldGeneration *manifoldGenerationAlgorithm;
        
        std::vector<U4DDynamicModel*> modelCollection;
        
    public:
        
        U4DCollisionEngine();
        
        ~U4DCollisionEngine();
        
        
        void setCollisionAlgorithm(U4DCollisionAlgorithm* uCollisionAlgorithm);
        
        void setManifoldGenerationAlgorithm(U4DManifoldGeneration* uManifoldGenerationAlgorithm);
        
        void detectCollisions(float dt);
        
        void addToCollisionContainer(U4DDynamicModel* uModel);
        
        void contactResolution(U4DDynamicModel* uModel, float dt);
        
        void update(float dt);
        
        void add(U4DDynamicModel *uModel);
        
        void remove(U4DDynamicModel *uModel);
        
    };

}

#endif /* defined(__UntoldEngine__U4DCollisionEngine__) */
