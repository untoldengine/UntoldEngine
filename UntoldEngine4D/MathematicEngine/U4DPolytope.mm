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
    
    void U4DPolytope::removeAllFacesSeenByPoint(U4DPoint3n& uPoint){
        
        //what faces are seen by point
        std::vector<U4DTriangle> facesNotSeenByPoint;
        
        for (int i=0; i<faces.size(); i++) {
            
            if (faces.at(i).directionOfTriangleNormalToPoint(uPoint)<0) { //if dot<0, then face not seen by point, so save these faces and delete the others
                
                facesNotSeenByPoint.push_back(faces.at(i));
            }else{
                
                //save the edges of the triangles which will be removed
                U4DSegment ab(faces.at(i).pointA,faces.at(i).pointB);
                U4DSegment ac(faces.at(i).pointA,faces.at(i).pointC);
                U4DSegment bc(faces.at(i).pointB,faces.at(i).pointC);
                
                /*
                 In the event that an edge is added that already exists with the same points in the opposite order the old edge is removed and the new edge is not added.
                 */
                
                
                
                
            }
        }
        
        //clear faces
        faces.clear();
        
        //copy faces with faces not seen by point
        faces=facesNotSeenByPoint;
        
        
    }
    
    void U4DPolytope::createNewFaces(){
        
    }

    
}