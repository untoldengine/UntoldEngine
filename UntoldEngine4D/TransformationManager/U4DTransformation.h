//
//  U4DTransformation.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DTransformation__
#define __UntoldEngine__U4DTransformation__

#include <iostream>
#include "U4DTransformationManagerInterface.h"

namespace U4DEngine {
    
class U4DTransformation:public U4DTransformationManagerInterface{
    
private:
    
    U4DEntity *uEntity;
    
public:
    
    U4DTransformation(U4DEntity *uUObject);
    
    ~U4DTransformation(){};
    
    void updateSpaceMatrixPosition(U4DQuaternion& translation);
    
    void updateSpaceMatrixOrientation(U4DQuaternion& orientation);
    
    void translateTo(U4DVector3n& translation);
    
    void translateTo(float x,float y, float z);
    
    void rotateTo(U4DQuaternion& rotation);
    
    void rotateTo(U4DMatrix3n& uRotationMatrix);
    
    void rotateBy(U4DQuaternion& rotation);
    
    void rotateTo(float angle, U4DVector3n& axis);
    
    void rotateBy(float angle, U4DVector3n& axis);
    
    void rotateTo(float angleX, float angleY, float angleZ);
    
    void rotateBy(float angleX, float angleY, float angleZ);
    
    void translateTo(U4DVector2n &translation);
    
    void translateBy(float x,float y, float z);
    
    void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition);
    
    void rotateAboutAxis(U4DQuaternion& uOrientation, U4DVector3n& axisPosition);
    
    void viewInDirection(U4DVector3n& uDestinationPoint);
    
    
};
}

#endif /* defined(__UntoldEngine__U4DTransformation__) */
