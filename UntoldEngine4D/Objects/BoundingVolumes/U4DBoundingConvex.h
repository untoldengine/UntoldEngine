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
        
        U4DBoundingConvex(){};
        
        ~U4DBoundingConvex(){};
        
        U4DBoundingConvex(const U4DBoundingConvex& value){};
        
        U4DBoundingConvex& operator=(const U4DBoundingConvex& value){
            return *this;
        };
        
        void computeConvexHullVertices(std::vector<U4DVector3n>& uVertices);
        void initConvexHullRenderingVertices();
        
        std::vector<U4DVector3n> getConvexHullVertices();
    };
    
}

#endif /* U4DBoundingConvex_h */
