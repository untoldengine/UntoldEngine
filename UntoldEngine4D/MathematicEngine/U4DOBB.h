//
//  U4DOBB.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/15.
//  Copyright (c) 2015 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DOBB__
#define __UntoldEngine__U4DOBB__

#include <stdio.h>
#include <vector>
#include <string>
#include "U4DVector3n.h"
#include "U4DMatrix3n.h"
#include "U4DPoint3n.h"
#include "U4DPlane.h"


namespace U4DEngine {

/**
 @ingroup mathengine
 @brief The U4DOBB class implements a represenatation of an Oriented-Bounding Box.
 */
class U4DOBB{
    
private:
    
public:
   
    /**
    @brief  Positive halfwidth of the OBB along each axis
     */
    U4DVector3n halfwidth;
    
    /**
    @brief  Matrix containing the local orientation of the OBB
     */
    U4DMatrix3n orientation;
    
    /**
    @brief  3D Vector containing the center point of the OBB
     */
    U4DVector3n center;
    
    /**
     @brief Constructor which creates an OBB with zero halfwidth, center at zero position, with an identity orientation
     */
    U4DOBB();
    
    /**
     @brief Constructor which createas an OBB with the given halfwidth, center at zero position, with an identity orientation
     */
    U4DOBB(U4DVector3n& uHalfWidth);
    
    /**
     @brief Constructor which creates an OBB with the given halfwidth, center position and orientation
     */
    U4DOBB(U4DVector3n& uHalfWidth, U4DVector3n& uCenter, U4DMatrix3n& uOrientation);
    
    /**
     @brief Destructor for the class
     */
    ~U4DOBB();
    
    /**
     @brief Method which testes if the OBB intersects with a 3D plane
     
     @param uPlane 3D plane to test intersection
     
     @return Returns true if OBB intersects with 3D plane
     */
    bool intersectionWithVolume(U4DPlane& uPlane);
    
    /**
     @brief Method which tests if OBB intersects another OBB
     
     @param uOBB OBB to test intersection
     
     @return Returns true if OBB intersects another OBB
     */
    bool intersectionWithVolume(U4DOBB* uOBB);
    
    /**
     @brief Method which computes closest 3D vector to OBB from a given 3D point
     
     @param uPoint 3D point to compute proximity
     
     @return Returns the closest 3D vector to OBB
     */
    U4DVector3n closestPointToOBB(U4DVector3n& uPoint);
    
    /**
     @brief Method which computes the square magnitude between a 3D point and a OBB
     
     @param uPoint 3D point to compute square magnitude
     
     @return Returns square magnitude of 3D point to OBB. That is, it does not compute the square root of the magnitude
     */
    float sqDistPointOBB(U4DVector3n& uPoint);
    
    /**
     @brief Method which computes 3D vector produced by a intersecting plane
     
     @param uPlane 3D plane to compute intersection
     
     @return Returns intersecting vectors produced by the plane intersection
     */
    std::vector<U4DVector3n> computeVertexIntersectingPlane(U4DPlane& uPlane);

    /**
     @brief Method which sets the OBB vector halfwidth
     
     @param uHalfwidth Vector halfwidth for the OBB
     */
    void setHalfwidth(U4DVector3n& uHalfwidth);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOBB__) */
