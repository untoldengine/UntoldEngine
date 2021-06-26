//
//  U4DMatrix4n.cpp
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#include "U4DVector3n.h"
#include "U4DQuaternion.h"
#include "Constants.h"
#include "U4DLogger.h"

namespace U4DEngine {
// 4x4 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
//	0	4	8	12
//	1	5	9	13
//	2	6	10	14
//	3	7	11	15
    
    
U4DMatrix4n::U4DMatrix4n(){
    
    // 4x4 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    for (int i=0; i<16; i++) {
        matrixData[i]=0.0f;
    }
    
    matrixData[0]=matrixData[5]=matrixData[10]=matrixData[15]=1.0f;
    
};


U4DMatrix4n::U4DMatrix4n(float m0,float m4,float m8,float m12,float m1,float m5,float m9,float m13,float m2,float m6,float m10,float m14,float m3,float m7, float m11,float m15){
    
    matrixData[0]=m0;
    matrixData[4]=m4;
    matrixData[8]=m8;
    matrixData[12]=m12;
    
    matrixData[1]=m1;
    matrixData[5]=m5;
    matrixData[9]=m9;
    matrixData[13]=m13;
    
    matrixData[2]=m2;
    matrixData[6]=m6;
    matrixData[10]=m10;
    matrixData[14]=m14;
    
    matrixData[3]=m3;
    matrixData[7]=m7;
    matrixData[11]=m11;
    matrixData[15]=m15;
    
}

U4DMatrix4n& U4DMatrix4n::operator=(const U4DMatrix4n& value){
    
    for (int i=0; i<16; i++) {
        matrixData[i]=value.matrixData[i];
    }
    
    return *this;
}


U4DMatrix4n::~U4DMatrix4n(){}

//multiply
#pragma mark-multiply

U4DMatrix4n U4DMatrix4n::multiply(const U4DMatrix4n& m)const{
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    U4DMatrix4n result;
    
    result.matrixData[0]=matrixData[0]*m.matrixData[0]+matrixData[4]*m.matrixData[1]+matrixData[8]*m.matrixData[2]+matrixData[12]*m.matrixData[3];
    
    result.matrixData[4]=matrixData[0]*m.matrixData[4]+matrixData[4]*m.matrixData[5]+matrixData[8]*m.matrixData[6]+matrixData[12]*m.matrixData[7];
    
    result.matrixData[8]=matrixData[0]*m.matrixData[8]+matrixData[4]*m.matrixData[9]+matrixData[8]*m.matrixData[10]+matrixData[12]*m.matrixData[11];
    
    result.matrixData[12]=matrixData[0]*m.matrixData[12]+matrixData[4]*m.matrixData[13]+matrixData[8]*m.matrixData[14]+matrixData[12]*m.matrixData[15];
    
    
    
    result.matrixData[1]=matrixData[1]*m.matrixData[0]+matrixData[5]*m.matrixData[1]+matrixData[9]*m.matrixData[2]+matrixData[13]*m.matrixData[3];
    
    result.matrixData[5]=matrixData[1]*m.matrixData[4]+matrixData[5]*m.matrixData[5]+matrixData[9]*m.matrixData[6]+matrixData[13]*m.matrixData[7];
    
    result.matrixData[9]=matrixData[1]*m.matrixData[8]+matrixData[5]*m.matrixData[9]+matrixData[9]*m.matrixData[10]+matrixData[13]*m.matrixData[11];
    
    result.matrixData[13]=matrixData[1]*m.matrixData[12]+matrixData[5]*m.matrixData[13]+matrixData[9]*m.matrixData[14]+matrixData[13]*m.matrixData[15];
    
    
    
    result.matrixData[2]=matrixData[2]*m.matrixData[0]+matrixData[6]*m.matrixData[1]+matrixData[10]*m.matrixData[2]+matrixData[14]*m.matrixData[3];
    
    result.matrixData[6]=matrixData[2]*m.matrixData[4]+matrixData[6]*m.matrixData[5]+matrixData[10]*m.matrixData[6]+matrixData[14]*m.matrixData[7];
    
    result.matrixData[10]=matrixData[2]*m.matrixData[8]+matrixData[6]*m.matrixData[9]+matrixData[10]*m.matrixData[10]+matrixData[14]*m.matrixData[11];
    
    result.matrixData[14]=matrixData[2]*m.matrixData[12]+matrixData[6]*m.matrixData[13]+matrixData[10]*m.matrixData[14]+matrixData[14]*m.matrixData[15];
    
    
    
    
    result.matrixData[3]=matrixData[3]*m.matrixData[0]+matrixData[7]*m.matrixData[1]+matrixData[11]*m.matrixData[2]+matrixData[15]*m.matrixData[3];
    
    result.matrixData[7]=matrixData[3]*m.matrixData[4]+matrixData[7]*m.matrixData[5]+matrixData[11]*m.matrixData[6]+matrixData[15]*m.matrixData[7];
    
    result.matrixData[11]=matrixData[3]*m.matrixData[8]+matrixData[7]*m.matrixData[9]+matrixData[11]*m.matrixData[10]+matrixData[15]*m.matrixData[11];
    
    result.matrixData[15]=matrixData[3]*m.matrixData[12]+matrixData[7]*m.matrixData[13]+matrixData[11]*m.matrixData[14]+matrixData[15]*m.matrixData[15];
    
    return result;
}

//multiply
U4DMatrix4n U4DMatrix4n::operator*(const U4DMatrix4n& m)const{
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    
    
    U4DMatrix4n result;
    
    result.matrixData[0]=matrixData[0]*m.matrixData[0]+matrixData[4]*m.matrixData[1]+matrixData[8]*m.matrixData[2]+matrixData[12]*m.matrixData[3];
    
    result.matrixData[4]=matrixData[0]*m.matrixData[4]+matrixData[4]*m.matrixData[5]+matrixData[8]*m.matrixData[6]+matrixData[12]*m.matrixData[7];
    
    result.matrixData[8]=matrixData[0]*m.matrixData[8]+matrixData[4]*m.matrixData[9]+matrixData[8]*m.matrixData[10]+matrixData[12]*m.matrixData[11];
    
    result.matrixData[12]=matrixData[0]*m.matrixData[12]+matrixData[4]*m.matrixData[13]+matrixData[8]*m.matrixData[14]+matrixData[12]*m.matrixData[15];
    
    
    
    result.matrixData[1]=matrixData[1]*m.matrixData[0]+matrixData[5]*m.matrixData[1]+matrixData[9]*m.matrixData[2]+matrixData[13]*m.matrixData[3];
    
    result.matrixData[5]=matrixData[1]*m.matrixData[4]+matrixData[5]*m.matrixData[5]+matrixData[9]*m.matrixData[6]+matrixData[13]*m.matrixData[7];
    
    result.matrixData[9]=matrixData[1]*m.matrixData[8]+matrixData[5]*m.matrixData[9]+matrixData[9]*m.matrixData[10]+matrixData[13]*m.matrixData[11];
    
    result.matrixData[13]=matrixData[1]*m.matrixData[12]+matrixData[5]*m.matrixData[13]+matrixData[9]*m.matrixData[14]+matrixData[13]*m.matrixData[15];
    
    
    
    result.matrixData[2]=matrixData[2]*m.matrixData[0]+matrixData[6]*m.matrixData[1]+matrixData[10]*m.matrixData[2]+matrixData[14]*m.matrixData[3];
    
    result.matrixData[6]=matrixData[2]*m.matrixData[4]+matrixData[6]*m.matrixData[5]+matrixData[10]*m.matrixData[6]+matrixData[14]*m.matrixData[7];
    
    result.matrixData[10]=matrixData[2]*m.matrixData[8]+matrixData[6]*m.matrixData[9]+matrixData[10]*m.matrixData[10]+matrixData[14]*m.matrixData[11];
    
    result.matrixData[14]=matrixData[2]*m.matrixData[12]+matrixData[6]*m.matrixData[13]+matrixData[10]*m.matrixData[14]+matrixData[14]*m.matrixData[15];
    
    
    
    
    result.matrixData[3]=matrixData[3]*m.matrixData[0]+matrixData[7]*m.matrixData[1]+matrixData[11]*m.matrixData[2]+matrixData[15]*m.matrixData[3];
    
    result.matrixData[7]=matrixData[3]*m.matrixData[4]+matrixData[7]*m.matrixData[5]+matrixData[11]*m.matrixData[6]+matrixData[15]*m.matrixData[7];
    
    result.matrixData[11]=matrixData[3]*m.matrixData[8]+matrixData[7]*m.matrixData[9]+matrixData[11]*m.matrixData[10]+matrixData[15]*m.matrixData[11];
    
    result.matrixData[15]=matrixData[3]*m.matrixData[12]+matrixData[7]*m.matrixData[13]+matrixData[11]*m.matrixData[14]+matrixData[15]*m.matrixData[15];
    
    return result;
}

//multiply

void U4DMatrix4n::operator*=(const U4DMatrix4n& m){
    
    (*this)=multiply(m);
}

#pragma mark-transform
//transform the given vector by this matrix

U4DVector3n U4DMatrix4n::operator*(const U4DVector3n& v) const{
   
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    return U4DVector3n(matrixData[0]*v.x+matrixData[4]*v.y+matrixData[8]*v.z+matrixData[12],
                       matrixData[1]*v.x+matrixData[5]*v.y+matrixData[9]*v.z+matrixData[13],
                       matrixData[2]*v.x+matrixData[6]*v.y+matrixData[10]*v.z+matrixData[14]);
    
    
}

//transform the given vector by this matrix

U4DVector3n U4DMatrix4n::transform(const U4DVector3n& v) const{
    
    return (*this)*v;
}

#pragma mark-determinant
//get determinant
float U4DMatrix4n::getDeterminant() const{
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    
    return (matrixData[0]*(matrixData[5]*(matrixData[10]*matrixData[15]-matrixData[14]*matrixData[11])-
                   matrixData[9]*(matrixData[6]*matrixData[15]-matrixData[14]*matrixData[7])+
                   matrixData[13]*(matrixData[6]*matrixData[11]-matrixData[10]*matrixData[7]))-
    matrixData[4]*(matrixData[1]*(matrixData[10]*matrixData[15]-matrixData[14]*matrixData[11])-
                   matrixData[9]*(matrixData[2]*matrixData[15]-matrixData[14]*matrixData[3])+
                   matrixData[13]*(matrixData[2]*matrixData[11]-matrixData[3]*matrixData[10]))+
    matrixData[8]*(matrixData[1]*(matrixData[6]*matrixData[15]-matrixData[14]*matrixData[7])-
                   matrixData[5]*(matrixData[2]*matrixData[15]-matrixData[14]*matrixData[3])+
                   matrixData[13]*(matrixData[2]*matrixData[7]-matrixData[6]*matrixData[3]))-
    matrixData[12]*(matrixData[1]*(matrixData[6]*matrixData[11]-matrixData[7]*matrixData[10])-
                    matrixData[5]*(matrixData[2]*matrixData[11]-matrixData[10]*matrixData[3])+
                    matrixData[9]*(matrixData[2]*matrixData[7]-matrixData[6]*matrixData[3])));
    
}

#pragma mark-inverse
//set the matrix to be the inverse of the given matrix
void U4DMatrix4n::setInverse(const U4DMatrix4n& m){
    
    
    float det=m.matrixData[0]*(m.matrixData[5]*(m.matrixData[10]*m.matrixData[15]-m.matrixData[14]*m.matrixData[11])-
                             m.matrixData[9]*(m.matrixData[6]*m.matrixData[15]-m.matrixData[14]*m.matrixData[7])+
                             m.matrixData[13]*(m.matrixData[6]*m.matrixData[11]-m.matrixData[10]*m.matrixData[7]))-
    m.matrixData[4]*(m.matrixData[1]*(m.matrixData[10]*m.matrixData[15]-m.matrixData[14]*m.matrixData[11])-
                   m.matrixData[9]*(m.matrixData[2]*m.matrixData[15]-m.matrixData[14]*m.matrixData[3])+
                   m.matrixData[13]*(m.matrixData[2]*m.matrixData[11]-m.matrixData[3]*m.matrixData[10]))+
    m.matrixData[8]*(m.matrixData[1]*(m.matrixData[6]*m.matrixData[15]-m.matrixData[14]*m.matrixData[7])-
                   m.matrixData[5]*(m.matrixData[2]*m.matrixData[15]-m.matrixData[14]*m.matrixData[3])+
                   m.matrixData[13]*(m.matrixData[2]*m.matrixData[7]-m.matrixData[6]*m.matrixData[3]))-
    m.matrixData[12]*(m.matrixData[1]*(m.matrixData[6]*m.matrixData[11]-m.matrixData[7]*m.matrixData[10])-
                    m.matrixData[5]*(m.matrixData[2]*m.matrixData[11]-m.matrixData[10]*m.matrixData[3])+
                    m.matrixData[9]*(m.matrixData[2]*m.matrixData[7]-m.matrixData[6]*m.matrixData[3]));
    
    if (det==0) return;
    
    det=1.0f/det;
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    float a11=m.matrixData[0];
    float a12=m.matrixData[4];
    float a13=m.matrixData[8];
    float a14=m.matrixData[12];
    
    float a21=m.matrixData[1];
    float a22=m.matrixData[5];
    float a23=m.matrixData[9];
    float a24=m.matrixData[13];
    
    float a31=m.matrixData[2];
    float a32=m.matrixData[6];
    float a33=m.matrixData[10];
    float a34=m.matrixData[14];
    
    float a41=m.matrixData[3];
    float a42=m.matrixData[7];
    float a43=m.matrixData[11];
    float a44=m.matrixData[15];
    
    float b0=a22*a33*a44 + a23*a34*a42 +a24*a32*a43 - a22*a34*a43 -a23*a32*a44 - a24*a33*a42;
    float b4=a12*a34*a43 + a13*a32*a44 + a14*a33*a42 - a12*a33*a44 - a13*a34*a42 - a14*a32*a43;
    float b8=a12*a23*a44 + a13*a24*a42 + a14*a22*a43 - a12*a24*a43 - a13*a22*a44-a14*a23*a42;
    float b12=a12*a24*a33 + a13*a22*a34 +a14*a23*a32 - a12*a23*a34 - a13*a24*a32 - a14*a22*a33;
   
    float b1=a21*a34*a43 + a23*a31*a44 + a24*a33*a41 - a21*a33*a44 - a23*a34*a41 - a24*a31*a43;
    float b5=a11*a33*a44 + a13*a34*a41 + a14*a31*a43 - a11*a34*a43 -a13*a31*a44 - a14*a33*a41;
    float b9=a11*a24*a43 + a13*a21*a44 + a14*a23*a41 - a11*a23*a44 - a13*a24*a41 - a14*a21*a43;
    float b13=a11*a23*a34 + a13*a24*a31 + a14*a21*a33 - a11*a24*a33 - a13*a21*a34 - a14*a23*a31;
    
    float b2=a21*a32*a44 + a22*a34*a41 + a24*a31*a42 - a21*a34*a42 - a22*a31*a44 - a24*a32*a41;
    float b6=a11*a34*a42 + a12*a31*a44 + a14*a32*a41 - a11*a32*a44 - a12*a34*a41 - a14*a31*a42;
    float b10=a11*a22*a44 + a12*a24*a41 + a14*a21*a42 - a11*a24*a42 - a12*a21*a44 - a14*a22*a41;
    float b14=a11*a24*a32 + a12*a21*a34 + a14*a22*a31 - a11*a22*a34 - a12*a24*a31 - a14*a21*a32;
    
    float b3=a21*a33*a42 + a22*a31*a43 + a23*a32*a41 - a21*a32*a43 - a22*a33*a41 - a23*a31*a42;
    float b7=a11*a32*a43 + a12*a33*a41 + a13*a31*a42 - a11*a33*a42 - a12*a31*a43 - a13*a32*a41;
    float b11=a11*a23*a42 + a12*a21*a43 + a13*a22*a41 - a11*a22*a43 - a12*a23*a41 - a13*a21*a42;
    float b15=a11*a22*a33 + a12*a23*a31 +a13*a21*a32 - a11*a23*a32 - a12*a21*a33 - a13*a22*a31;
    
    matrixData[0]=b0*det;
    matrixData[4]=b4*det;
    matrixData[8]=b8*det;
    matrixData[12]=b12*det;
    
    matrixData[1]=b1*det;
    matrixData[5]=b5*det;
    matrixData[9]=b9*det;
    matrixData[13]=b13*det;
    
    matrixData[2]=b2*det;
    matrixData[6]=b6*det;
    matrixData[10]=b10*det;
    matrixData[14]=b14*det;
    
    matrixData[3]=b3*det;
    matrixData[7]=b7*det;
    matrixData[11]=b11*det;
    matrixData[15]=b15*det;
}

//returns a new matrix containing the inverse of this matrix
U4DMatrix4n U4DMatrix4n::inverse()const{
    
    U4DMatrix4n result;
    result.setInverse(*this);
    return result;
}

//inverts the matrix
void U4DMatrix4n::invert(){
 
    setInverse(*this);
}

#pragma mark-extract
U4DMatrix3n U4DMatrix4n::extract3x3Matrix(){
    
    //3x3 Matrix
    //	0	3	6
    //	1	4	7
    //	2	5	8
    
    //4x4 Matrix
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    U4DMatrix3n result;
    
    result.matrixData[0]=matrixData[0];
    result.matrixData[1]=matrixData[1];
    result.matrixData[2]=matrixData[2];
    
    result.matrixData[3]=matrixData[4];
    result.matrixData[4]=matrixData[5];
    result.matrixData[5]=matrixData[6];
    
    result.matrixData[6]=matrixData[8];
    result.matrixData[7]=matrixData[9];
    result.matrixData[8]=matrixData[10];
    
    return result;
    
}
    
U4DVector3n U4DMatrix4n::extractAffineVector(){
    
    //4x4 Matrix
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    U4DVector3n result;
    
    result.x=matrixData[12];
    result.y=matrixData[13];
    result.z=matrixData[14];
    
    return result;
    
}

#pragma mark-Transpose
//transpose
void U4DMatrix4n::setTranspose(const U4DMatrix4n& m){
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    //transpose
    
    // 0 1 2 3
    // 4 5 6 7
    // 8 9 10 11
    // 12 13 14 15
    
    matrixData[0]=m.matrixData[0];
    matrixData[4]=m.matrixData[1];
    matrixData[8]=m.matrixData[2];
    matrixData[12]=m.matrixData[3];
    
    matrixData[1]=m.matrixData[4];
    matrixData[5]=m.matrixData[5];
    matrixData[9]=m.matrixData[6];
    matrixData[13]=m.matrixData[7];
    
    matrixData[2]=m.matrixData[8];
    matrixData[6]=m.matrixData[9];
    matrixData[10]=m.matrixData[10];
    matrixData[14]=m.matrixData[11];
    
    matrixData[3]=m.matrixData[12];
    matrixData[7]=m.matrixData[13];
    matrixData[11]=m.matrixData[14];
    matrixData[15]=m.matrixData[15];
    
}

U4DMatrix4n U4DMatrix4n::transpose() const{
    
    U4DMatrix4n result;
    
    result.setTranspose(*this);
    return result;
    
}

/*
#pragma mark-Orientation

//orientation and position
void U4DMatrix4n::setOrientationAndPos(const U4DQuaternion& q, const U4DVector3n& v){
    
    //	0	4	8	12
    //	1	5	9	13
    //	2	6	10	14
    //	3	7	11	15
    
    matrixData[0]=1-(2*q.y*q.y + 2*q.z*q.z);
    matrixData[4]=2*q.x*q.y + 2*q.z*q.w;
    matrixData[8]=2*q.x*q.z - 2*q.y*q.w;
    matrixData[12]=v.x;
    
    
    matrixData[1]=2*q.x*q.y - 2*q.z*q.w;
    matrixData[5]=1-(2*q.x*q.x + 2*q.z*q.z);
    matrixData[9]=2*q.y*q.z + 2*q.x*q.w;
    matrixData[13]=v.y;
    
    
    matrixData[2]=2*q.x*q.z + 2*q.y*q.w;
    matrixData[6]=2*q.y*q.z - 2*q.x*q.w;
    matrixData[10]=1-(2*q.x*q.x + 2*q.y*q.y);
    matrixData[14]=v.z;
    
    //just to make sure the matrix is proper
    
    matrixData[3]=matrixData[7]=matrixData[11]=0.0;
    matrixData[15]=1.0;
}

 */

#pragma mark-show
void U4DMatrix4n::show(){
    /*
    std::cout<<"["<<matrixData[0]<<","<<matrixData[4]<<","<<matrixData[8]<<","<<matrixData[12]<<","<<std::endl;
    std::cout<<matrixData[1]<<","<<matrixData[5]<<","<<matrixData[9]<<","<<matrixData[13]<<","<<std::endl;
    std::cout<<matrixData[2]<<","<<matrixData[6]<<","<<matrixData[10]<<","<<matrixData[14]<<","<<std::endl;
    std::cout<<matrixData[3]<<","<<matrixData[7]<<","<<matrixData[11]<<","<<matrixData[15]<<"]"<<std::endl;
*/
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    logger->log("[%f,%f,%f,%f,\n%f,%f,%f,%f,\n%f,%f,%f,%f,\n%f,%f,%f,%f",
                matrixData[0],matrixData[4],matrixData[8],matrixData[12],
                matrixData[1],matrixData[5],matrixData[9],matrixData[13],
                matrixData[2],matrixData[6],matrixData[10],matrixData[14],
                matrixData[3],matrixData[7],matrixData[11],matrixData[15]);
}

}
