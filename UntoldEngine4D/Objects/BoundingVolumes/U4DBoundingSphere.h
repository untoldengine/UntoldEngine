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
#include "U4DSphere.h"

namespace U4DEngine {
    
    class U4DBoundingSphere:public U4DBoundingVolume{
      
    private:
        
        float radius;
        U4DSphere sphere; //used for mathematical operaions only
        
    public:
        
        U4DBoundingSphere();
        
        ~U4DBoundingSphere();
       
        U4DBoundingSphere(const U4DBoundingSphere& value);
        
        U4DBoundingSphere& operator=(const U4DBoundingSphere& value);
        
        void computeBoundingVolume(float uRadius,int uRings, int uSectors);
        
        void setRadius(float uRadius);
        
        float getRadius();
        
        U4DPoint3n getMaxBoundaryPoint();
        
        U4DPoint3n getMinBoundaryPoint();
        
        U4DSphere& getSphere();
        
    };

}

#endif /* defined(__UntoldEngine__U4DBoundingSphere__) */
