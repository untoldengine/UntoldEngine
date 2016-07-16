//
//  U4DConvexHullGenerator.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/16/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DConvexHullGenerator_hpp
#define U4DConvexHullGenerator_hpp

#include <stdio.h>
#include <vector>
#include "CommonProtocols.h"
#include "U4DTetrahedron.h"

namespace U4DEngine {

    //structure that holds vertices that are valid to build a tetrahedron
    typedef struct{
        
        U4DVector3n vertex;
        bool isValid;
        
    }INITIALHULLVERTEX;
    
    typedef struct{
        
        std::vector<INITIALHULLVERTEX> vertices;
        U4DTetrahedron tetrahedron;
        
    }HULLINITIALDATA;

}

namespace U4DEngine {
    
    class U4DConvexHullGenerator{
        
    private:
        
        
    public:
        
        U4DConvexHullGenerator();
        ~U4DConvexHullGenerator();
        
        CONVEXHULL buildHull(std::vector<U4DVector3n> &uVertices);
        
        HULLINITIALDATA buildTetrahedron(std::vector<U4DVector3n> &uVertices);
        
        
        bool verify();
   
    };

}

#endif /* U4DConvexHullGenerator_hpp */
