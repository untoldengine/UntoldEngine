//
//  U4DBVHCollisionInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 5/9/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DBVHCollisionInterface_hpp
#define U4DBVHCollisionInterface_hpp

#include <stdio.h>
#include <vector>

namespace U4DEngine {
    class U4DBVHTree;
    class U4DBroadPhaseCollisionModelPair;
}

namespace U4DEngine {
    
    class U4DBVHCollision{
        
    private:
        
    public:
        
        U4DBVHCollision();
        
        ~U4DBVHCollision();
        
        bool collisionBetweenTreeVolume(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode);
        
        bool descendTreeRule(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode);
        
        virtual void startCollision(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DBroadPhaseCollisionModelPair>& uBroadPhaseCollisionPairs){};
        
        virtual void collision(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){};
        
        virtual void collisionBetweenTreeLeafNodes(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode){};
        
        virtual void setGroundNode(std::shared_ptr<U4DBVHTree> uGroundNode){};
        
    };
}

#endif /* U4DBVHCollisionInterface_hpp */
