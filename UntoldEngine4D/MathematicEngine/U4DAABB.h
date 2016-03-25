//
//  U4DAABB.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 2/28/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DAABB_hpp
#define U4DAABB_hpp

#include <stdio.h>
#include "U4DPoint3n.h"
#include "U4DVector3n.h"

namespace U4DEngine {
    
    class U4DAABB {
        
    private:
        
        U4DPoint3n minPoint;
        
        U4DPoint3n maxPoint;
        
        //longest volume dimension
        U4DVector3n longestAABBDimensionVector;
        
    public:
        
        U4DAABB();
        
        U4DAABB(U4DPoint3n &uMinPoint, U4DPoint3n &uMaxPoint);
        
        ~U4DAABB();
        
        void setMinPoint(U4DPoint3n& uMinPoint);
        
        void setMaxPoint(U4DPoint3n& uMaxPoint);
        
        U4DPoint3n getMinPoint();
        
        U4DPoint3n getMaxPoint();
        
        bool intersectionWithVolume(U4DAABB *uAABB);
        
        void setLongestAABBDimensionVector(U4DVector3n& uLongestAABBDimensionVector);
        
        U4DVector3n getLongestAABBDimensionVector();

        
    };
    
}

#endif /* U4DAABB_hpp */
