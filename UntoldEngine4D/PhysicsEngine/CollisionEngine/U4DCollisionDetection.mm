//
//  U4DCollisionDetection.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DCollisionDetection.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "U4DTetrahedron.h"
#include "U4DConvexPolygon.h"

namespace U4DEngine {
    
    U4DSimplexStruct U4DCollisionDetection::calculateSupportPointInDirection(U4DConvexPolygon *uBoundingVolume1, U4DConvexPolygon* uBoundingVolume2, U4DVector3n& uDirection){
        
        //V=Sb(-p)-sa(p)
        
        U4DPoint3n sa=uBoundingVolume1->getSupportPointInDirection(uDirection);
        
        uDirection.negate();
        
        U4DPoint3n sb=uBoundingVolume2->getSupportPointInDirection(uDirection);
        
        //sb - sa
        U4DPoint3n sab=(sa-sb).toPoint();
        
        U4DSimplexStruct supportPoint;
        
        supportPoint.sa=sa;
        supportPoint.sb=sb;
        supportPoint.minkowskiPoint=sab;
        
        return supportPoint;
        
    }
    
    std::vector<float> U4DCollisionDetection::determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin,std::vector<U4DSimplexStruct> uQ){
        
        std::vector<float> barycentricCoordinates;
        int uNumberOfSimplexInContainer=uQ.size();
        
        if (uNumberOfSimplexInContainer==2) {
            
            //do line
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            
            U4DSegment segment(a,b);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            
            segment.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            
            
            
        }else if(uNumberOfSimplexInContainer==3){
            
            //do triangle
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            U4DPoint3n c=uQ.at(2).minkowskiPoint;
            
            U4DTriangle triangle(a,b,c);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            float uBarycentricW=0.0;
            
            triangle.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV, uBarycentricW);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            barycentricCoordinates.push_back(uBarycentricW);
            
            
            
        }else if(uNumberOfSimplexInContainer==4){
            
            //do tetrahedron
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            U4DPoint3n c=uQ.at(2).minkowskiPoint;
            U4DPoint3n d=uQ.at(3).minkowskiPoint;
            
            U4DTetrahedron tetrahedron(a,b,c,d);
            
            float uBarycentricU=0.0;
            float uBarycentricV=0.0;
            float uBarycentricW=0.0;
            float uBarycentricX=0.0;
            
            tetrahedron.getBarycentricCoordinatesOfPoint(uClosestPointToOrigin, uBarycentricU, uBarycentricV, uBarycentricW, uBarycentricX);
            
            barycentricCoordinates.push_back(uBarycentricU);
            barycentricCoordinates.push_back(uBarycentricV);
            barycentricCoordinates.push_back(uBarycentricW);
            barycentricCoordinates.push_back(uBarycentricX);
            
        }
        
        return barycentricCoordinates;
        
    }
}