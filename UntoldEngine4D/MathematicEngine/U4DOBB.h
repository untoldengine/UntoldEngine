//
//  U4DOBB.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/8/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
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
    
class U4DOBB{
    
private:
    
public:
    
    U4DOBB();
    
    U4DOBB(U4DVector3n& uHalfWidth);
    
    U4DOBB(U4DVector3n& uHalfWidth, U4DVector3n& uCenter, U4DMatrix3n& uOrientation);
    
    ~U4DOBB(){};
    
    /*!
     *  @brief  Positive halfwidth extents of OBB along each axis
     */
    U4DVector3n halfwidth;
    
    /*!
     *  @brief  Local x,y and z axis
     */
    U4DMatrix3n orientation;
    
    /*!
     *  @brief  OBB Center point
     */
    U4DVector3n center;
    
    /*!
     *  @brief  Test if OBB intersects plane
     *
     *  @param uPlane plane
     *
     *  @return true if intersection exist
     */
    bool intersectionWithVolume(U4DPlane& uPlane);
    
    /*!
     * @brief Test if OBB intersects OBB
     * 
     * @param OBB box
     *
     * @return true if intersection exist;
     */
    
    bool intersectionWithVolume(U4DOBB* uOBB);
    
    /*!
     *  @brief  Given point uPoint, return point on (or in) OBB, closest to uPoint
     *
     *  @param uPoint Point uPoint
     *
     *  @return Closest point on OBB closest to uPoint
     */
    U4DVector3n closestPointToOBB(U4DVector3n& uPoint);
    
    /*!
     *  @brief  Computes the square distance between point uPoint and OBB
     *
     *  @param point value
     *
     *  @return distance of point and OBB
     */
    float sqDistPointOBB(U4DVector3n& uPoint);
    
    
    /*!
     *  @brief  Computes the OBB vertex intersecting the plane
     *
     *  @param uPlane plane
     *
     *  @return average point intersecting plane
     */
    std::vector<U4DVector3n> computeVertexIntersectingPlane(U4DPlane& uPlane);

    void setHalfwidth(U4DVector3n& uHalfwidth);
    
};
    
}

#endif /* defined(__UntoldEngine__U4DOBB__) */
