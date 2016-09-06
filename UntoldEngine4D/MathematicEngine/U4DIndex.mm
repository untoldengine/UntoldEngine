//
//  U4DIndex.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DIndex.h"

namespace U4DEngine {


    U4DIndex::U4DIndex():x(0),y(0),z(0){};
    

    U4DIndex::U4DIndex(int nx,int ny,int nz):x(nx),y(ny),z(nz){}
    

    U4DIndex::~U4DIndex(){}
    

    U4DIndex::U4DIndex(const U4DIndex& a):x(a.x),y(a.y),z(a.z){}
    

    U4DIndex& U4DIndex::operator=(const U4DIndex& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        
        return *this;
        
    }

    void U4DIndex::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<")"<<std::endl;
    }

}