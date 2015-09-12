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

        U4DPoint3n a(0,0,0);
        U4DPoint3n b(1,1,0);
        U4DPoint3n c(2,0,0);
        U4DPoint3n d(3,1,0);
        U4DPoint3n e(4,0,0);
        U4DPoint3n f(5,1,0);
        
        U4DTriangle acb(a,c,b);
        U4DTriangle cdb(c,d,b);
        U4DTriangle ced(c,e,d);
        U4DTriangle edf(e,d,f);
        
        
        faces.push_back(acb);
        faces.push_back(cdb);
        faces.push_back(ced);
        faces.push_back(edf);
        /*
        int m=4;    //set m to initial size of tetrahedron simplex
        
        int n=0;
        
        while (m<=uQ.size()) {
            
            U4DPoint3n a=uQ.at(n).minkowskiPoint;
            U4DPoint3n b=uQ.at(n+1).minkowskiPoint;
            U4DPoint3n c=uQ.at(n+2).minkowskiPoint;
            U4DPoint3n d=uQ.at(n+3).minkowskiPoint;
            
            U4DTriangle abc(a,b,c);
            U4DTriangle abd(a,b,d);
            U4DTriangle acd(a,c,d);
            U4DTriangle bcd(b,c,d);
            
            faces.push_back(abc);
            faces.push_back(abd);
            faces.push_back(acd);
            faces.push_back(bcd);
            
            m=m+1;
            n=n+1;
            
        }
        */
        
    }
    
    U4DPolytope::~U4DPolytope(){
        
    }

    U4DTriangle U4DPolytope::closestFaceOnPolytopeToPoint(U4DPoint3n& uPoint){
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<faces.size(); i++) {
            
            float triangleDistanceToOrigin=faces.at(i).squareDistanceOfClosestPointOnTriangleToPoint(uPoint);
            
            if (triangleDistanceToOrigin<=distance) {
                
                distance=triangleDistanceToOrigin;
                
                index=i;
            }
        }
        
        return faces.at(index);
        
    }
    
    
}