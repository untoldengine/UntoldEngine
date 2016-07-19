//
//  U4DTransformationManagerInterface.h
//  UntoldEngine
//
//  Created by Harold Serrano on 6/18/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
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
    
class U4DTransformationManagerInterface{
    
private:
    
public:
    
    ~U4DTransformationManagerInterface(){};
    
    virtual void translateTo(U4DVector3n& translation)=0;
    
    virtual void translateTo(float x,float y, float z)=0;
    
    virtual void rotateTo(U4DQuaternion& rotation)=0;
    
    virtual void rotateTo(U4DMatrix3n& uRotationMatrix)=0;
    
    virtual void rotateBy(U4DQuaternion& rotation)=0;
    
    virtual void rotateTo(float angle, U4DVector3n& axis)=0;
    
    virtual void rotateBy(float angle, U4DVector3n& axis)=0;
    
    virtual void translateTo(U4DVector2n &translation)=0;
    
    virtual void translateBy(float x,float y, float z)=0;
    
    virtual void rotateTo(float angleX, float angleY, float angleZ)=0;
    
    virtual void rotateBy(float angleX, float angleY, float angleZ)=0;
    
    virtual void rotateAboutAxis(float angle, U4DVector3n& axisOrientation, U4DVector3n& axisPosition)=0;
    
    virtual void viewInDirection(U4DVector3n& uDestinationPoint)=0;
};
    
}

#endif /* defined(__UntoldEngine__U4DTransformationManagerInterface__) */
