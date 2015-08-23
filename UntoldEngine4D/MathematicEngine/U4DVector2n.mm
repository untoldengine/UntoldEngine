//
//  U4DVector2n.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DVector2n.h"

namespace U4DEngine {
    
//add
void U4DVector2n::operator+=(const U4DVector2n& v){
    
    x+=v.x;
    y+=v.y;
    
}

U4DVector2n U4DVector2n::operator+(const U4DVector2n& v)const{
    
    return U4DVector2n(x+v.x,y+v.y);
}

//substract
void U4DVector2n::operator-=(const U4DVector2n& v){
    
    x-=v.x;
    y-=v.y;
}

U4DVector2n U4DVector2n::operator-(const U4DVector2n& v)const{
    return U4DVector2n(x-v.x,y-v.y);
}

//multiply a scalar
void U4DVector2n::operator*=(const float s){
    
    x*=s;
    y*=s;
}

U4DVector2n U4DVector2n::operator*(const float s)const{
    
    return U4DVector2n(s*x,s*y);
}

//divide by scalar
void U4DVector2n::operator /=(const float s){
    
    x=x/s;
    y=y/s;
}

U4DVector2n U4DVector2n::operator/(const float s)const{
    
    return U4DVector2n(x/s,y/s);
}


//dot product
float U4DVector2n::operator*(const U4DVector2n& v) const{
    
    return x*v.x+y*v.y;
}

float U4DVector2n::dot(const U4DVector2n& v) const{
 
     return x*v.x+y*v.y;
}



//conjuage
void U4DVector2n::conjugate(){
    
    x=-1*x;
    y=-1*y;
}

//normalize
void U4DVector2n::normalize(){
    
    float mag=sqrt(x*x+y*y);
    
    if (mag>0.0f) {
        
        //normalize it
        float oneOverMag=1.0f/mag;
        
        x=x*oneOverMag;
        y=y*oneOverMag;
       
    }

}

//magnitude
float U4DVector2n::magnitude(){
    
    float magnitude=sqrt(x*x+y*y);
    
    return magnitude;
}

float U4DVector2n::squareMagnitude(){
    
    float magnitude=x*x+y*y;
    
    return magnitude;
}

//clear
void U4DVector2n::zero(){
    
    x=0;
    y=0;
}

void U4DVector2n::show(){
    
    std::cout<<"("<<x<<","<<y<<")"<<std::endl;
}

}