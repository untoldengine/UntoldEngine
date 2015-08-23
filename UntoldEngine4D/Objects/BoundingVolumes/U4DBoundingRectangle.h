//
//  U4DBoundingRectangle.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoundingRectangle__
#define __UntoldEngine__U4DBoundingRectangle__

#include <iostream>
#include "U4DBoundingVolume.h"


class U4DBoundingRectangle:public U4DBoundingVolume{
  
private:
    
public:
  
    U4DBoundingRectangle(){}
    
   
    ~U4DBoundingRectangle(){};
    
    
    U4DBoundingRectangle(const U4DBoundingRectangle& value){};
    
    
    U4DBoundingRectangle& operator=(const U4DBoundingRectangle& value){
        return *this;
    };
  
    
    void initRectangleGeometry(float uWidth,float uHeight,float uDepth);
};

#endif /* defined(__UntoldEngine__U4DBoundingRectangle__) */
