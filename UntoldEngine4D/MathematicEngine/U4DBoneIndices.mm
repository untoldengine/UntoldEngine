//
//  U4DBoneIndices.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/14.
//  Copyright (c) 2014 Untold Engine Studios. All rights reserved.
//

#include "U4DBoneIndices.h"

namespace U4DEngine {
    
    U4DBoneIndices::U4DBoneIndices():x(0),y(0),z(0),w(0){}
    
    U4DBoneIndices::U4DBoneIndices(int nx,int ny,int nz,int nw):x(nx),y(ny),z(nz),w(nw){}
    
    U4DBoneIndices::~U4DBoneIndices(){}
    
    U4DBoneIndices::U4DBoneIndices(const U4DBoneIndices& a):x(a.x),y(a.y),z(a.z),w(a.w){}
    
    U4DBoneIndices& U4DBoneIndices::operator=(const U4DBoneIndices& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        w=a.w;
        
        return *this;
        
    }
    
    void U4DBoneIndices::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<","<<w<<")"<<std::endl;
        
    }

}
