//
//  Vector3.cpp
//  MathLibrary
//
//  Created by Harold Serrano on 4/18/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DVector3n.h"
#include "U4DPoint3n.h"
#include "U4DQuaternion.h"
#include "Constants.h"
#include <cmath>


namespace U4DEngine {
    
    bool U4DVector3n::operator==(const U4DVector3n& a){
        
        if (x==a.x && y==a.y && z==a.z) {
            return true;
        }else{
            return false;
        }
    }

    #pragma mark-add

    void U4DVector3n::operator+=(const U4DVector3n& v){
        
        x+=v.x;
        y+=v.y;
        z+=v.z;
        
    }

    U4DVector3n U4DVector3n::operator+(const U4DVector3n& v)const{
        
        
        return U4DVector3n(x+v.x,y+v.y,z+v.z);
    }

    #pragma mark-subtract
    void U4DVector3n::operator-=(const U4DVector3n& v){
        
        x-=v.x;
        y-=v.y;
        z-=v.z;
    }

    U4DVector3n U4DVector3n::operator-(const U4DVector3n& v)const{
     
        return U4DVector3n(x-v.x,y-v.y,z-v.z);
    }

    #pragma mark-multiply scalar
    void U4DVector3n::operator*=(const float s){
        
        x*=s;
        y*=s;
        z*=s;
        
    }

    U4DVector3n U4DVector3n::operator*(const float s) const{
        
        return U4DVector3n(s*x,s*y,s*z);
    }

    #pragma mark-multiply times a matrix

    //multiply times a matrix
    U4DVector3n U4DVector3n::operator*(const U4DMatrix3n& m)const{
        
        //	0	3	6
        //	1	4	7
        //	2	5	8
        
        float newX=x*m.matrixData[0]+y*m.matrixData[1]+z*m.matrixData[2];
        float newY=x*m.matrixData[3]+y*m.matrixData[4]+z*m.matrixData[5];
        float newZ=x*m.matrixData[6]+y*m.matrixData[7]+z*m.matrixData[8];
        
        U4DVector3n result(newX,newY,newZ);
        return result;
    }

    #pragma mark-multiply times a quaternion
    U4DQuaternion U4DVector3n::operator*(U4DQuaternion& q) const{
        
        float sPart=-(q.v.x*x + q.v.y*y + q.v.z*z);
        float xPart=q.s*x + q.v.z*y - q.v.y*z;
        float yPart=q.s*y + q.v.x*z - q.v.z*x;
        float zPart=q.s*z + q.v.y*x - q.v.x*y;
        
        U4DVector3n vectorPart(xPart,yPart,zPart);
        
        U4DQuaternion result(sPart,vectorPart);
        
        return result;
        
    }

    #pragma mark-divide by scalar
    //divide by scalar
    void U4DVector3n::operator /=(const float s){
        
        x=x/s;
        y=y/s;
        z=z/s;
    }

    U4DVector3n U4DVector3n::operator/(const float s)const{
     
        return U4DVector3n(x/s,y/s,z/s);
    }

    #pragma mark-dot product
    float U4DVector3n::operator*(const U4DVector3n& v) const{
        
        return x*v.x+y*v.y+z*v.z;

    }

    float U4DVector3n::dot(const U4DVector3n& v) const{
        
        return x*v.x+y*v.y+z*v.z;

    }

    float U4DVector3n::angle(const U4DVector3n& v){
        
        float theta;
        
        U4DVector3n u=v;
        U4DVector3n m=*this;
        
        theta=dot(u)/(m.magnitude()*u.magnitude());
        
        theta=RadToDegrees(acos(theta));
        
        return theta;
        
    }

    #pragma mark-cross product
    U4DVector3n U4DVector3n::cross(const U4DVector3n& v) const{
     
        return U4DVector3n(y*v.z-z*v.y,
                           z*v.x-x*v.z,
                           x*v.y-y*v.x);
        
    }

    void U4DVector3n::operator %=(const U4DVector3n& v){
        
        *this=cross(v);
        
    }

    U4DVector3n U4DVector3n::operator %(const U4DVector3n& v) const{
        
        return U4DVector3n(y*v.z-z*v.y,
                           z*v.x-x*v.z,
                           x*v.y-y*v.x);
        
    }

    #pragma mark-normalize
    void U4DVector3n::normalize(){
        
        float mag=sqrt(x*x+y*y+z*z);
        
        if (mag>0.0f) {
            
            //normalize it
            float oneOverMag=1.0f/mag;
            
            x=x*oneOverMag;
            y=y*oneOverMag;
            z=z*oneOverMag;
            
        }
        
    }

    #pragma mark-conjugate
    void U4DVector3n::conjugate(){
        
        x=-1*x;
        y=-1*y;
        z=-1*z;
            
    }

    #pragma mark-magnitude

    float U4DVector3n::magnitude(){

        float magnitude=sqrt(x*x+y*y+z*z);
        
        return magnitude;
        
    }

    float U4DVector3n::magnitudeSquare(){
        
        float magnitude=x*x+y*y+z*z;
        
        return magnitude;
    }


    #pragma mark-to point
    U4DPoint3n U4DVector3n::toPoint(){
        
        U4DPoint3n q(x,y,z);
        
        return q;
    }

    #pragma mark-clear
    //clear
    void U4DVector3n::zero(){
        x=0;
        y=0;
        z=0;
    }

    void U4DVector3n::absolute(){
        
        x=std::abs(x);
        y=std::abs(y);
        z=std::abs(z);
        
    }



    #pragma mark-show
    void U4DVector3n::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<")"<<std::endl;
    }

    float U4DVector3n::getX(){
        
        return x;
    }

    float U4DVector3n::getY(){
        
        return y;
    }

    float U4DVector3n::getZ(){
        
        return z;
    }

    void U4DVector3n::negate(){

        x=-1*x;
        y=-1*y;
        z=-1*z;
    }
    
}