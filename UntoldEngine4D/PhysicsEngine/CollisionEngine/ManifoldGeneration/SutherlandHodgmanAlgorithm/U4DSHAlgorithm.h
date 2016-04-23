//
//  U4DSHAlgorithm.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/18/16.
//  Copyright © 2016 Untold Game Studio. All rights reserved.
//

#ifndef U4DSHAlgorithm_hpp
#define U4DSHAlgorithm_hpp

#include <stdio.h>
#include "U4DManifoldGeneration.h"

namespace U4DEngine {
    class U4DSegment;
    class U4DTriangle;
}

namespace U4DEngine {
    
    typedef struct{
        
        U4DTriangle triangle;
        float distance;
        float dotProduct;
        
    }CONTACTFACES;
    
    typedef struct{
        
        U4DSegment segment;
        bool isDuplicate;
        U4DVector3n normal;
        bool isReference;
        
    }CONTACTPOLYGON;
    
    
    
}

namespace U4DEngine {
    
    class U4DSHAlgorithm:public U4DManifoldGeneration{
        
    private:
        
    public:
        
        U4DSHAlgorithm();
        
        ~U4DSHAlgorithm();
        
        void determineContactManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ, U4DPoint3n& uClosestPoint);
        
        void determineCollisionManifold(U4DDynamicModel* uModel1, U4DDynamicModel* uModel2,std::vector<U4DSimplexStruct> uQ, U4DPoint3n& uClosestPointToOrigin){}
        
    
        std::vector<U4DSegment> clipPolygons(std::vector<CONTACTPOLYGON>& uReferencePolygons, std::vector<CONTACTPOLYGON>& uIncidentPolygons);
        
        std::vector<CONTACTFACES> mostParallelFacesToPlane(U4DDynamicModel* uModel, U4DPlane& uPlane);
        
        std::vector<U4DTriangle> projectFacesToPlane(std::vector<CONTACTFACES>& uFaces, U4DPlane& uPlane);
        
        std::vector<CONTACTPOLYGON> getEdgesFromFaces(std::vector<U4DTriangle>& uFaces, U4DPlane& uPlane);
        
    };
    
}


#endif /* U4DSHAlgorithm_hpp */
