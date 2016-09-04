//
//  U4DQuaternion.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DQuaternion__
#define __MathLibrary__U4DQuaternion__

#include <iostream>


#include "U4DVector3n.h"
#include "U4DVector3n.h"
#include <cmath>

namespace U4DEngine {
class U4DVector3n;
class U4DMatrix4n;
class U4DMatrix3n;
}

namespace U4DEngine {

/**
 @brief The 4DQuaternion class is responsible for implementing Quaternion operations in the engine. These operations include: Quaternion addition,
 * subtraction, multiplication, normalization, etc.
 */
class U4DQuaternion{
    
public:
    
    /**
     @brief Scalar component of quaternion
     */
    float s;
    
    /**
     @brief Vector component of quaternion
     */
    U4DVector3n v;
    
    /**
     @brief Default Constructor which creates a quaternion
     */
    U4DQuaternion();
    
    /**
     @brief Quaternion constructor which creates a quaternion with given scalar and vector component
     */
    U4DQuaternion(float uS,U4DVector3n& uV);
    
    /**
     @brief Default quaternion destructor
     */
    ~U4DQuaternion();
    
    /**
     @brief Quaternion Copy Constructor
     
     @param value Quaternion to copy
     
     @return returns a copy of the quaternion
     */
    U4DQuaternion(const U4DQuaternion& value);
    
    /**
     @brief Quaternion Copy Constructor
     
     @param value Quaternion to copy
     
     @return returns a copy of the quaternion
     */
    U4DQuaternion& operator=(const U4DQuaternion& value);
    
    /**
     @brief Method which adds two quaternions
     
     @param q Quaternion to add
     
     @return Returns the addition result of the two quaternions
     */
    void operator+=(const U4DQuaternion& q);
    
    /**
     @brief Method which adds two quaternions
     
     @param q Quaternion to add
     
     @return Returns the addition result of the two quaternions
     */
    U4DQuaternion operator+(const U4DQuaternion& q)const;
    
    /**
     @brief Method which subtracts two quaternions
     
     @param q Quaternion to subtract
     
     @return Returns the subtraction difference of the two quaternions
     */
    void operator-=(const U4DQuaternion& q);
    
    /**
     @brief Method which subtracts two quaternions
     
     @param q Quaternion to subtract
     
     @return Returns the subtraction difference of the two quaternions
     */
    U4DQuaternion operator-(const U4DQuaternion& q)const;
    
    /**
     @brief Method which multiplies two quaternions
     
     @param q Quaternion to multiply
     
     @return Returns the multiplication of two quaternions
     */
    void operator*=(const U4DQuaternion& q);
    
    /**
     @brief Method which multiplies two quaternions
     
     @param q Quaternion to multiply
     
     @return Returns the multiplication of two quaternions
     */
    U4DQuaternion operator*(const U4DQuaternion& q)const;
    
    /**
     @brief Method which multiplies two quaternions
     
     @param q Quaternion to multiply
     
     @return Returns the multiplication of two quaternions
     */
    U4DQuaternion multiply(const U4DQuaternion& q)const;
    
    /**
     @brief Method which multiplies a quaternion times a 3D vector
     
     @param uValue 3D vector to multiply
     
     @return Returns the multiplication of the quaternion and vector
     */
    U4DQuaternion operator*(const U4DVector3n& uValue)const;
    
    /**
     @brief Method which computes the dot product between two quaternions
     
     @param q Quaternion to compute the dot product with
     
     @return Returns the dot product between the quaternions
     */
    float dot(U4DQuaternion& q);
    
    /**
     @brief Method which computes the multiplication between a quaternion and scalar
     
     @param value Scalar to multiply the quaternion
     
     @return Returns the multiplication result between the scalar and quaternion
     */
    void operator*=(const float value);

    /**
     @brief Method which computes the multiplication between a quaternion and scalar
     
     @param value Scalar to multiply the quaternion
     
     @return Returns the multiplication result between the scalar and quaternion
     */
    U4DQuaternion operator*(const float value)const;

    /**
     @brief Method which computes the norm of the quaternion
     
     @return Returns the norm of the quaternion
     */
    float norm();
    
    /**
     @brief Method which normalizes the quaternion
     */
    void normalize();
    
    /**
     @brief Method which computes the conjugate of the quaternion
     
     @return Returns the conjugate of the quaternion
     */
    U4DQuaternion conjugate();
    
    /**
     @brief Method which computes the inverse of the quaternion
     
     @return Returns the inverse of the quaternion
     */
    U4DQuaternion inverse();
    
    /**
     @brief Method which computes the inverse of the quaternion
     
     @param q Quaternion to compute the inverse
     */
    void inverse(U4DQuaternion& q);
    
    /**
     @brief Method which converts the quaternion into a Unit-Norm quaternion
     */
    void convertToUnitNormQuaternion();
    
    /**
     @brief Method that computes the 3x3 matrix representation of the quaternion
     
     @return Returns a 3x3 matrix representation of the quaternion
     */
    U4DMatrix3n transformQuaternionToMatrix3n();
    
    /**
     @brief Method that computes a quaternion representation from an Euler angle
     
     @param x The x component of the euler angle
     @param y The y component of the euler angle
     @param z The z component of the euler angle
     */
    void transformEulerAnglesToQuaternion(float x,float y, float z);
    
    /**
     @brief Method which computes a quaternion to its Euler angle representation
     
     @return Returns an Euler Angle representation of the quaternion
     */
    U4DVector3n transformQuaternionToEulerAngles();
    
    
    /**
     @brief Method that computes a quaternion from its 3x3 matrix representation
     
     @param uMatrix 3x3 matrix to convert
     */
    void transformMatrix3nToQuaternion(U4DMatrix3n &uMatrix);
    
    /**
     @brief Method that computes the slerp of a quaternion
     
     @param U4DQuaternion&q Quaternion to compute the slerp
     @param time            Time value
     
     @return Returns the slerp of the quaternion
     */
    U4DQuaternion slerp(U4DQuaternion&q, float time);
    
    /**
     @brief Method which prints the quaternion components to the window console log
     */
    void show();
    
};

}

#endif /* defined(__MathLibrary__U4DQuaternion__) */
