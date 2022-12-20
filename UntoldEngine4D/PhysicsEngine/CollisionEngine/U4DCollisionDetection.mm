//
//  U4DCollisionDetection.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#include "U4DCollisionDetection.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "U4DTetrahedron.h"
#include "U4DMesh.h"

namespace U4DEngine {
    
    U4DCollisionDetection::U4DCollisionDetection(){
        
    }
    
    SIMPLEXDATA U4DCollisionDetection::calculateSupportPointInDirection(U4DMesh *uBoundingVolume1, U4DMesh* uBoundingVolume2, U4DVector3n& uDirection){
        
        //Calculate the supporting point Sa-b(v)=sa(v)-sb(-v)
        
        U4DPoint3n sa=uBoundingVolume1->getSupportPointInDirection(uDirection);
        
        uDirection.negate();
        
        U4DPoint3n sb=uBoundingVolume2->getSupportPointInDirection(uDirection);
        
        //Sa-b(v)=sa(v)-sb(-v)
        U4DPoint3n sab=(sb-sa).toPoint();
        
        SIMPLEXDATA supportPoint;
        
        supportPoint.sa=sa;
        supportPoint.sb=sb;
        supportPoint.minkowskiPoint=sab;
        
        //set direction back to normal
        uDirection.negate();
        
        return supportPoint;
        
    }
    
    std::vector<float> U4DCollisionDetection::determineBarycentricCoordinatesInSimplex(U4DPoint3n& uClosestPointToOrigin,std::vector<SIMPLEXDATA> uQ){
        
        std::vector<float> barycentricCoordinates;
        
        int uNumberOfSimplexInContainer=(int)uQ.size();
        
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
    
    U4DPoint3n U4DCollisionDetection::determineClosestPointOnSimplexToPoint(U4DPoint3n& uPoint,std::vector<SIMPLEXDATA> uQ){
        
        U4DPoint3n closestPoint;
        
        int uNumberOfSimplexInContainer=(int)uQ.size();
        
        if (uNumberOfSimplexInContainer==2) {
            //do line
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            
            U4DSegment segment(a,b);
            
            closestPoint=segment.closestPointOnSegmentToPoint(uPoint);
            
        }else if(uNumberOfSimplexInContainer==3){
            //do triangle
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            U4DPoint3n c=uQ.at(2).minkowskiPoint;
            
            U4DTriangle triangle(a,b,c);
            
            closestPoint=triangle.closestPointOnTriangleToPoint(uPoint);
            
         
        }else if(uNumberOfSimplexInContainer==4){
            //do tetrahedron
            U4DPoint3n a=uQ.at(0).minkowskiPoint;
            U4DPoint3n b=uQ.at(1).minkowskiPoint;
            U4DPoint3n c=uQ.at(2).minkowskiPoint;
            U4DPoint3n d=uQ.at(3).minkowskiPoint;
            
            U4DTetrahedron tetrahedron(a,b,c,d);
            
            closestPoint=tetrahedron.closestPointOnTetrahedronToPoint(uPoint);
            
        }
        
        return closestPoint;
    }
    
}
