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
#include <vector>
#include "U4DPoint3n.h"
#include "U4DBoundingVolume.h"
#include "U4DPlane.h"

namespace U4DEngine {
    
class U4DBoundingOBB:public U4DBoundingVolume{
    
private:
    
public:
    
    /*!
     *  @brief  Positive halfspace extents of OBB along each axis
     */
    U4DVector3n halfSpace;
    
    U4DBoundingOBB(){};
    
    ~U4DBoundingOBB(){};
    
    U4DBoundingOBB(const U4DBoundingOBB& value){};
    
    U4DBoundingOBB& operator=(const U4DBoundingOBB& value){
        return *this;
    };
    
    void initBoundingVolume(U4DVector3n& uHalfSpace);
  
   
};
    
}

#endif /* defined(__UntoldEngine__U4DCubeObject__) */
