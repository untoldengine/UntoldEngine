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
 *  Class in charge of quaternions
 */
class U4DQuaternion{
    
public:
    
    /**
     *  Scalar
     */
    float s;
    
    /**
     *  Vector
     */
    U4DVector3n v;
    
    /**
     *  Constructor
     */
    U4DQuaternion(){};
    
    /**
     *  Constructor
     */
    U4DQuaternion(float uS,U4DVector3n& uV):s(uS),v(uV){}
    
    
    /**
     *  Destructor
     */
    ~U4DQuaternion(){};
    
    /**
     *  Copy Constructor
     */
    U4DQuaternion(const U4DQuaternion & value){
    
        s=value.s;
        v=value.v;
        
    };
    
    /**
     *  Copy Constructor
     */
    inline U4DQuaternion& operator=(const U4DQuaternion& value){
        
        s=value.s;
        v=value.v;
        
        return *this;
    };
    
    
    void operator+=(const U4DQuaternion& q);
    
    
    U4DQuaternion operator+(const U4DQuaternion& q)const;
    
    
    void operator-=(const U4DQuaternion& q);
    
    
    U4DQuaternion operator-(const U4DQuaternion& q)const;
    
    
    void operator*=(const U4DQuaternion& q);
    
    
    U4DQuaternion operator*(const U4DQuaternion& q)const;
    
   
    U4DQuaternion multiply(const U4DQuaternion& q)const;
    
   
    U4DQuaternion operator*(const U4DVector3n& uValue)const;
    
    
    float dot(U4DQuaternion& q);
    
    void operator*=(const float value);
    
    U4DQuaternion operator*(const float value)const;

    float norm();
    
    void normalize();
    
    U4DQuaternion conjugate();
    
    U4DQuaternion inverse();
    
    void inverse(U4DQuaternion& q);
    
    void convertToUnitNormQuaternion();
    
    U4DMatrix3n transformQuaternionToMatrix3n();
    
    void transformEulerAnglesToQuaternion(float x,float y, float z);
    
    U4DVector3n transformQuaternionToEulerAngles();

    void transformMatrix3nToQuaternion(U4DMatrix3n &uMatrix);
    
    U4DQuaternion slerp(U4DQuaternion&q, float time);
    
    void show();
    
};

}

#endif /* defined(__MathLibrary__U4DQuaternion__) */
