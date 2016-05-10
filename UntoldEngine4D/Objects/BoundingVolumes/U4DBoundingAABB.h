//
//  U4DBoundingAABB.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/15/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingAABB__
#define __UntoldEngine__U4DBoundingAABB__

#include <iostream>
#include <cmath>
#include "U4DBoundingVolume.h"
#include "U4DAABB.h"

namespace U4DEngine {
    
    class U4DBoundingAABB:public U4DBoundingVolume{
      
    private:
        
        U4DAABB aabb;
        
    public:
        
        U4DBoundingAABB();
        
        ~U4DBoundingAABB();
       
        U4DBoundingAABB(const U4DBoundingAABB& value);
        
        U4DBoundingAABB& operator=(const U4DBoundingAABB& value);

        U4DPoint3n getMaxBoundaryPoint();
        
        U4DPoint3n getMinBoundaryPoint();

        void computeBoundingVolume(U4DPoint3n& uMin,U4DPoint3n& uMax);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DBoundingAABB__) */
