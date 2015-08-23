//
//  U4DBoundingSphere.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingSphere__
#define __UntoldEngine__U4DBoundingSphere__

#include <iostream>
#include "U4DBoundingVolume.h"

namespace U4DEngine {
    
class U4DBoundingSphere:public U4DBoundingVolume{
  
private:
    
public:
    
   
    U4DBoundingSphere(){}
    
    
    ~U4DBoundingSphere(){}
    
   
    U4DBoundingSphere(const U4DBoundingSphere& value){
        radius=value.radius;
    };
    
    
    U4DBoundingSphere& operator=(const U4DBoundingSphere& value){
        radius=value.radius;
        return *this;
    };
    
    
    float radius;
    
   
    U4DVector3n offset;
    
    
    void initBoundingVolume(float uRadius,int uRings, int uSectors);
    
   
   // void initSphere(float uRadius,U4DVector3n& uOffset,int uRings, int uSectors);
};

}

#endif /* defined(__UntoldEngine__U4DBoundingSphere__) */
