//
//  U4DTransformationManagerInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTransformationManagerInterface__
#define __UntoldEngine__U4DTransformationManagerInterface__

#include <iostream>
#include "U4DVector3n.h"
#include "U4DVector2n.h"
#include "U4DMatrix3n.h"
#include "U4DQuaternion.h"

namespace U4DEngine {
class U4DEntity;
}

namespace U4DEngine {
    
/**
 @ingroup gameobjects
 @brief The U4DTransformation interfaces provides all the methods for the transformation of all entities
 */
class U4DTransformationManagerInterface{
    
private:
    
public:
    
    /**
     @brief interface destructor
     */
    ~U4DTransformationManagerInterface(){};
    
    /**
     @brief Method which translates entity to a new position
     
     @param translation 3D vector translation
     */
    virtual void translateTo(U4DVector3n& translation)=0;
    
    /**
     @brief Method which translates entity to a new position
     
     @param x Translation along x-coordinate
     @param y Translation along y-coordinate
     @param z Tranalation along z-coordinate
     */
    virtual void translateTo(float x,float y, float z)=0;
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param rotation Quaternion representing orientation
     */
    virtual void rotateTo(U4DQuaternion& rotation)=0;
    
    /**
     @brief rotates to a new orientation
     
     @param uRotationMatrix matrix representing the orientation
     */
    virtual void rotateTo(U4DMatrix3n& uRotationMatrix)=0;
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param rotation Quaternion representing orientation
     */
    virtual void rotateBy(U4DQuaternion& rotation)=0;
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param angle Angle of rotation
     @param axis  Asis of rotation
     */
    virtual void rotateTo(float angle, U4DVector3n& axis)=0;
    
    /**
     @brief Method which rotates entity by certain amount
     
     @param angle Angle of rotation
     @param axis  Axis of rotation
     */
    virtual void rotateBy(float angle, U4DVector3n& axis)=0;
    
    /**
     @brief Method which translates entity to a new position
     
     @param translation 2D vector translation
     */
    virtual void translateTo(U4DVector2n &translation)=0;
    
    /**
     @brief Method which translates entity by certain amount
     
     @param x Translaiion along x-coordinate
     @param y Translation along y-coordinate
     @param z Translation along z-coordinate
     */
    virtual void translateBy(float x,float y, float z)=0;
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param angleX Angle of rotation along the x-axis
     @param angleY Angle of rotation along the y-axis
     @param angleZ Angle of rotation along the z-axis
     */
    virtual void rotateTo(float angleX, float angleY, float angleZ)=0;
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param angleX Angle of rotation along x-axis
     @param angleY Angle of rotation along y-axis
     @param angleZ Angle of rotation along z-axis
     */
    virtual void rotateBy(float angleX, float angleY, float angleZ)=0;
    
    /**
     @brief Method which rotates entity about an axis
     
     @param angle           Angle representing rotation
     @param axisOrientation Axis of rotation
     @param axisPosition    Position of rotation axis
     */
    virtual void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition)=0;
    
    //virtual void viewInDirection(U4DVector3n& uDestinationPoint)=0;
};
    
}

#endif /* defined(__UntoldEngine__U4DTransformationManagerInterface__) */
