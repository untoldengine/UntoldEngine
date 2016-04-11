//
//  U4DBoundingConvex.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#ifndef U4DBoundingConvex_hpp
#define U4DBoundingConvex_hpp

#include <stdio.h>
#include "U4DBoundingVolume.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    class U4DVector3n;
    
}

namespace U4DEngine {
    
    class U4DBoundingConvex:public U4DBoundingVolume{
    private:
        
    public:
        
        U4DBoundingConvex();
        
        ~U4DBoundingConvex();
        
        U4DBoundingConvex(const U4DBoundingConvex& value);
        
        U4DBoundingConvex& operator=(const U4DBoundingConvex& value);
        
        void setConvexHullVertices(std::vector<U4DVector3n>& uVertices);
        
        void computeBoundingVolume();
        
        std::vector<U4DVector3n> getConvexHullVertices();
        
        U4DPoint3n getSupportPointInDirection(U4DVector3n& uDirection);
        
    };
    
}

#endif /* U4DBoundingConvex_h */
