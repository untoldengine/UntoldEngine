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
 * @brief The U4DVector3n class implements all mathematical vector operations in 3-Dimensional space.
 */

class U4DVector3n{

private:
    
public:
    
    #pragma mark-constructors
    
    /**
     @brief  Constructor to create a 3D vector with zero vector components.
    
     */
    U4DVector3n(){
    
        x=0.0;
        y=0.0;
        z=0.0;
    };
    
    
    /**
     @brief  Constructor to create a 3D vector with x,y, and z components
     
     @param nx x component
     @param ny y component
     @param nz z component
     
     @return Creates a vector with the given x,y and z components
     
     */
    U4DVector3n(float nx,float ny,float nz):x(nx),y(ny),z(nz){};
    
    /**
     @brief  3D vector desctructor
     
     */
    ~U4DVector3n(){};
    
    #pragma mark-copy constructors
    
    /*!
     *  @brief  Copy constructor for 3D vector
     *
     *  @param a 3D vector to copy
     *
     *  @return Copies the values of the vector
     */
    U4DVector3n(const U4DVector3n& a):x(a.x),y(a.y),z(a.z){
    
    };
    
    /*!
     *  @brief  Copy constructor for 3D vector
     *
     *  @param a 3D vector to copy
     *
     *  @return Copies the values of the vector
     *
     */
    inline U4DVector3n& operator=(const U4DVector3n& a){
        
        x=a.x;
        y=a.y;
        z=a.z;
        
        return *this;
    
    };
    
    bool operator==(const U4DVector3n& a);
    
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
    
    #pragma mark-Methods
    
    #pragma mark-add
    
    /*!
     *  @brief  It calculates the addition of two vectors.
     *
     *  @param v Vector to add.
     *
     *  @return Resultant of two vectors.
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
     *  @brief  Calculate dot product
     *
     *  @param v Vector
     *
     *  @return Dot product result
     *
     */
    float operator*(const U4DVector3n& v) const;
    
    /*!
     *  @brief  Calculate dot product
     *
     *  @param v Vector
     *
     *  @return Dot product result
     *
     */
    float dot(const U4DVector3n& v) const;

    /*!
     *  @brief  Calculates the angle between vectors
     *
     *  @param v Vector
     *
     *  @return Returns the angle between vectors in degrees
     *
     */
    float angle(const U4DVector3n& v);
    
    #pragma mark-cross product
    
    /*!
     *  @brief  Calculate cross product
     *
     *  @param v Vector
     *
     *  @return Cross product result
     *
     */
    void operator %=(const U4DVector3n& v);
    
    /*!
     *  @brief  Calculate cross product
     *
     *  @param v Vector
     *
     *  @return Cross product result
     *
     */
    U4DVector3n operator %(const U4DVector3n& v) const;
    
    /*!
     *  @brief  Calculate cross product
     *
     *  @param v Vector
     *
     *  @return Cross product result
     *
     */
    
    U4DVector3n cross(const U4DVector3n& v) const;
    
    /*!
     *  @brief  Conjugate the vector
     *
     */
    void conjugate();
    
    /*!
     *  @brief  Normalize the vector
     *
     */
    void normalize();
    
    /*!
     *  @brief  Calculate magnitude of vector
     *
     *  @return Magnitude value
     *
     */
    
    float magnitude();
    
    /*!
     *  @brief  Calculate the magnitude square of vector
     *
     *  @return Magnitude squared value
     *
     */
    float magnitudeSquare();
    
    /*!
     *  @brief  Convert vector to point
     *
     *  @return Point representation of vector
     *
     */
    U4DPoint3n toPoint();
    
    /*!
     *  @brief  Convert vector to a zero vector
     *
     */
    void zero();
    
    /*!
     *  @brief  Calculate absolute value of vector
     *
     */
    void absolute();
    
    /*!
     *  @brief  Print vector components
     *
     */
    
    void show();
    
    void show(std::string uString);
    
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

    U4DVector3n rotateVectorAboutAngleAndAxis(float uAngle, U4DVector3n& uAxis);
    
    void computeOrthonormalBasis(U4DVector3n& uTangent1, U4DVector3n& uTangent2);
    
    //Negate all components
    void negate();
    
    
};

}

#endif /* defined(__MathLibrary__U4DVector3n__) */
