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
 *  Class in charge of 2N vector
 */
class U4DVector2n{
  
private:
    
public:
    
    /**
     *  x-component
     */
    float x;
    
    /**
     *  y-component
     */
    float y;
    
    /**
     *  Constructor
     */
    U4DVector2n(){};
    
    /**
     *  Constructor
     *
     *  @param uX     x-component
     *  @param uY     y-component
     */
    U4DVector2n(float uX,float uY):x(uX),y(uY){};
    
    /**
     *  Destructor
     */
    ~U4DVector2n(){};
    
    /**
     *  Copy constructor
     */
    U4DVector2n(const U4DVector2n& a):x(a.x),y(a.y){};
    
    /**
     *  Copy constructor
     */
    inline U4DVector2n& operator=(const U4DVector2n& a){
        x=a.x;
        y=a.y;
        return *this;
    };
    
    /**
     *  Vector addition
     *
     *  @param v vector
     */
    void operator+=(const U4DVector2n& v);
    
    /**
     *  Vector addition
     *
     *  @param v vector
     *
     *  @return vector addition
     */
    U4DVector2n operator+(const U4DVector2n& v)const;
    
    /**
     *  Vector subtraction
     *
     *  @param v vector
     */
    void operator-=(const U4DVector2n& v);
    
    /**
     *  Vector subtraction
     *
     *  @param v vector
     *
     *  @return vector subtraction
     */
    U4DVector2n operator-(const U4DVector2n& v)const;
    
    /**
     *  Multiply vector by scalar
     *
     *  @param s scalar
     */
    void operator*=(const float s);
    
    /**
     *  Multiply vector by scalar
     *
     *  @param s scalar
     *
     *  @return vector product
     */
    U4DVector2n operator*(const float s)const;
    
    /**
     *  Divide vector by scalar
     *
     *  @param s scalar
     */
    void operator /=(const float s);
    
    /**
     *  Divide vector by scalar
     *
     *  @param s scalar
     *
     *  @return vector division by scalar
     */
    U4DVector2n operator/(const float s)const;
    
    
    /**
     *  Dot product
     *
     *  @param v vector
     *
     *  @return dot product
     */
    float operator*(const U4DVector2n& v) const;
    
    /**
     *  Dot product
     *
     *  @param v vector
     *
     *  @return dot product
     */
    float dot(const U4DVector2n& v) const;
    
    /**
     *  Conjugate the vector
     */
    void conjugate();

    /**
     *  Normalize the vector
     */
    void normalize();
    
    /**
     *  Vector magnitude
     *
     *  @return vector magnitude
     */
    float magnitude();
    
    /**
     *  Vector squared magnitude
     *
     *  @return squared magnitude
     */
    float squareMagnitude();
    
    /**
     *  zero the vector
     */
    void zero();
    
    /**
     *  Debug-show the vector on the output log
     */
    void show();

};
    
}

#endif /* defined(__UntoldEngine__U4DVector2n__) */
