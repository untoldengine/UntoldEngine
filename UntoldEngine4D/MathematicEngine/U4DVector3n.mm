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
#include "U4DNumerical.h"
#include "U4DTrigonometry.h"
#include <cmath>

namespace U4DEngine {
    
    U4DVector3n::U4DVector3n(){
        
        x=0.0;
        y=0.0;
        z=0.0;
    }
    
    U4DVector3n::U4DVector3n(float nx,float ny,float nz):x(nx),y(ny),z(nz){}
    
    U4DVector3n::~U4DVector3n(){}
    
    U4DVector3n::U4DVector3n(const U4DVector3n& a):x(a.x),y(a.y),z(a.z){
        
    }
    
    U4DVector3n& U4DVector3n::operator=(const U4DVector3n& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        
        return *this;
        
    }
    
    bool U4DVector3n::operator==(const U4DVector3n& a){
        
        U4DNumerical comparison;
        
        if (comparison.areEqual(x, a.x, U4DEngine::zeroEpsilon) && comparison.areEqual(y, a.y, U4DEngine::zeroEpsilon) && comparison.areEqual(z, a.z, U4DEngine::zeroEpsilon)) {
            return true;
        }else{
            return false;
        }
        
    }

    void U4DVector3n::operator+=(const U4DVector3n& v){
        
        x+=v.x;
        y+=v.y;
        z+=v.z;
        
    }

    U4DVector3n U4DVector3n::operator+(const U4DVector3n& v)const{
        
        
        return U4DVector3n(x+v.x,y+v.y,z+v.z);
    }

    void U4DVector3n::operator-=(const U4DVector3n& v){
        
        x-=v.x;
        y-=v.y;
        z-=v.z;
    }

    U4DVector3n U4DVector3n::operator-(const U4DVector3n& v)const{
     
        return U4DVector3n(x-v.x,y-v.y,z-v.z);
    }

    
    void U4DVector3n::operator*=(const float s){
        
        x*=s;
        y*=s;
        z*=s;
        
    }

    U4DVector3n U4DVector3n::operator*(const float s) const{
        
        return U4DVector3n(s*x,s*y,s*z);
    }


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

    
    U4DQuaternion U4DVector3n::operator*(U4DQuaternion& q) const{
        
        float sPart=-(q.v.x*x + q.v.y*y + q.v.z*z);
        float xPart=q.s*x + q.v.z*y - q.v.y*z;
        float yPart=q.s*y + q.v.x*z - q.v.z*x;
        float zPart=q.s*z + q.v.y*x - q.v.x*y;
        
        U4DVector3n vectorPart(xPart,yPart,zPart);
        
        U4DQuaternion result(sPart,vectorPart);
        
        return result;
        
    }

    
    //divide by scalar
    void U4DVector3n::operator /=(const float s){
        
        x=x/s;
        y=y/s;
        z=z/s;
    }

    U4DVector3n U4DVector3n::operator/(const float s)const{
     
        return U4DVector3n(x/s,y/s,z/s);
    }

    
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
        
        //keep theta bounded by [-1,1]
        if (theta>1.0) {
            theta=1.0;
        }else if(theta<-1.0){
            theta=-1.0;
        }
        
        U4DTrigonometry trigonometry;
        
        theta=trigonometry.radToDegrees(acos(theta));
        
        return theta;
        
    }

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

    
    void U4DVector3n::conjugate(){
        
        x=-1*x;
        y=-1*y;
        z=-1*z;
            
    }


    float U4DVector3n::magnitude(){

        float magnitude=sqrt(x*x+y*y+z*z);
        
        return magnitude;
        
    }

    float U4DVector3n::magnitudeSquare(){
        
        float magnitude=x*x+y*y+z*z;
        
        return magnitude;
    }


    U4DPoint3n U4DVector3n::toPoint(){
        
        U4DPoint3n q(x,y,z);
        
        return q;
    }

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

    U4DVector3n U4DVector3n::rotateVectorAboutAngleAndAxis(float uAngle, U4DVector3n& uAxis){
        
        //convert our vector to a pure quaternion
        
        U4DQuaternion p(0,(*this));
        
        //normalize the axis
        uAxis.normalize();
        
        //create the real quaternion
        U4DQuaternion q(uAngle,uAxis);
        
        //convert quaternion to unit norm quaternion
        q.convertToUnitNormQuaternion();
        
        U4DQuaternion qInverse=q.inverse();
        
        U4DQuaternion rotatedVector=q*p*qInverse;
        
        return rotatedVector.v;
        
    }

    void U4DVector3n::show(){
        
        std::cout<<"("<<x<<","<<y<<","<<z<<")"<<std::endl;
    }
    
    void U4DVector3n::show(std::string uString){
        
        std::cout<<uString<<std::endl;
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
    
    void U4DVector3n::computeOrthonormalBasis(U4DVector3n& uTangent1, U4DVector3n& uTangent2){
        
        //From Erin Catto
        if (std::fabs(x)>=0.57735f) {
            
            uTangent1.x=y;
            uTangent1.y=-x;
            uTangent1.z=0.0;
            
        }else{
            
            uTangent1.x=0.0;
            uTangent1.y=z;
            uTangent1.z=-y;
            
        }
        
        uTangent1.normalize();
        
        uTangent2=(*this).cross(uTangent1);
        
    }
    
}
