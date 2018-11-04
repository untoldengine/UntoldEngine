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
    
    /**
     @ingroup camera
     @brief The U4DVisibilityCulling class tests whether a 3D model is within the frustum
     */
    class U4DVisibilityCulling {
        
    public:
        
        /**
         @brief class constructor
         */
        U4DVisibilityCulling();
        
        /**
         @brief class destructor
         */
        ~U4DVisibilityCulling();
        
        
        /**
         @brief check if all the points of the AABB intersect or are inside the plane

         @param uPlanes camera planes
         @param uAABB AABB box encompassing the 3D models
         @return true if all AABB points are inside the plane
         */
        bool aabbInFrustum(std::vector<U4DPlane> &uPlanes, U4DAABB *uAABB);
        
        
        /**
         @brief starts the frustum intersection

         @param uTreeContainer tree containing the AABB boxes encompassing the 3D models
         @param uPlanes camera planes
         */
        void startFrustumIntersection(std::vector<std::shared_ptr<U4DBVHTree>>& uTreeContainer, std::vector<U4DPlane> &uPlanes);
        
        
        /**
         @brief tests the frustum intersection

         @param uTreeLeftNode left node of tree containing the AABB boxes encompassing the 3D models
         @param uTreeRightNode right node of tree containing the AABB boxes encompassing the 3D models
         @param uPlanes camera planes
         */
        void testFrustumIntersection(U4DBVHTree *uTreeLeftNode, U4DBVHTree *uTreeRightNode, std::vector<U4DPlane> &uPlanes);
        
    };
    
}

#endif /* U4DVisibilityCulling_hpp */
