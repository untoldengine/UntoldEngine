//
//  U4DBVHGroundCollision.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DBVHGroundCollision_hpp
#define U4DBVHGroundCollision_hpp

#include <stdio.h>
#include "U4DBVHCollision.h"

namespace U4DEngine {
    class U4DBVHTree;
}

namespace U4DEngine {
    
    class U4DBVHGroundCollision:public U4DBVHCollision{
        
    private:
        
        std::shared_ptr<U4DBVHTree> groundNode;
        
    public:
        
        U4DBVHGroundCollision();
        
        ~U4DBVHGroundCollision();
        
        void startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        void collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        void collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs);
        
        void setGroundNode(std::shared_ptr<U4DBVHTree> uGroundNode);
        
    };
    
}

#endif /* U4DBVHGroundCollision_hpp */
