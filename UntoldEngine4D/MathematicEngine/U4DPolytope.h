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
#include "CommonProtocols.h"

namespace U4DEngine {
    
    class U4DPolytope{
        
    private:
        
        int index;
        
    public:
        
        std::vector<POLYTOPEFACES> polytopeFaces;
        std::vector<POLYTOPEEDGES> polytopeEdges;
        std::vector<POLYTOPEVERTEX> polytopeVertices;
        
        U4DPolytope();
        
        ~U4DPolytope();
        
        
        U4DPolytope(const U4DPolytope& a):polytopeFaces(a.polytopeFaces){};
        
        
        inline U4DPolytope& operator=(const U4DPolytope& a){
            
            polytopeFaces=a.polytopeFaces;
            polytopeEdges=a.polytopeEdges;
            polytopeVertices=a.polytopeVertices;
            
            return *this;
        };

    
        POLYTOPEFACES& closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint);
        
        std::vector<POLYTOPEFACES>& getPolytopeFaces();
                
        std::vector<POLYTOPEEDGES> getPolytopeSegments();
        
        std::vector<POLYTOPEVERTEX> getPolytopeVertices();
        
        void addPolytopeData(U4DTriangle& uTriangle);
        
        void removeAllFaces();
        
        void cleanUp();
        
        /**
         *  Debug-show the vector on the output log
         */
        void show();
        
    };
}

#endif /* defined(__UntoldEngine__U4DPolytope__) */
