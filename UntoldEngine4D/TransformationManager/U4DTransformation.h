//
//  U4DTransformation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#ifndef __UntoldEngine__U4DTransformation__
#define __UntoldEngine__U4DTransformation__

#include <iostream>
#include "U4DTransformationManagerInterface.h"

namespace U4DEngine {

/**
 @ingroup gameobjects
 @brief The U4DTransformation class manages the transformation of all entities
 */
class U4DTransformation:public U4DTransformationManagerInterface{
    
private:
    
    /**
     @brief pointer to the entity
     */
    U4DEntity *uEntity;
    
public:
    
    /**
     @brief class constructor
     @param uUObject pointer to entity
     */
    U4DTransformation(U4DEntity *uUObject);
    
    /**
     @brief class destructor
     */
    ~U4DTransformation(){};
    
    /**
     @brief updates the space matrix (position)

     @param translation position quaternion
     */
    void updateSpaceMatrixPosition(U4DQuaternion& translation);
    
    
    /**
     @brief updates the space matrix (orientation)

     @param orientation orientation quaternion
     */
    void updateSpaceMatrixOrientation(U4DQuaternion& orientation);
    
    /**
     @brief Method which translates entity to a new position
     
     @param translation 3D vector translation
     */
    void translateTo(U4DVector3n& translation);
    
    /**
     @brief Method which translates entity to a new position
     
     @param x Translation along x-coordinate
     @param y Translation along y-coordinate
     @param z Tranalation along z-coordinate
     */
    void translateTo(float x,float y, float z);
    
    /**
     @brief Method which translates entity to a new position
     
     @param translation 2D vector translation
     */
    void translateTo(U4DVector2n &translation);
    
    /**
     @brief Method which translates entity by a certain amount
     
     @param translation 3D vector offset translation
     */
    void translateBy(U4DVector3n& translation);
    
    /**
     @brief Method which translates entity by certain amount
     
     @param x Translaiion along x-coordinate
     @param y Translation along y-coordinate
     @param z Translation along z-coordinate
     */
    void translateBy(float x,float y, float z);
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param rotation Quaternion representing orientation
     */
    void rotateTo(U4DQuaternion& rotation);
    
    
    /**
     @brief rotates to a new orientation

     @param uRotationMatrix matrix representing the orientation
     */
    void rotateTo(U4DMatrix3n& uRotationMatrix);
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param angle Angle of rotation
     @param axis  Asis of rotation
     */
    void rotateTo(float angle, U4DVector3n& axis);
    
    /**
     @brief Method which rotates entity to a new orientation
     
     @param angleX Angle of rotation along the x-axis
     @param angleY Angle of rotation along the y-axis
     @param angleZ Angle of rotation along the z-axis
     */
    void rotateTo(float angleX, float angleY, float angleZ);
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param rotation Quaternion representing orientation
     */
    void rotateBy(U4DQuaternion& rotation);
    
    /**
     @brief Method which rotates entity by certain amount
     
     @param angle Angle of rotation
     @param axis  Axis of rotation
     */
    void rotateBy(float angle, U4DVector3n& axis);
    
    /**
     @brief Method which rotates entity by a certain amount
     
     @param angleX Angle of rotation along x-axis
     @param angleY Angle of rotation along y-axis
     @param angleZ Angle of rotation along z-axis
     */
    void rotateBy(float angleX, float angleY, float angleZ);
    
    /**
     @brief Method which rotates entity about an axis
     
     @param angle           Angle representing rotation
     @param axisOrientation Axis of rotation
     @param axisPosition    Position of rotation axis
     */
    void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition);
    
    /**
     @brief Method which rotates entity about an axis
     
     @param uOrientation Orientation to rotate
     @param axisPosition Position of axis
     */
    void rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition);
    
    //void viewInDirection(U4DVector3n& uDestinationPoint);
    
    
};
}

#endif /* defined(__UntoldEngine__U4DTransformation__) */
