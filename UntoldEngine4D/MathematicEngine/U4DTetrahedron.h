//
//  U4DTetrahedron.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/2/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTetrahedron__
#define __UntoldEngine__U4DTetrahedron__

#include <stdio.h>
#include <vector>
#include "U4DPoint3n.h"
#include "U4DTriangle.h"


namespace U4DEngine {

/**
 @ingroup mathengine
 @brief The U4DTetrahedron class implements a geometrical representation of a Tetrahedron
 */
class U4DTetrahedron{
    
private:
    
    /**
     @brief 3D vertex point of the tetrahedron
     */
    U4DPoint3n pointA;
    
    /**
     @brief 3D vertex point of the tetrahedron
     */
    U4DPoint3n pointB;
    
    /**
     @brief 3D vertex point of the tetrahedron
     */
    U4DPoint3n pointC;
    
    /**
     @brief 3D vertex point of the tetrahedron
     */
    U4DPoint3n pointD;
    
    /**
     @brief 3D triangle face of the tetrahedron
     */
    U4DTriangle triangleABC;
    
    /**
     @brief 3D triangle face of the tetrahedron
     */
    U4DTriangle triangleACD;
    
    /**
     @brief 3D triangle face of the tetrahedron
     */
    U4DTriangle triangleADB;
    
    /**
     @brief 3D triangle face of the tetrahedron
     */
    U4DTriangle triangleBDC;
    
public:
    
    /**
     @brief Constructor which creates a tetrahedron with all vertices-components set to zero
     */
    U4DTetrahedron();
    
    /**
     @brief Constructor which creates a tetrahedron with the given 3D vertex points
     */
    U4DTetrahedron(U4DPoint3n& uPointA, U4DPoint3n& uPointB, U4DPoint3n& uPointC, U4DPoint3n& uPointD);
    
    /**
     @brief Destructor for the class
     */
    ~U4DTetrahedron();
    
    /**
     @brief Copy constructor for the class
     */
    U4DTetrahedron(const U4DTetrahedron& a);
    
    /**
     @brief Copy constructor for the class
     
     @param a 3D tetrahedron to copy to
     
     @return Returns a copy of the tetrahedron
     */
    U4DTetrahedron& operator=(const U4DTetrahedron& a);
    
    //Test if point p lies outside plane through abc
    
    /**
     @brief Method to test if 3D point p lies outside the plane through abc. This is a private method
     
     @param U4DPoint3n&p 3D point to test
     @param a            3D point composing face
     @param b            3D point composing face
     @param c            3D point composing face
     
     @return Returns true if 3D point lies outside the plane through abc
     */
    bool pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c);
    
    /**
     @brief Method to test if 3D point p and d lies outside the plane through abc. This is a private method
     
     @param U4DPoint3n&p 3D point to test
     @param a            3D point composing face
     @param b            3D point composing face
     @param c            3D point composing face
     @param d            3D point to test
     
     @return Returns true if 3D point p and d lies outside the plane through abc
     */
    bool pointOutsideOfPlane(U4DPoint3n&p, U4DPoint3n& a, U4DPoint3n& b, U4DPoint3n& c, U4DPoint3n& d);
    
    /**
     @brief Method which computes the closest 3D point to the tetrahedron from the given 3D point
     
     @param uPoint 3D point to compute closest 3D point to tetrahedron
     
     @return Returns the closest 3D point to the tetrahedron
     */
    U4DPoint3n closestPointOnTetrahedronToPoint(U4DPoint3n& uPoint);
    
    /**
     @brief Method which computes the closest tetrahedron face to the given 3D point
     
     @param uPoint 3D point to compute closest face to tetrahedron
     
     @return Returns the closest tetrahedron face to the 3D point
     */
    U4DTriangle closestTriangleOnTetrahedronToPoint(U4DPoint3n& uPoint);
    
    /**
     @brief Method which determines if a 3D point lies on the tetrahedron
     
     @param uPoint 3D point to test
     
     @return Returns true if the 3D point lies on or in the tetrahedron
     */
    bool isPointInTetrahedron(U4DPoint3n& uPoint);
    
    /**
     @brief Method which computes the barycentric coordinates of the 3D point in the tetrahedron
     
     @param uPoint          3D point to compute barycentric coordinates from
     @param baryCoordinateU u-component of the barycentric coordinates of the 3D point
     @param baryCoordinateV v-component of the barycentric coordinates of the 3D point
     @param baryCoordinateW w-component of the barycentric coordinates of the 3D point
     @param baryCoordinateX x-component of the barycentric coordinates of the 3D point
     */
    void getBarycentricCoordinatesOfPoint(U4DPoint3n& uPoint, float& baryCoordinateU, float& baryCoordinateV, float& baryCoordinateW, float& baryCoordinateX);
    
    /**
     @brief Method which returns the face triangles composing the tetrahedron
     
     @return Returns the faces of the tetrahedron
     */
    std::vector<U4DTriangle> getTriangles();
    
    /**
     @brief Method which prints the vertices of the tetrahedron to the console log window
     */
    void show();
    
    /**
     @brief Method which determines if the Tetrahedron has a valid construction
     
     @return Returns true if the tetrahedron is valid
     */
    bool isValid();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DTetrahedron__) */
