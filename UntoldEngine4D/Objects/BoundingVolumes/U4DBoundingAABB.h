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

namespace U4DEngine {
    
    class U4DBoundingAABB:public U4DBoundingVolume{
      
    private:
        
    public:
        
        
        U4DBoundingAABB(){};
        
      
        ~U4DBoundingAABB(){}
        
       
        U4DBoundingAABB(const U4DBoundingAABB& value){};

        
        U4DBoundingAABB& operator=(const U4DBoundingAABB& value){
            width=value.width;
            height=value.height;
            depth=value.depth;
            
            min=value.min;
            max=value.max;
            
            return *this;
        };
        
        
        float width;
        
        
        float height;
        
        
        float depth;
        
        
        U4DVector3n min;
        
        
        U4DVector3n max;
        
        
        void computeBoundingVolume(U4DVector3n& uMin,U4DVector3n& uMax);
        
    };
    
}

#endif /* defined(__UntoldEngine__U4DBoundingAABB__) */
