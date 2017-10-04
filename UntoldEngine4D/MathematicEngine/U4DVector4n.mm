//
//  U4DVector4n.mm
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DVector4n.h"

namespace U4DEngine {
    

    U4DVector4n::U4DVector4n(){
    
        x=0.0;
        y=0.0;
        z=0.0;
        w=0.0;
        
    }
    
    U4DVector4n::U4DVector4n(float nx,float ny,float nz,float nw):x(nx),y(ny),z(nz),w(nw){}
    
    U4DVector4n::~U4DVector4n(){}
    
    U4DVector4n::U4DVector4n(const U4DVector4n& a):x(a.x),y(a.y),z(a.z),w(a.w){}
    
    U4DVector4n& U4DVector4n::operator=(const U4DVector4n& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        w=a.w;
        
        return *this;
        
    }
    
    float U4DVector4n::dot(const U4DVector4n& v) const{
        
        return x*v.x+y*v.y+z*v.z+w*v.w;
        
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
    
    
    void U4DVector4n::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<","<<w<<")"<<std::endl;
    }

}
