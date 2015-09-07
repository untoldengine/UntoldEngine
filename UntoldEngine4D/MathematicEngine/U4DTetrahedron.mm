//
//  U4DTetrahedron.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DTetrahedron.h"
#include <cmath>
#include <vector>
#include "U4DVector3n.h"
#include "U4DMatrix4n.h"
#include "U4DTriangle.h"


namespace U4DEngine {
    
    U4DTetrahedron::U4DTetrahedron(U4DPoint3n& uPointA, U4DPoint3n& uPointB, U4DPoint3n& uPointC, U4DPoint3n& uPointD){
        
        pointA=uPointA;
        pointB=uPointB;
        pointC=uPointC;
        pointD=uPointD;
        
    }

    U4DTetrahedron::~U4DTetrahedron(){
        
    }

    bool U4DTetrahedron::pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c){
        
        return (a-p).dot((a-b).cross(a-c))>=0.0f; //[AP AB AC]>=0
    }


    bool U4DTetrahedron::pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c, U4DPoint3n& d){
        
        float signp=(a-p).dot((a-b).cross(a-c)); //[AP AB AC]
        float signd=(a-d).dot((a-b).cross(a-c)); //[AD AB AC]
        
        //points on opposite sides if expression signs are opposite
        
        return signp*signd<0.0f;
        
    }
        
        
    U4DPoint3n U4DTetrahedron::closestPointOnTetrahedronToPoint(U4DPoint3n& uPoint){
       
        //start out assuming point inside all halfspaces, so closest to itself
        
        U4DPoint3n closestPt=uPoint;
        
        float bestSqDist=FLT_MAX;
        
        //if point outside face abc then compute closest point on abc
        if (pointOutsideOfPlane(uPoint,pointA,pointB,pointC,pointD)) {
            
            U4DPoint3n q;
            U4DTriangle triangle(pointA, pointB, pointC);
            
            q=triangle.closestPointOnTriangleToPoint(uPoint);
            
            float sqDist=(q-uPoint).dot(q-uPoint);
            
            //update best closest point if (squared) distance is less than current best
            
            if (sqDist<bestSqDist){
                
                bestSqDist=sqDist;
                closestPt=q;
                
            }
            
        }
        
        //repeat test for face acd
        
        if (pointOutsideOfPlane(uPoint,pointA,pointC,pointD,pointB)) {
            
            U4DPoint3n q;
            U4DTriangle triangle(pointA, pointC, pointD);
            
            q=triangle.closestPointOnTriangleToPoint(uPoint);
            
            float sqDist=(q-uPoint).dot(q-uPoint);
            
            if (sqDist<bestSqDist) {
                bestSqDist=sqDist;
                closestPt=q;
                
            }
        }
        
        
        //repeat test for face adb
        if (pointOutsideOfPlane(uPoint,pointA,pointD,pointB,pointC)) {
            
            U4DPoint3n q;
            U4DTriangle triangle(pointA, pointD, pointB);
            
            q=triangle.closestPointOnTriangleToPoint(uPoint);
            
            float sqDist=(q-uPoint).dot(q-uPoint);
            
            if (sqDist<bestSqDist) {
                bestSqDist=sqDist;
                closestPt=q;
            }
        }
        
        //repeat test for face bdc
        if (pointOutsideOfPlane(uPoint,pointB,pointD,pointC,pointA)) {
            
            U4DPoint3n q;
            U4DTriangle triangle(pointB, pointD, pointC);
            
            q=triangle.closestPointOnTriangleToPoint(uPoint);
            
            float sqDist=(q-uPoint).dot(q-uPoint);
            
            if (sqDist<bestSqDist) {
                bestSqDist=sqDist;
                closestPt=q;
            }
        }

        return closestPt;
    }

    U4DTriangle U4DTetrahedron::closestTriangleOnTetrahedronToPoint(U4DPoint3n& uPoint){
        
        U4DTriangle abc(pointA,pointB,pointC);
        U4DTriangle abd(pointA,pointB,pointD);
        U4DTriangle bcd(pointB,pointC,pointD);
        U4DTriangle acd(pointA,pointC,pointD);
        
        std::vector<U4DTriangle> triangles{abc,abd,bcd,acd};
        
        float distance=FLT_MAX;
        int index=0;
        
        for (int i=0; i<triangles.size(); i++) {
            
            float triangleDistanceToOrigin=triangles.at(i).squareDistanceOfClosestPointOnTriangleToPoint(uPoint);
            
            if (triangleDistanceToOrigin<=distance) {
                
                distance=triangleDistanceToOrigin;
                
                index=i;
            }
        }
        
        return triangles.at(index);
        
    }

    bool U4DTetrahedron::isPointInTetrahedron(U4DPoint3n& uPoint){
        
        return !(pointOutsideOfPlane(uPoint, pointA, pointB, pointC)&&pointOutsideOfPlane(uPoint, pointA, pointC, pointD)&&pointOutsideOfPlane(uPoint, pointA, pointD, pointB)&&pointOutsideOfPlane(uPoint, pointB,pointC,pointD));
        
    }
    
    void U4DTetrahedron::getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV, float& baryCoordinateW, float& baryCoordinateX){
        
        //see page 48 in Real-time collision detection for explanation on how to
        //calculate the barycentric coordinates in a tetrahedron
        
        float dPBCD;
        float dAPCD;
        float dABPD;
        float dABCP;
        float dABCD;
        
        U4DPoint3n p=uPoint;
        U4DPoint3n a=pointA;
        U4DPoint3n b=pointB;
        U4DPoint3n c=pointC;
        U4DPoint3n d=pointD;
        
        U4DMatrix4n pbcd(p.x,b.x,c.x,d.x,
                         p.y,b.y,c.y,d.y,
                         p.z,b.z,c.z,d.z,
                         1.0,1.0,1.0,1.0);
        
        U4DMatrix4n apcd(a.x,p.x,c.x,d.x,
                         a.y,p.y,c.y,d.y,
                         a.z,p.z,c.z,d.z,
                         1.0,1.0,1.0,1.0);
        
        U4DMatrix4n abpd(a.x,b.x,p.x,d.x,
                         a.y,b.y,p.y,d.y,
                         a.z,b.z,p.z,d.z,
                         1.0,1.0,1.0,1.0);
        
        U4DMatrix4n abcp(a.x,b.x,c.x,p.x,
                         a.y,b.y,c.y,p.y,
                         a.z,b.z,c.z,p.z,
                         1.0,1.0,1.0,1.0);
        
        U4DMatrix4n abcd(a.x,b.x,c.x,d.x,
                         a.y,b.y,c.y,d.y,
                         a.z,b.z,c.z,d.z,
                         1.0,1.0,1.0,1.0);
        
        dPBCD=pbcd.getDeterminant();
        dAPCD=apcd.getDeterminant();
        dABPD=abpd.getDeterminant();
        dABCP=abcp.getDeterminant();
        dABCD=abcd.getDeterminant();
        
        baryCoordinateU=dPBCD/dABCD;
        baryCoordinateV=dAPCD/dABCD;
        baryCoordinateW=dABPD/dABCD;
        baryCoordinateX=1-baryCoordinateU-baryCoordinateV-baryCoordinateW;
        
    }

}