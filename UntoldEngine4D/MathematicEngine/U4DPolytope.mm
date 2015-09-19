//
//  U4DPolytope.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/7/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DPolytope.h"

namespace U4DEngine {
    
    U4DPolytope::U4DPolytope(std::vector<U4DSimplexStruct> uQ){
        //build polytope from simplex points
        
        faces.clear();

        
        U4DPoint3n a=uQ.at(0).minkowskiPoint;
        U4DPoint3n b=uQ.at(1).minkowskiPoint;
        U4DPoint3n c=uQ.at(2).minkowskiPoint;
        U4DPoint3n d=uQ.at(3).minkowskiPoint;
        
        U4DTriangle abc(a,b,c);
        
        U4DTriangle abd(a,b,d);
        
        U4DTriangle bdc(b,d,c);
        
        U4DTriangle adc(a,d,c);
        
        faces.push_back(abc);
        faces.push_back(abd);
        faces.push_back(bdc);
        faces.push_back(adc);
        
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }

    U4DTriangle U4DPolytope::closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<faces.size(); i++) {
            
            float triangleDistanceToOrigin=faces.at(i).squareDistanceOfClosestPointOnTriangleToPoint(uPoint);
            
            if (triangleDistanceToOrigin<distance) {
                
                distance=triangleDistanceToOrigin;
                
                index=i;
            }
        }
        
        return faces.at(index);
        
    }
    
    
}