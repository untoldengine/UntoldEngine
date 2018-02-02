//
//  U4DVisibilityCulling.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/3/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DVisibilityCulling_hpp
#define U4DVisibilityCulling_hpp

#include <stdio.h>
#include <vector>
#include "U4DDynamicModel.h"
#include "U4DVisibilityCulling.h"

namespace U4DEngine {
    
    class U4DAABB;
    class U4DBVHTree;
}

namespace U4DEngine {
    
    class U4DVisibilityCulling {
        
        
    public:
        
        U4DVisibilityCulling();
        
        ~U4DVisibilityCulling();
        
        bool aabbInFrustum(std::vector<U4DPlane> &uPlanes, U4DAABB *uAABB);
        
        void startFrustumIntersection(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DPlane> &uPlanes);
        
        void testFrustumIntersection(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DPlane> &uPlanes);
        
    };
    
}

#endif /* U4DVisibilityCulling_hpp */
