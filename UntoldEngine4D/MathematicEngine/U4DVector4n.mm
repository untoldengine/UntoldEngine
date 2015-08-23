//
//  U4DVector4n.mm
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DVector4n.h"

namespace U4DEngine {
    
#pragma mark-show
void U4DVector4n::show(){
    
    std::cout<<"("<<x<<","<<y<<","<<z<<","<<w<<")"<<std::endl;
}

float U4DVector4n::getX(){
    
    return x;
}

float U4DVector4n::getY(){
    
    return y;
}

float U4DVector4n::getZ(){

    return z;
}

float U4DVector4n::getW(){
    
    return w;
}

}