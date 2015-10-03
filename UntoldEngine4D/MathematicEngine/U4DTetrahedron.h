//
//  U4DTetrahedron.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DTetrahedron__
#define __UntoldEngine__U4DTetrahedron__

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"
#include "U4DTriangle.h"

namespace U4DEngine {
    
class U4DTetrahedron{
    
private:
    
    U4DPoint3n pointA;
    U4DPoint3n pointB;
    U4DPoint3n pointC;
    U4DPoint3n pointD;
    
    U4DTriangle triangleABC;
    U4DTriangle triangleACD;
    U4DTriangle triangleADB;
    U4DTriangle triangleBDC;
    
public:
    
    
    U4DTetrahedron(U4DPoint3n& uPointA, U4DPoint3n& uPointB, U4DPoint3n& uPointC, U4DPoint3n& uPointD);
    
    ~U4DTetrahedron();
    
    U4DTetrahedron(const U4DTetrahedron& a):pointA(a.pointA),pointB(a.pointB),pointC(a.pointC),pointD(a.pointD),triangleABC(a.triangleABC),triangleACD(a.triangleACD),triangleADB(a.triangleADB),triangleBDC(a.triangleBDC){};
    
    
    inline U4DTetrahedron& operator=(const U4DTetrahedron& a){
        
        pointA=a.pointA;
        pointB=a.pointB;
        pointC=a.pointC;
        pointD=a.pointD;
        
        triangleABC=a.triangleABC;
        triangleACD=a.triangleACD;
        triangleADB=a.triangleADB;
        triangleBDC=a.triangleBDC;
        
        return *this;
    }
    
    //Test if point p lies outside plane through abc
    bool pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c);
    
    //Test if point p and d lie on opposite sides of plane through abc
    bool pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c, U4DPoint3n& d);
    
    U4DPoint3n closestPointOnTetrahedronToPoint(U4DPoint3n& uPoint);
    
    U4DTriangle closestTriangleOnTetrahedronToPoint(U4DPoint3n& uPoint);
    
    bool isPointInTetrahedron(U4DPoint3n& uPoint);
    
    void getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV, float& baryCoordinateW, float& baryCoordinateX);
    
    std::vector<U4DTriangle> getTriangles();
    /**
     *  Debug-show the vector on the output log
     */
    void show();
    
    bool isValid();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DTetrahedron__) */
