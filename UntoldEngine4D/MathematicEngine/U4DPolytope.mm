//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"
#include <algorithm>
#include "U4DTriangle.h"
#include "U4DSegment.h"
#include "U4DPoint3n.h"
#include "U4DVector3n.h"



namespace U4DEngine {
    
    U4DPolytope::U4DPolytope():index(0){
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }
    

    std::vector<POLYTOPEVERTEX> U4DPolytope::getPolytopeVertices(){
     
        return polytopeVertices;
        
    }
    
    
    std::vector<POLYTOPEEDGES> U4DPolytope::getPolytopeSegments(){
        
        return polytopeEdges;
        
    }
    
    
    std::vector<POLYTOPEFACES>& U4DPolytope::getPolytopeFaces(){
            
            return polytopeFaces;
    }
    
    
    void U4DPolytope::show(){
        
        for (auto n:polytopeFaces) {
            n.triangle.show();
        }
        
    }
    
}