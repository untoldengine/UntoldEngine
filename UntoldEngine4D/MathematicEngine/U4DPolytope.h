//
//  U4DPolytope.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DPolytope__
#define __UntoldEngine__U4DPolytope__

#include <stdio.h>
#include <vector>
#include "U4DTriangle.h"  
#include "U4DSegment.h"
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DPolytope{
        
    private:
        
        std::vector<U4DTriangle> faces;
        std::vector<U4DSegment> edgesList;
        
    public:
        U4DPolytope(std::vector<U4DSimplexStruct> uQ);
        
        ~U4DPolytope();
        
        U4DTriangle closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint);
        
        void removeAllFacesSeenByPoint(U4DPoint3n& uPoint);
        
        void createNewFaces();
        
    };
}

#endif /* defined(__UntoldEngine__U4DPolytope__) */
