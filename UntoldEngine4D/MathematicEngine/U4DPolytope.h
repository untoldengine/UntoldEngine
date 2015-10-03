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
        
        int n;
    public:
        
        std::vector<POLYTOPEFACES> polytopeFaces;

        
        U4DPolytope();
        
        ~U4DPolytope();
        
        
        U4DPolytope(const U4DPolytope& a):polytopeFaces(a.polytopeFaces){};
        
        
        inline U4DPolytope& operator=(const U4DPolytope& a){
            
            polytopeFaces=a.polytopeFaces;
            
            return *this;
        };

    
        POLYTOPEFACES& closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint);
        
        std::vector<POLYTOPEFACES>& getFacesOfPolytope();
        
        void addFaceToPolytope(U4DTriangle& uTriangle);
        
        void removeAllFaces();
        
        /**
         *  Debug-show the vector on the output log
         */
        void show();
        
    };
}

#endif /* defined(__UntoldEngine__U4DPolytope__) */
