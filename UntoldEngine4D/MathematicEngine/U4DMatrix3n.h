//
//  U4DMatrix3n.h
//  MathLibrary
//
//  Created by Harold Serrano on 5/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DMatrix3n__
#define __MathLibrary__U4DMatrix3n__

#include <iostream>

namespace U4DEngine {
class U4DVector3n;
class U4DQuaternion;
}

namespace U4DEngine {

/**
 *  Class in charge of 3N matrix
 */
class U4DMatrix3n{

private:
    
public:
    
    /**
     *  Matrix data elements
     */
    float matrixData[9]={0};
    
    /**
     *  Constructor
     */
    U4DMatrix3n(){
        
        // 3x3 matrix - column major. X vector is 0, 1, 2, etc. (openGL prefer way)
        //	0	3	6	
        //	1	4	7	
        //	2	5	8	
      
        
        for (int i=0; i<9; i++) {
            matrixData[i]=0.0f;
        }
        
        matrixData[0]=matrixData[4]=matrixData[8]=1.0f;
        
    };
    
    /**
     *  Constructor
     */
    U4DMatrix3n(float m0,float m3,float m6,float m1,float m4,float m7,float m2,float m5,float m8){
    
        matrixData[0]=m0;
        matrixData[3]=m3;
        matrixData[6]=m6;
        
        matrixData[1]=m1;
        matrixData[4]=m4;
        matrixData[7]=m7;
        
        matrixData[2]=m2;
        matrixData[5]=m5;
        matrixData[8]=m8;
        
    };
    
    
    /**
     *  Copy Constructor
    */
    U4DMatrix3n& operator=(const U4DMatrix3n& value){
        
        for (int i=0; i<9; i++) {
            matrixData[i]=value.matrixData[i];
        }
        
        return *this;
    };
    
    /**
     *  Destructor
     */
    ~U4DMatrix3n(){}
    
    
    /**
     *  transform the given vector by this matrix
     *
     *  @param v Vector
     *
     *  @return new transform vector
     */
    U4DVector3n operator*(const U4DVector3n & v) const;
    
    /**
     *  transform the given vector by this matrix
     *
     *  @param v Vector
     *
     *  @return new transform vector
     */
    U4DVector3n transform(const U4DVector3n& v) const;
    
    /**
     *  Multiply matrix
     *
     *  @param m matrix
     *
     *  @return matrix product
     */
    U4DMatrix3n operator*(const U4DMatrix3n& m) const;
    
    /**
     *  Multiply matrix
     *
     *  @param m matrix
     */
    void operator*=(const U4DMatrix3n& m);
    
    /*!
     *  @brief  set matrix to identity
     */
    void setIdentity();
    
    /*!
     *  @brief  transform matrix about x axis
     *
     *  @param uAngle angle of rotation
     */
    void transformMatrixAboutXAxis(float uAngle);
    
    /*!
     *  @brief  transform matrix about y axis
     *
     *  @param uAngle angle of rotation
     */
    void transformMatrixAboutYAxis(float uAngle);
    
    /*!
     *  @brief  transform matrix about z axis
     *
     *  @param uAngle angle of rotation
     */
    void transformMatrixAboutZAxis(float uAngle);
    
    /**
     *  Set the matrix to be the inverse of the given matrix
     *
     *  @param m matrix
     */
    void setInverse(const U4DMatrix3n& m);
    
    /**
     *  returns a new matrix containing the inverse of the matrix
     *
     *  @return Matrix inverse
     */
    U4DMatrix3n inverse() const;
    
    /**
     *  Inverts the matrix
     */
    void invert();
    
    /**
     *  Gets matrix determinant
     *
     *  @return matrix determinant
     */
    float getDeterminant() const;
    
    /**
     *  Inverts and transpose the matrix
     */
    void invertAndTranspose();
    
    /**
     *  Set the matrix as the transpose of the given matrix
     *
     *  @param m matrix
     */
    void setTranspose(const U4DMatrix3n& m);
    
    /**
     *  Transpose the matrix
     *
     *  @return matrix transpose
     */
    U4DMatrix3n transpose() const;
    
    /**
     *  Set the matrix orientation
     *
     *  @param q quaternion
     */
    void setOrientation(const U4DQuaternion& q);
    
    U4DVector3n getFirstRowVector();
    
    U4DVector3n getSecondRowVector();
    
    U4DVector3n getThirdRowVector();
    
    U4DVector3n getFirstColumnVector();
    
    U4DVector3n getSecondColumnVector();
    
    U4DVector3n getThirdColumnVector();
    
    /**
     *  Debug, show the matrix in the console log
     */
    void show();
    
};

}

#endif /* defined(__MathLibrary__U4DMatrix3n__) */
