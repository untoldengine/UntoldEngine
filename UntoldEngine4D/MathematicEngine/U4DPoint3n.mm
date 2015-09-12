//
//  U4DPoint3n.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/9/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DPoint3n.h"
#include "U4DVector3n.h"


namespace U4DEngine {
    

    bool U4DPoint3n::operator==(const U4DPoint3n& a){
        
        if (x==a.x && y==a.y && z==a.z) {
            return true;
        }else{
            return false;
        }
    }

    U4DVector3n U4DPoint3n::operator-(const U4DPoint3n& p)const{
        
        return U4DVector3n(p.x-x,p.y-y,p.z-z);
        
    }


    #pragma mark-add

    //add
    void U4DPoint3n::operator+=(const U4DPoint3n& v){
        
        x+=v.x;
        y+=v.y;
        z+=v.z;
    }

    U4DPoint3n U4DPoint3n::operator+(const U4DPoint3n& v)const{
        
        U4DPoint3n q(x+v.x,y+v.y,z+v.z);
        
        return q;
    }

    U4DPoint3n U4DPoint3n::operator*(const float s) const{
        
        return U4DPoint3n(s*x,s*y,s*z);
    }

    #pragma mark-distance between points
    //distance between two points
    float U4DPoint3n::distanceBetweenPoints(U4DPoint3n& v){
        
        float x1=x-v.x;
        float y1=y-v.y;
        float z1=z-v.z;
        
        float d=sqrt(x1*x1 + y1*y1 + z1*z1);
        return d;
        
    }

    void U4DPoint3n::convertVectorToPoint(U4DVector3n& v){
        
        x=v.x;
        y=v.y;
        z=v.z;
        
    }
    
    float U4DPoint3n::magnitude(){
        
        float magnitude=sqrt(x*x+y*y+z*z);
        
        return magnitude;
        
    }
    
    float U4DPoint3n::magnitudeSquare(){
        
        float magnitude=x*x+y*y+z*z;
        
        return magnitude;
    }
    

    #pragma mark-show
    void U4DPoint3n::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<")"<<std::endl;
    }

    U4DVector3n U4DPoint3n::toVector(){
        
        U4DVector3n vec(x,y,z);
        
        return vec;
    }
    
    

}

