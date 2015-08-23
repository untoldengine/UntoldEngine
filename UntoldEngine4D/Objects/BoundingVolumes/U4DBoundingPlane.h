//
//  U4DBoundingPlane.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingPlane__
#define __UntoldEngine__U4DBoundingPlane__

#include <iostream>
#include "U4DBoundingVolume.h"

class U4DBoundingPlane:public U4DBoundingVolume{
    
private:
    
public:
    
    
    U4DBoundingPlane(){};
                    
    
    ~U4DBoundingPlane(){}
    
    
    U4DBoundingPlane(const U4DBoundingPlane& value){};
    
    
    U4DBoundingPlane& operator=(const U4DBoundingPlane& value){
        return *this;
    };
    
    
    U4DVector3n normal;
    
    
    U4DVector3n point;
    
    
    void initPlaneGeometry(U4DVector3n& uNormal,U4DVector3n& uPoint);
    
};

#endif /* defined(__UntoldEngine__U4DBoundingPlane__) */
