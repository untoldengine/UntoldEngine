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
 @brief The U4DMatrix3n is in charge of implementing linear algebra matrix operations such as addition, subtraction, transformations, etc.
 */
class U4DMatrix3n{

private:
    
public:
    
    /**
     @brief component values of the 3x3 matrix
     */
    float matrixData[9]={0};
    
    /**
     @brief Constructor which creates a 3x3 default matrix. That is, it creates a 3x3 matrix
     */
    U4DMatrix3n();
    
    /**
     @brief Constructor which creates a 3x3 matrix with the given values
     */
    U4DMatrix3n(float m0,float m3,float m6,float m1,float m4,float m7,float m2,float m5,float m8);
    
    /**
     @brief Creates a copy of the 3x3 matrix
     
     @param value 3x3 matrix to copy
     
     @return Returns a copy of the 3x3 matrix
     */
    U4DMatrix3n& operator=(const U4DMatrix3n& value);
    
    /**
     @brief default 3x3 destructor
     */
    ~U4DMatrix3n();
    
    /**
     @brief Method which transforms the given vector by the matrix
     
     @param v 3D vector to transform
     
     @return Returns the transformation of the vector
     */
    U4DVector3n operator*(const U4DVector3n & v) const;
    
    /**
     @brief Method which transforms the given vector by the matrix
     
     @param v 3D vector to transform
     
     @return Returns the transformation of the vector
     */
    U4DVector3n transform(const U4DVector3n& v) const;
    
    /**
     @brief Method which multiplies two 3x3 matrices
     
     @param m Matrix to multiply with
     
     @return Returns the multiplication product between the two 3x3 matrices
     */
    U4DMatrix3n operator*(const U4DMatrix3n& m) const;
    
    /**
     @brief Method which multiplies two 3x3 matrices
     
     @param m Matrix to multiply with
     
     @return Returns the multiplication product between the two 3x3 matrices
     */
    void operator*=(const U4DMatrix3n& m);
    
    /**
     @brief Method which sets a 3x3 matrix to an identity 3x3 matrix
     */
    void setIdentity();
    
    /**
     @brief Method which transforms a matrix about the x-axis
     
     @param uAngle Angle to apply the rotation by
     */
    void transformMatrixAboutXAxis(float uAngle);
    
    /**
     @brief Method which transforms a matrix about the y-axis
     
     @param uAngle Angle to apply the rotation by
     */
    void transformMatrixAboutYAxis(float uAngle);
    
    /**
     @brief Method which transforms a matrix about the z-axis
     
     @param uAngle Angle to apply the rotation by
     */
    void transformMatrixAboutZAxis(float uAngle);
    
    /**
     @brief Method which sets current matrix with the inverse of the given matrix
     
     @param m 3x3 matrix to use as the inverse
     */
    void setInverse(const U4DMatrix3n& m);
    
    /**
     @brief Method which computes the inverse of the matrix
     
     @return Returns the inverse of the matrix
     */
    U4DMatrix3n inverse() const;
    
    /**
     @brief Method which sets the matrix to its inverse
     */
    void invert();
    
    /**
     @brief Method which computes the determinant of the 3x3 matrix
     
     @return Returns the determinant of the matrix
     */
    float getDeterminant() const;
    
    /**
     @brief Method that computes the inverse and transpose of the matrix
     */
    void invertAndTranspose();
    
    /**
     @brief Method that sets the current matrix to a transpose matrix
     
     @param m 3x3 Matrix to use as the transpose
     */
    void setTranspose(const U4DMatrix3n& m);
    
    /**
     @brief Method which returns the transpose of the matrix
     
     @return Returns the transpose of the matrix
     */
    U4DMatrix3n transpose() const;
    
    /**
     @brief Method to get the first row of the 3x3 matrix
     
     @return Returns the first row of the 3x3 matrix
     */
    U4DVector3n getFirstRowVector();
    
    /**
     @brief Method to get the second row of the 3x3 matrix
     
     @return Returns the second row of the 3x3 matrix
     */
    U4DVector3n getSecondRowVector();
    
    /**
     @brief Method to get the third row of the 3x3 matrix
     
     @return Returns the third row of the 3x3 matrix
     */
    U4DVector3n getThirdRowVector();
    
    /**
     @brief Method to get the first column of the 3x3 matrix
     
     @return Returns the first column of the 3x3 matrix
     */
    U4DVector3n getFirstColumnVector();
    
    /**
     @brief Method to get the second column of the 3x3 matrix
     
     @return Returns the second column of the 3x3 matrix
     */
    U4DVector3n getSecondColumnVector();
    
    /**
     @brief Method to get the third column of the 3x3 matrix
     
     @return Returns the third column of the 3x3 matrix
     */
    U4DVector3n getThirdColumnVector();
    
    /**
     @brief Method which prints the 3x3 matrix components in the window console log
     */
    void show();
    
};

}

#endif /* defined(__MathLibrary__U4DMatrix3n__) */
