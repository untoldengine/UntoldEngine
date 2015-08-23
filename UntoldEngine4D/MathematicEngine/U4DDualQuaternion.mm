//
//  U4DDualQuaternion.cpp
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DDualQuaternion.h"
#include "U4DQuaternion.h"
#include "U4DVector3n.h"
#include "U4DMatrix3n.h"
#include "U4DMatrix4n.h"
#include <cmath>

namespace U4DEngine {
    
void U4DDualQuaternion::setRealQuaternionPart(U4DQuaternion &uqReal){
    
    qReal=uqReal;
}

void U4DDualQuaternion::setPureQuaternionPart(U4DQuaternion &uqPure){
    
    qPure=uqPure;
    
}


#pragma mark-add
//add
void U4DDualQuaternion::operator+=(const U4DDualQuaternion& q){
    
    qReal+=q.qReal;
    qPure+=q.qPure;
    
}

U4DDualQuaternion U4DDualQuaternion::operator+(const U4DDualQuaternion& q)const{
    
    U4DQuaternion real=qReal+q.qReal;
    U4DQuaternion dual=qPure+q.qPure;
    
    return U4DDualQuaternion(real,dual);
}

#pragma mark-multiply
//multiply
void U4DDualQuaternion::operator*=(const U4DDualQuaternion& q){
    
    (*this).multiply(q);
}

U4DDualQuaternion U4DDualQuaternion::operator*(const U4DDualQuaternion& q)const{
   
    
    U4DQuaternion real=q.qReal*qReal;
    
    U4DQuaternion dual=q.qPure*qReal + q.qReal*qPure;
    
    return U4DDualQuaternion(real,dual);
}

U4DDualQuaternion U4DDualQuaternion::multiply(const U4DDualQuaternion& q)const{
    
    U4DQuaternion real=q.qReal*qReal;
    U4DQuaternion dual=q.qPure*qReal + q.qReal*qPure;
    
    return U4DDualQuaternion(real,dual);

}

U4DDualQuaternion U4DDualQuaternion::operator*(const float value){
    
    U4DDualQuaternion q(qReal,qPure);
    q.qReal*=value;
    q.qPure*=value;
    return q;
    
}

float U4DDualQuaternion::dot(U4DDualQuaternion& q){
    

    return qReal.dot(q.qReal);
    
}

#pragma mark-conjugate
//conjugate
U4DDualQuaternion U4DDualQuaternion::conjugate(){
 
    U4DQuaternion realConjugate=qReal.conjugate();
    U4DQuaternion pureConjugate=qPure.conjugate();
    
    U4DDualQuaternion answer(realConjugate,pureConjugate);
    
    return answer;
    
}

U4DDualQuaternion U4DDualQuaternion::normalize(){
    
    U4DDualQuaternion q;
    
    float mag=qReal.dot(qReal);
    
    if (mag>0.000001) {
        
        q.qReal*=1/mag;
        q.qPure*=1/mag;
        
    }
    
    return q;
}

#pragma mark-extract position/rotation
//extract from dual
U4DQuaternion U4DDualQuaternion::getRealQuaternionPart(){
    
    U4DQuaternion r=qReal;
    return r;
}

U4DQuaternion U4DDualQuaternion::getPureQuaternionPart(){
    
    U4DQuaternion rConj=qReal.conjugate();
    
    U4DQuaternion t=qPure*2*rConj;
    
    return t;
}

#pragma mark-matrix transform
//matrixTransform
U4DMatrix4n U4DDualQuaternion::transformDualQuaternionToMatrix4n(){
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    U4DMatrix4n result;
    U4DMatrix3n m=qReal.transformQuaternionToMatrix3n();
    
    result.matrixData[0]=m.matrixData[0];
    result.matrixData[4]=m.matrixData[3];
    result.matrixData[8]=m.matrixData[6];
    
    result.matrixData[1]=m.matrixData[1];
    result.matrixData[5]=m.matrixData[4];
    result.matrixData[9]=m.matrixData[7];
    
    result.matrixData[2]=m.matrixData[2];
    result.matrixData[6]=m.matrixData[5];
    result.matrixData[10]=m.matrixData[8];
    
    //extract the position info
    
    U4DQuaternion t=getPureQuaternionPart();
    
    result.matrixData[12]=t.v.x;
    result.matrixData[13]=t.v.y;
    result.matrixData[14]=t.v.z;
    
    return result;
    
}

void U4DDualQuaternion::transformMatrix4nToDualQuaternion(U4DMatrix4n &uMatrix){
    
    //break down the matrix 4x4 into a 3x3 matrix
    U4DMatrix3n matrix=uMatrix.extract3x3Matrix();
    
    //convert the matrix 3x3 into a quaternion
    
    U4DQuaternion quaternion;
    quaternion.transformMatrix3nToQuaternion(matrix);
    
    
    //Get the translation part of the matrix4x4
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    U4DVector3n translationVector(uMatrix.matrixData[12],uMatrix.matrixData[13],uMatrix.matrixData[14]);
    
    
    
    //convert to dual quaternion
    U4DDualQuaternion dualQuaternion(quaternion,translationVector);
    
    (*this)=dualQuaternion;
    
}

U4DDualQuaternion U4DDualQuaternion::sclerp(U4DDualQuaternion& uToDualQuaternion,float t){
    
    //U4DDualQuaternion uFrom(qReal,qPure);
    
    //Shortest path
    float dot=(*this).dot(uToDualQuaternion);
    
    if (dot<0.0) {
      
        uToDualQuaternion=uToDualQuaternion*-1.0;
        
    }
    
    //slerp=qa(qa^-1 qb)^t
    U4DDualQuaternion diff=(*this).conjugate()*uToDualQuaternion;
    
    U4DVector3n vr(diff.qReal.v.x,diff.qReal.v.y,diff.qReal.v.z);
    U4DVector3n vd(diff.qPure.v.x,diff.qPure.v.y,diff.qPure.v.z);
    
    float invr;
    
    if (vr.magnitude()==0) {
        invr=1.0;
    }else{
        invr=1/vr.magnitude();
    }
    
    //Screw parameters
    float angle=2*acos(diff.qReal.s);
    float pitch=-2*diff.qPure.s*invr;
    
    U4DVector3n direction=vr*invr;
    U4DVector3n moment=(vd-direction*pitch*diff.qReal.s*0.5)*invr;
    
    //exponential power
    angle*=t;
    pitch*=t;
    
    //convert back to dual-quaternion
    
    float sinAngle=sin(0.5*angle);
    float cosAngle=cos(0.5*angle);
    
    U4DVector3n realVector=direction*sinAngle;
    U4DVector3n pureVector=moment*sinAngle+(direction*0.5)*(pitch*cosAngle);
    
    
    U4DQuaternion real(cosAngle,realVector);
    U4DQuaternion dual(-pitch*0.5*sinAngle,pureVector);
    
    //complete the multiplication and return the interpolated value
    U4DDualQuaternion sclerpDualQuaternion(real,dual);
    
    sclerpDualQuaternion=(*this)*sclerpDualQuaternion;
    
    return sclerpDualQuaternion;
    
    
}

#pragma mark-Show
//show
void U4DDualQuaternion::show(){
  
    std::cout<<"Real"<<std::endl;
    qReal.show();
    std::cout<<"Pure"<<std::endl;
    qPure.show();
    
}
    
}
