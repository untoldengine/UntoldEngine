//
//  U4DVector2n.h
//  UntoldEngine
//
//  Created by Harold Serrano on 8/11/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVector2n__
#define __UntoldEngine__U4DVector2n__

#include <iostream>

namespace U4DEngine {
    
/**
 @brief  The U4DVector2n class is in charge of implementing a 2D vector representation. The class contains several linear algebra operations such as addition, subtraction, scalar multiplication, dot product, etc.
 */
    
class U4DVector2n{
  
private:
    
public:
    
    /**
     @brief x-component
     */
    float x;
    
    /**
     @brief y-component
     */
    float y;
    
    /**
     @brief Constructor that creates a 2D vector with components equal to zero.
     */
    U4DVector2n();
    
    /**
     @brief Constructor that creates a 2D vector with given x and y components.
     */
    U4DVector2n(float uX,float uY);
    
    /**
     @brief Destructor of the class
     */
    ~U4DVector2n();
    
    /**
     @brief Copy constructor for the 2D vector class
     */
    U4DVector2n(const U4DVector2n& a);
    
    /**
     @brief Copy constructor for the 2D vector class
     
     @param a 2D vector to copy
     
     @return Returns a copy of the 2D vector
     */
    U4DVector2n& operator=(const U4DVector2n& a);
    
    /**
     @brief Method that adds two 2D vectors
     
     @param v 2D vector to add
     
     @return Returns the addition of two 2D vectors
     */
    void operator+=(const U4DVector2n& v);
    
    /**
     @brief Method that adds two 2D vectors
     
     @param v 2D vector to add
     
     @return Returns the addition of two 2D vectors
     */
    U4DVector2n operator+(const U4DVector2n& v)const;
    
    /**
     @brief Method that subtracts two 2D vectors
     
     @param v 2D vector to subract
     
     @return Returns the difference between two 2D vectors
     */
    void operator-=(const U4DVector2n& v);
    
    /**
     @brief Method that subtracts two 2D vectors
     
     @param v 2D vector to subract
     
     @return Returns the difference between two 2D vectors
     */
    U4DVector2n operator-(const U4DVector2n& v)const;
    
    /**
     @brief Method that multiplies a 2D vector by a scalar
     
     @param s Scalar value to multiply
     
     @return Returns the product of a 2D vector by a scalar
     */
    void operator*=(const float s);
    
    /**
     @brief Method that multiplies a 2D vector by a scalar
     
     @param s Scalar value to multiply
     
     @return Returns the product of a 2D vector by a scalar
     */
    U4DVector2n operator*(const float s)const;
    
    /**
     @brief Method that divides a 2D vector by a scalar
     
     @param s Scalar value to divide
     
     @return Returns the division of a 2D vector by a scalar
     */
    void operator /=(const float s);
    
    /**
     @brief Method that divides a 2D vector by a scalar
     
     @param s Scalar value to divide
     
     @return Returns the division of a 2D vector by a scalar
     */
    U4DVector2n operator/(const float s)const;
    
    /**
     @brief Method which computes the dot product between two 2D vectors
     
     @param v 2D vector to compute dot product with
     
     @return Returns the dot product between two 2D vectors
     */
    float operator*(const U4DVector2n& v) const;
    
    /**
     @brief Method which computes the dot product between two 2D vectors
     
     @param v 2D vector to compute dot product with
     
     @return Returns the dot product between two 2D vectors
     */
    float dot(const U4DVector2n& v) const;
    
    /**
     @brief Method which conjugates the 2D vector
     */
    void conjugate();

    /**
     @brief Method which normalized the 2D vector
     */
    void normalize();
    
    /**
     @brief Method which computes the magnitude (distance) of the 2D vector
     
     @return Returns the magnitude of the 2D vector
     */
    float magnitude();
    
    /**
     @brief Method which computes the square magnitude of the 2D vector
     
     @return Returns the square magnitude of the 2D vector. That is, it does not compute the square root of the magnitude
     */
    float squareMagnitude();
    
    /**
     @brief Method to set the current 2D vector to a zero-value 2D vector. That is, it sets all its components to zero.
     */
    void zero();
    
    /**
     @brief Method which prints the components value of the 2D vector to the console log window
     */
    void show();

};
    
}

#endif /* defined(__UntoldEngine__U4DVector2n__) */
