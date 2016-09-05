//
//  U4DVector3n.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/18/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DVector3n__
#define __MathLibrary__U4DVector3n__

#include <iostream>
#include "U4DMatrix3n.h"

namespace U4DEngine {
class U4DPoint3n;
class U4DQuaternion;
}

namespace U4DEngine {
    
/*!
 * @class U4DVector3n
 * @brief The U4DVector3n class is in charge of implementing 3D Linear Algebra Vector operations. These operations include: Addition, subtraction,
 * scalar multiplication, dot product, cross product, among others.
 */

class U4DVector3n{

private:
    
public:
    
    #pragma mark-Data Members
    
    /*!
     *  @brief  x vector component
     */
    float x;
    
    /*!
     *  @brief  y vector component
     */
    
    float y;
    
    /*!
     *  @brief  z vector component
     */
    
    float z;
    
    
    #pragma mark-constructors
    
    /**
     @brief  Constructor which creates a default 3D vector. That is, it creates a vector with x, y and z components equal to zero.
    
     */
    U4DVector3n();
    
    
    /**
     @brief  Constructor which creates a 3D vector with x,y, and z components.
     
     @param nx x component
     @param ny y component
     @param nz z component
     
     @return Constructs a vector with the given x,y and z components
     
     */
    U4DVector3n(float nx,float ny,float nz);
    
    /**
     @brief  Default destructor of a vector
     */
    ~U4DVector3n();
    
    #pragma mark-copy constructors
    
    /*!
     *  @brief  Copy Constructor for a 3D vector
     *
     *  @param  3D vector to copy
     *
     *  @return A copy of the 3D vector
     */
    U4DVector3n(const U4DVector3n& a);
    
    /*!
     *  @brief  Copy Constructor for 3D vector
     *
     *  @param  3D vector to copy
     *
     *  @return A copy of the 3D vector
     *
     */
    U4DVector3n& operator=(const U4DVector3n& a);
    
    #pragma mark-comparison
    /**
     @brief Operation to compare if two 3D vectors are equal
     
     @param a 3D vector to compare to
     
     @return Returs true if both vectors contain the same components
     */
    bool operator==(const U4DVector3n& a);
    
    
    #pragma mark-add
    
    /*!
     *  @brief  Calculates the addition of two vectors.
     *
     *  @param v Vector to add.
     *
     *  @return Returns the addition of two vectors.
     *
     */
    void operator+=(const U4DVector3n& v); //add vectors
    
    /*!
     *  @brief  Calculates the addition of two vectors.
     *
     *  @param v 3D vector to add
     *
     *  @return Returns a third vector representing the addition of two 3D vectors
     *
     */
    U4DVector3n operator+(const U4DVector3n& v)const; //add vectors
    
    #pragma mark-subraction
    
    /*!
     *  @brief  Calculates the subtraction of two vectors.
     *
     *  @param v 3D vector to subtract
     *
     *  @return Subtraction result of two vectors
     *
     */
    void operator-=(const U4DVector3n& v); //subtract vectors
    
    /*!
     *  @brief  Calculates the subtraction of two vectors.
     *
     *  @param v 3D vector to subtract
     *
     *  @return Returns a third vector representing the subtraction of two 3D vectors
     *
     */
   
    U4DVector3n operator-(const U4DVector3n& v)const; //subtract vectors
    
    #pragma mark-multiplication
    
    /*!
     *  @brief  Multiply vector by scalar
     *
     *  @param s Scalar
     *
     *  @return Product of multiplication
     *
     */
    void operator*=(const float s);
    
    /*!
     *  @brief  Multiply vector by scalar
     *
     *  @param s Scalar
     *
     *  @return Vector representing product
     *
     */
    U4DVector3n operator*(const float s)const;

    /*!
     *  @brief  Multiply vector by matrix
     *
     *  @param m Matrix
     *
     *  @return Vector representing product
     *
     */
    U4DVector3n operator*(const U4DMatrix3n& m)const;
    
    /*!
     *  @brief  Multiply vector by quaternion
     *
     *  @param q Quaternion
     *
     *  @return Quaternion representing product
     *
     */
    U4DQuaternion operator*(U4DQuaternion& q) const;

    #pragma mark-division
    
    /*!
     *  @brief  Division of vector by scalar
     *
     *  @param s Scalar
     *
     *  @return Quotient of division
     *
     */
    void operator /=(const float s);
  
    /*!
     *  @brief  Division of vector by scalar
     *
     *  @param s Scalar
     *
     *  @return Quotient of division
     *
     */
    U4DVector3n operator/(const float s)const;
    
    #pragma mark-dot product
    
    /*!
     *  @brief  Calculates dot product of two 3D vectors
     *
     *  @param v A 3D vector to compute the dot product with
     *
     *  @return Dot product result
     *
     */
    float operator*(const U4DVector3n& v) const;
    
    /*!
     *  @brief  Calculate dot product of two 3D vectors
     *
     *  @param v A 3D vector to compute the dot product with
     *
     *  @return Dot product result
     *
     */
    float dot(const U4DVector3n& v) const;

    /*!
     *  @brief  Calculates the angle between vectors
     *
     *  @param v A 3D vector to compute the dot product with
     *
     *  @return Returns the angle between vectors in degrees
     *
     */
    float angle(const U4DVector3n& v);
    
    #pragma mark-cross product
    
    /*!
     *  @brief  Calculates cross product of two vectors
     *
     *  @param v A 3D vector to compute the cross product with
     *
     *  @return Cross product result
     *
     */
    void operator %=(const U4DVector3n& v);
    
    /*!
     *  @brief  Calculate cross product
     *
     *  @param v A 3D vector to compute the cross product with
     *
     *  @return Cross product result
     *
     */
    U4DVector3n operator %(const U4DVector3n& v) const;
    
    /*!
     *  @brief  Calculate cross product
     *
     *  @param v A 3D vector to compute the cross product with
     *
     *  @return Cross product result
     *
     */
    
    U4DVector3n cross(const U4DVector3n& v) const;
    
    #pragma mark-utility Vector Methods
    
    /*!
     *  @brief  Method to conjugate a 3D vector
     *
     */
    void conjugate();
    
    /*!
     *  @brief  Method to normalize a 3D vector
     *
     */
    void normalize();
    
    /*!
     *  @brief  Method which calculates magnitude of a 3D vector
     *
     *  @return Magnitude value
     *
     */
    
    float magnitude();
    
    /*!
     *  @brief  Method which calculates the magnitude square of vector
     *
     *  @return Magnitude squared value
     *
     */
    float magnitudeSquare();
    
    /*!
     *  @brief  Method to convert 3D vector to a 3D point
     *
     *  @return 3D point representation of a 3D vector
     *
     */
    U4DPoint3n toPoint();
    
    /*!
     *  @brief  Method to set the current 3D vector to a zero-value 3D vector. That is, it sets all its components to zero.
     *
     */
    void zero();
    
    /*!
     *  @brief  Method which calculates absolute value of a 3D vector
     *
     */
    void absolute();
    
    /**
     @brief Method which rotates the 3D vector about an axis by the specified angle amount
     
     @param uAngle Angle in degrees to rotate
     @param uAxis  Axis to rotate vector about
     
     @return Rotation of the vector about a given axis by the angle amount
     */
    U4DVector3n rotateVectorAboutAngleAndAxis(float uAngle, U4DVector3n& uAxis);
    
    /**
     @brief Method which computes the Orthonormal Basis of the 3D vector given two tangential 3D vectors
     
     @param uTangent1 Tangential 3D Vector
     @param uTangent2 Tangential 3D Vector
     */
    void computeOrthonormalBasis(U4DVector3n& uTangent1, U4DVector3n& uTangent2);
    
    /**
     @brief Method which negates the 3D vector components of the vector.
     */
    void negate();
    
    #pragma mark-get components methods
    /*!
     *  @brief  returns the x component of the vector
     *
     *  @return x-component of vector
     */
    float getX();
    
    /*!
     *  @brief  returns the y component of the vector
     *
     *  @return y-component of vector
     */
    float getY();
    
    /*!
     *  @brief  returns the z component of the vector
     *
     *  @return z-component of vector
     */
    float getZ();
    
    #pragma mark-Print Methods
    /*!
     *  @brief  Method which prints the components value of the 3D vector to the console log window
     *
     */
    void show();
    
    /**
     @brief Method which prints the components value of the 3D vector to the console log window with a user message
     
     @param uString Message to pring along with the vector components
     */
    void show(std::string uString);
    
    
};

}

#endif /* defined(__MathLibrary__U4DVector3n__) */
