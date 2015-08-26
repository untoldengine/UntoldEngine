//
//  U4DConvexPolygon.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DConvexPolygon__
#define __UntoldEngine__U4DConvexPolygon__

#include <stdio.h>
#include <vector>
#include "U4DVector3n.h"
#include "U4DPoint3n.h"

namespace U4DEngine {
    
    class U4DConvexPolygon{
        
    private:
        
    public:
        
        std::vector<U4DVector3n> polygonVertices;
        
        U4DMatrix3n orientation;
        
        U4DVector3n center;
        
        U4DConvexPolygon();
        
        ~U4DConvexPolygon();
        
        void setVerticesInConvexPolygon(std::vector<U4DVector3n> uPolygonVertices);
        
        std::vector<U4DVector3n> getVerticesInConvexPolygon();
        
        U4DPoint3n getSupportPointInDirection(U4DVector3n& uDirection);
        
    };
}

#endif /* defined(__UntoldEngine__U4DConvexPolygon__) */
