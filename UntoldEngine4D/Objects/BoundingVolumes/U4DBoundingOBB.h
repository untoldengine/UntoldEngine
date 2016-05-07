//
//  U4DCubeObject.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingOBB__
#define __UntoldEngine__U4DBoundingOBB__

#include <iostream>
#include "U4DBoundingVolume.h"
#include "U4DOBB.h"

namespace U4DEngine {
    
    class U4DBoundingOBB:public U4DBoundingVolume{
        
    private:
        
        U4DVector3n halfwidth;  //Positive halfwidth extents of OBB along each axis
        U4DOBB obb;   //OBB volume. This holds all the math operations for a OBB
        
    public:

        U4DBoundingOBB();
        
        ~U4DBoundingOBB();
        
        U4DBoundingOBB(const U4DBoundingOBB& value);
        
        U4DBoundingOBB& operator=(const U4DBoundingOBB& value);
        
        void computeBoundingVolume(U4DVector3n& uHalfwidth);
      
        void setHalfwidth(U4DVector3n& uHalfwidth);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DCubeObject__) */
