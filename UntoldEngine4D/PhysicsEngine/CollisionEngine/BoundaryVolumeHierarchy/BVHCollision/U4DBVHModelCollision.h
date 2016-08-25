//
//  U4DBVHModelCollision.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DBVHModelCollision_hpp
#define U4DBVHModelCollision_hpp

#include <stdio.h>
#include "U4DBVHCollision.h"

namespace U4DEngine {
    class U4DBVHTree;
    class U4DDynamicModel;
    class U4DBoundingVolume;
}

namespace U4DEngine {
    
    typedef struct{
        
        U4DDynamicModel *model;
        U4DBoundingVolume *boundingVolume;
        
    }ModelBoundingVolumePair;
}

namespace U4DEngine {
    
    class U4DBVHModelCollision:public U4DBVHCollision{
        
    private:
        
    public:
        
        U4DBVHModelCollision();
        
        ~U4DBVHModelCollision();
        
        void startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        void collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        void collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
    };
    
}

#endif /* U4DBVHModelCollision_hpp */
