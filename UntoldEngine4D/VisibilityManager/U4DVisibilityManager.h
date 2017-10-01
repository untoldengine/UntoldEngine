//
//  U4DVisibilityManager.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/30/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DVisibilityManager_hpp
#define U4DVisibilityManager_hpp

#include <stdio.h>
#include <vector>
#include "U4DStaticModel.h"

namespace U4DEngine {
    
    class U4DAABB;
    
}

namespace U4DEngine {
    
    class U4DVisibilityManager {
        
    private:
        
    public:
        
        U4DVisibilityManager();
        
        ~U4DVisibilityManager();
        
        void setModelVisibility(U4DStaticModel* uModel, std::vector<U4DPlane> &uPlanes);
        
        bool modelInFrustum(std::vector<U4DPlane> &uPlanes, U4DBoundingVolume *uAABB);
    };
    
}

#endif /* U4DVisibilityManager_hpp */
