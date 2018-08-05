//
//  U4DMatrix3n.cpp
//  MathLibrary
//
//  Created by Harold Serrano on 5/20/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DMatrix3n.h"
#include "U4DVector3n.h"
#include "U4DQuaternion.h"
#include "Constants.h"
#include "U4DTrigonometry.h"

namespace U4DEngine {

    
U4DMatrix3n::U4DMatrix3n(){
    
    // 3x3 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    
    for (int i=0; i<9; i++) {
        matrixData[i]=0.0f;
    }
    
    matrixData[0]=matrixData[4]=matrixData[8]=1.0f;
    
}


U4DMatrix3n::U4DMatrix3n(float m0,float m3,float m6,float m1,float m4,float m7,float m2,float m5,float m8){
    
    matrixData[0]=m0;
    matrixData[3]=m3;
    matrixData[6]=m6;
    
    matrixData[1]=m1;
    matrixData[4]=m4;
    matrixData[7]=m7;
    
    matrixData[2]=m2;
    matrixData[5]=m5;
    matrixData[8]=m8;
    
}


U4DMatrix3n& U4DMatrix3n::operator=(const U4DMatrix3n& value){
    
    for (int i=0; i<9; i++) {
        matrixData[i]=value.matrixData[i];
    }
    
    return *this;
}


U4DMatrix3n::~U4DMatrix3n(){
}
    
#pragma mark-Transform vector
U4DVector3n U4DMatrix3n::operator*(const U4DVector3n & v) const{
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    return U4DVector3n(matrixData[0]*v.x+matrixData[3]*v.y+matrixData[6]*v.z,
                       matrixData[1]*v.x+matrixData[4]*v.y+matrixData[7]*v.z,
                       matrixData[2]*v.x+matrixData[5]*v.y+matrixData[8]*v.z);
    
}

U4DVector3n U4DMatrix3n::transform(const U4DVector3n& v) const{
    
    return (*this)*v;
}

#pragma mark-Multiply
U4DMatrix3n U4DMatrix3n::operator*(const U4DMatrix3n& m) const{
    
    //	0	3	6  
    //	1	4	7
    //	2	5	8
    
    //from book
    //0 1 2
    //3 4 5
    //6 7 8
    
    return U4DMatrix3n(matrixData[0]*m.matrixData[0]+ matrixData[3]*m.matrixData[1]+matrixData[6]*m.matrixData[2],
                       matrixData[0]*m.matrixData[3]+ matrixData[3]*m.matrixData[4]+matrixData[6]*m.matrixData[5],
                       matrixData[0]*m.matrixData[6]+ matrixData[3]*m.matrixData[7]+matrixData[6]*m.matrixData[8],
                       
                       matrixData[1]*m.matrixData[0]+ matrixData[4]*m.matrixData[1]+matrixData[7]*m.matrixData[2],
                       matrixData[1]*m.matrixData[3]+ matrixData[4]*m.matrixData[4]+matrixData[7]*m.matrixData[5],
                       matrixData[1]*m.matrixData[6]+ matrixData[4]*m.matrixData[7]+matrixData[7]*m.matrixData[8],
                      
                       matrixData[2]*m.matrixData[0]+ matrixData[5]*m.matrixData[1]+matrixData[8]*m.matrixData[2],
                       matrixData[2]*m.matrixData[3]+ matrixData[5]*m.matrixData[4]+matrixData[8]*m.matrixData[5],
                       matrixData[2]*m.matrixData[6]+ matrixData[5]*m.matrixData[7]+matrixData[8]*m.matrixData[8]);
    
}

void U4DMatrix3n::operator*=(const U4DMatrix3n& m){
 
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    float t1;
    float t2;
    float t3;
    
    t1=matrixData[0]*m.matrixData[0]+ matrixData[3]*m.matrixData[1]+matrixData[6]*m.matrixData[2];
    t2=matrixData[0]*m.matrixData[3]+ matrixData[3]*m.matrixData[4]+matrixData[6]*m.matrixData[5];
    t3=matrixData[0]*m.matrixData[6]+ matrixData[3]*m.matrixData[7]+matrixData[6]*m.matrixData[8];
    
    matrixData[0]=t1;
    matrixData[3]=t2;
    matrixData[6]=t3;
    
    t1=matrixData[1]*m.matrixData[0]+ matrixData[4]*m.matrixData[1]+matrixData[7]*m.matrixData[2];
    t2=matrixData[1]*m.matrixData[3]+ matrixData[4]*m.matrixData[4]+matrixData[7]*m.matrixData[5];
    t3=matrixData[1]*m.matrixData[6]+ matrixData[4]*m.matrixData[7]+matrixData[7]*m.matrixData[8];
    
    matrixData[1]=t1;
    matrixData[4]=t2;
    matrixData[7]=t3;
    
    
    t1=matrixData[2]*m.matrixData[0]+ matrixData[5]*m.matrixData[1]+matrixData[8]*m.matrixData[2];
    t2=matrixData[2]*m.matrixData[3]+ matrixData[5]*m.matrixData[4]+matrixData[8]*m.matrixData[5];
    t3=matrixData[2]*m.matrixData[6]+ matrixData[5]*m.matrixData[7]+matrixData[8]*m.matrixData[8];
    
    matrixData[2]=t1;
    matrixData[5]=t2;
    matrixData[8]=t3;
}


void U4DMatrix3n::transformMatrixAboutXAxis(float uAngle){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DTrigonometry trigonometry;
    
    uAngle=trigonometry.degreesToRad(uAngle);
    
    U4DMatrix3n m(1.0,0.0,0.0,
                  0.0,cos(uAngle),-sin(uAngle),
                  0.0,sin(uAngle),cos(uAngle));
    
    *this=m*(*this);
    
}

void U4DMatrix3n::transformMatrixAboutYAxis(float uAngle){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DTrigonometry trigonometry;
    
    uAngle=trigonometry.degreesToRad(uAngle);
    
    U4DMatrix3n m(cos(uAngle),0.0,sin(uAngle),
                  0.0,1.0,0.0,
                  -sin(uAngle),0.0,cos(uAngle));
    
    *this=m*(*this);
    
    
}

void U4DMatrix3n::transformMatrixAboutZAxis(float uAngle){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DTrigonometry trigonometry;
    
    uAngle=trigonometry.degreesToRad(uAngle);
    
    U4DMatrix3n m(cos(uAngle),-sin(uAngle),0.0,
                  sin(uAngle),cos(uAngle),0.0,
                  0.0,0.0,1.0);
  
    *this=m*(*this);
}

#pragma mark-Inverse
//set inverse
void U4DMatrix3n::setInverse(const U4DMatrix3n& m){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //from book
    //0 1 2
    //3 4 5
    //6 7 8
    
    
    float t1=m.matrixData[0]*m.matrixData[4];
    float t2=m.matrixData[0]*m.matrixData[7];
    float t3=m.matrixData[3]*m.matrixData[1];
    float t4=m.matrixData[6]*m.matrixData[1];
    float t5=m.matrixData[3]*m.matrixData[2];
    float t6=m.matrixData[6]*m.matrixData[2];
    
    //calculate the determinant
    
    float det=(t1*m.matrixData[8]-t2*m.matrixData[5]-t3*m.matrixData[8]+t4*m.matrixData[5]+t5*m.matrixData[7]-t6*m.matrixData[4]);
    
    //make sure the det is non-zero
    if (det==0.0) return;
    
    float invd=1.0f/det;
    
    float m0=(m.matrixData[4]*m.matrixData[8]-m.matrixData[7]*m.matrixData[5])*invd;
    float m3=-(m.matrixData[3]*m.matrixData[8]-m.matrixData[6]*m.matrixData[5])*invd;
    
    float m6=(m.matrixData[3]*m.matrixData[7]-m.matrixData[6]*m.matrixData[4])*invd;
    
    float m1=-(m.matrixData[1]*m.matrixData[8]-m.matrixData[7]*m.matrixData[2])*invd;
    
    float m4=(m.matrixData[0]*m.matrixData[8]-t6)*invd;
    
    float m7=-(t2-t4)*invd;
    
    float m2=(m.matrixData[1]*m.matrixData[5]-m.matrixData[4]*m.matrixData[2])*invd;
    
    float m5=-(m.matrixData[0]*m.matrixData[5]-t5)*invd;
    
    float m8=(t1-t3)*invd;
    
    matrixData[0]=m0;
    matrixData[3]=m3;
    matrixData[6]=m6;
    
    matrixData[1]=m1;
    matrixData[4]=m4;
    matrixData[7]=m7;
    
    matrixData[2]=m2;
    matrixData[5]=m5;
    matrixData[8]=m8;
    
    
}

//returns a new matrix containing the inverse of the matrix
U4DMatrix3n U4DMatrix3n::inverse()const{
    
    U4DMatrix3n result;
    result.setInverse(*this);
    return result;
    
}

//inverts the matrix
void U4DMatrix3n::invert(){
    
    setInverse(*this);
}

#pragma mark-Determinant
//get determinant;
float U4DMatrix3n::getDeterminant() const{
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    float t1=matrixData[0]*matrixData[4];
    float t2=matrixData[0]*matrixData[7];
    float t3=matrixData[3]*matrixData[1];
    float t4=matrixData[6]*matrixData[1];
    float t5=matrixData[3]*matrixData[2];
    float t6=matrixData[6]*matrixData[2];
    
    //calculate the determinant
    
    float det=(t1*matrixData[8]-t2*matrixData[5]-t3*matrixData[8]+t4*matrixData[5]+t5*matrixData[7]-t6*matrixData[4]);
    
    return det;
}

#pragma mark-Transpose

//Transpose
void U4DMatrix3n::setTranspose(const U4DMatrix3n& m){
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //3x3 transpose
    //  0   1   2
    //  3   4   5
    //  6   7   8
    
    matrixData[0]=m.matrixData[0];
    matrixData[3]=m.matrixData[1];
    matrixData[6]=m.matrixData[2];
    
    matrixData[1]=m.matrixData[3];
    matrixData[4]=m.matrixData[4];
    matrixData[7]=m.matrixData[5];
    
    matrixData[2]=m.matrixData[6];
    matrixData[5]=m.matrixData[7];
    matrixData[8]=m.matrixData[8];
    
    
}

U4DMatrix3n U4DMatrix3n::transpose() const{
    
    U4DMatrix3n result;
    result.setTranspose(*this);
    return result;
}


#pragma mark-Identity
void U4DMatrix3n::setIdentity(){
    
    for (int i=0; i<9; i++) {
        matrixData[i]=0.0f;
    }
    
    matrixData[0]=matrixData[4]=matrixData[8]=1.0f;
    
}

void U4DMatrix3n::invertAndTranspose(){
    
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //3x3 transpose
    //  0   1   2
    //  3   4   5
    //  6   7   8
    
    //find the deteminant
    
    float det=matrixData[0]*(matrixData[4]*matrixData[8]-matrixData[5]*matrixData[7])-matrixData[3]*(matrixData[1]*matrixData[8]-matrixData[2]*matrixData[7])+ matrixData[6]*(matrixData[1]*matrixData[5]-matrixData[2]*matrixData[4]);
    
    //get the transpose of the original matrix
    U4DMatrix3n transpose;
    
    transpose.matrixData[0]=matrixData[0];
    transpose.matrixData[1]=matrixData[3];
    transpose.matrixData[2]=matrixData[6];
    
    transpose.matrixData[3]=matrixData[1];
    transpose.matrixData[4]=matrixData[4];
    transpose.matrixData[5]=matrixData[7];
    
    transpose.matrixData[6]=matrixData[2];
    transpose.matrixData[7]=matrixData[5];
    transpose.matrixData[8]=matrixData[8];
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //find the adjoing and divide it by the det(M)
    float m11,m12,m13,m21,m22,m23,m31,m32,m33;
    
    m11=+(transpose.matrixData[4]*transpose.matrixData[8]-transpose.matrixData[5]*transpose.matrixData[7])/det;
    m12=-(transpose.matrixData[1]*transpose.matrixData[8]-transpose.matrixData[2]*transpose.matrixData[7])/det;
    m13=+(transpose.matrixData[1]*transpose.matrixData[5]-transpose.matrixData[2]*transpose.matrixData[4])/det;
    
    m21=-(transpose.matrixData[3]*transpose.matrixData[8]-transpose.matrixData[5]*transpose.matrixData[6])/det;
    m22=+(transpose.matrixData[0]*transpose.matrixData[8]-transpose.matrixData[2]*transpose.matrixData[6])/det;
    m23=-(transpose.matrixData[0]*transpose.matrixData[5]-transpose.matrixData[2]*transpose.matrixData[3])/det;
    
    m31=+(transpose.matrixData[3]*transpose.matrixData[7]-transpose.matrixData[4]*transpose.matrixData[6])/det;
    m32=-(transpose.matrixData[0]*transpose.matrixData[7]-transpose.matrixData[1]*transpose.matrixData[6])/det;
    m33=+(transpose.matrixData[0]*transpose.matrixData[4]-transpose.matrixData[1]*transpose.matrixData[3])/det;
    
    U4DMatrix3n preResult;
    
    preResult.matrixData[0]=m11;
    preResult.matrixData[1]=m21;
    preResult.matrixData[2]=m31;
    
    preResult.matrixData[3]=m12;
    preResult.matrixData[4]=m22;
    preResult.matrixData[5]=m32;
    
    preResult.matrixData[6]=m13;
    preResult.matrixData[7]=m23;
    preResult.matrixData[8]=m33;
    
    //transpose the matrix
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //3x3 transpose
    //  0   1   2
    //  3   4   5
    //  6   7   8
    
    matrixData[0]=preResult.matrixData[0];
    matrixData[1]=preResult.matrixData[3];
    matrixData[2]=preResult.matrixData[6];
    
    matrixData[3]=preResult.matrixData[1];
    matrixData[4]=preResult.matrixData[4];
    matrixData[5]=preResult.matrixData[7];
    
    matrixData[6]=preResult.matrixData[2];
    matrixData[7]=preResult.matrixData[5];
    matrixData[8]=preResult.matrixData[8];
    
    
}

#pragma mark-Orientation from quaternion

/*
//Orientation
void U4DMatrix3n::setOrientation(const U4DQuaternion& q){
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    matrixData[0]=1-(2*q.y*q.y + 2*q.z*q.z);
    matrixData[3]=2*q.x*q.y + 2*q.z*q.w;
    matrixData[6]=2*q.x*q.z - 2*q.y*q.w;
    
    matrixData[1]=2*q.x*q.y - 2*q.z*q.w;
    matrixData[4]=1-(2*q.x*q.x + 2*q.z*q.z);
    matrixData[7]=2*q.y*q.z + 2*q.x*q.w;
    
    matrixData[2]=2*q.x*q.z + 2*q.y*q.w;
    matrixData[5]=2*q.y*q.z - 2*q.x*q.w;
    matrixData[8]=1-(2*q.x*q.x + 2*q.y*q.y);
    
}
*/


U4DVector3n U4DMatrix3n::getFirstRowVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[0],matrixData[3],matrixData[6]);
    
    return n;
    
}

U4DVector3n U4DMatrix3n::getSecondRowVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[1],matrixData[4],matrixData[7]);
    
    return n;
    
}

U4DVector3n U4DMatrix3n::getThirdRowVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[2],matrixData[5],matrixData[8]);
    
    return n;
}

U4DVector3n U4DMatrix3n::getFirstColumnVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[0],matrixData[1],matrixData[2]);
    
    return n;
}

U4DVector3n U4DMatrix3n::getSecondColumnVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[3],matrixData[4],matrixData[5]);
    
    return n;
    
}

U4DVector3n U4DMatrix3n::getThirdColumnVector(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    U4DVector3n n(matrixData[6],matrixData[7],matrixData[8]);
    
    return n;
}


#pragma mark-Show
void U4DMatrix3n::show(){
    
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    std::cout<<"["<<matrixData[0]<<","<<matrixData[3]<<","<<matrixData[6]<<","<<std::endl;
    std::cout<<matrixData[1]<<","<<matrixData[4]<<","<<matrixData[7]<<","<<std::endl;
    std::cout<<matrixData[2]<<","<<matrixData[5]<<","<<matrixData[8]<<"]"<<std::endl;
    
}

}

