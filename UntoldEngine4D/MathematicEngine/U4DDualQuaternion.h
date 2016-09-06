//
//  U4DU4DDualQuaternion.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __MathLibrary__U4DDualQuaternion__
#define __MathLibrary__U4DDualQuaternion__

#include <iostream>
#include "U4DQuaternion.h"
#include "U4DVector3n.h"


namespace U4DEngine {
 
/**
 @brief The U4DDualQuaternion class implements a Dual-Quaternion mathematical entity used for storing rotation and translations as real and pure quaternions, respectively.
 */
class U4DDualQuaternion{

public:
    
    /**
     @brief real part of dual quaternion. This quaternion represents Orientation
     */
    U4DQuaternion qReal;
    
    /**
     @brief pure part of dual quaternion- This quaternion represents Translation
     */
    U4DQuaternion qPure;
    
    /**
     @brief Dual quaternion constructor. The constructor creates a Real and a Pure Quaternion used for rotation and translation
     */
    U4DDualQuaternion();
    
    /**
     @brief Dual quaternion constructor which constructs a dualquaternion from a quaternion and a 3D vector
     */
    U4DDualQuaternion(const U4DQuaternion &q,U4DVector3n& v);
    
    /**
     @brief Dual quaternion constructor that constructs a dualquaternion from two quaternions representing rotation and translation, respectively.
     */
    U4DDualQuaternion(const U4DQuaternion &q,U4DQuaternion& v);
    
    /**
     @brief Copy constructor for a dual quaternion
     */
    U4DDualQuaternion(const U4DDualQuaternion& value);
    
    /**
     @brief Copy constructor for a dual quaternion
     
     @param value Dualquaternion to copy
     
     @return Returns a copy of the dual quaternion
     */
    U4DDualQuaternion& operator=(const U4DDualQuaternion& value);
    
    /**
     @brief Dual quaternion destructor
     */
    ~U4DDualQuaternion();
    
    /**
     @brief Method to add two dual quaternions
     
     @param q Dual quaternion to add
     
     @return Returns the addition of two dual quaternions
     */
    void operator+=(const U4DDualQuaternion& q);
    
    /**
     @brief Method to add two dual quaternions
     
     @param q Dual quaternion to add
     
     @return Returns the addition of two dual quaternions
     */
    U4DDualQuaternion operator+(const U4DDualQuaternion& q)const;
   
    /**
     @brief Method to multiply two dual quaternions
     
     @param q Dual quaternion to multiply
     
     @return Returns the product of two dual quaternions
     */
    void operator*=(const U4DDualQuaternion& q);
    
    /**
     @brief Method to multiply two dual quaternions
     
     @param q Dual quaternion to multiply
     
     @return Returns the product of two dual quaternions
     */
    U4DDualQuaternion operator*(const U4DDualQuaternion& q)const;

    /**
     @brief Method to multiply two dual quaternions
     
     @param q Dual quaternion to multiply
     
     @return Returns the product of two dual quaternions
     */
    U4DDualQuaternion multiply(const U4DDualQuaternion& q)const;
    
    /**
     @brief Method to multiply a dual quaternion times a scalar value
     
     @param value Scalar value to multiply the dual quaternion
     
     @return Returns the product of a dual quaternion and a scalar
     */
    U4DDualQuaternion operator*(const float value);
    
    /**
     @brief Method which determines the dot product between two dual quaternions
     
     @param q Dual quaternion to find the dot product with
     
     @return Returns the dot product of the dual quaternions
     */
    float dot(U4DDualQuaternion& q);
    
    /**
     @brief Method to normalize the dual quaternions
     
     @return Normalizes the dual quaternion
     */
    U4DDualQuaternion normalize();
    
    /**
     @brief Method to conjugate the dual quaternion
     
     @return Conjugates the dual quaternion
     */
    U4DDualQuaternion conjugate();
    
    /**
     @brief Method to get the Real part of the dual quaternion. That is, it gets the quaternion that represents the orientation
     
     @return Returns the quaternion representing the orientation
     */
    U4DQuaternion getRealQuaternionPart();
    
    /**
     @brief Method to get the Pure part of the dual quaternion. That is, it gets the quaternion that represents translation
     
     @return Returns the quaternion representing translation
     */
    U4DQuaternion getPureQuaternionPart();
    
    /**
     @brief Method which transforms a Dual quaternion into its 4x4 matrix representation
     
     @return Returns a 4x4 matrix representation
     */
    U4DMatrix4n transformDualQuaternionToMatrix4n();
    
    /**
     @brief Method which transforms a 4x4 matrix into its dual quaternion representation
     
     @param uMatrix 4x4 matrix to use to compute the dual quaternion representation
     */
    void transformMatrix4nToDualQuaternion(U4DMatrix4n &uMatrix);
    
    /**
     @brief Method which sets the Real part of the dual quaternion
     
     @param uqReal Real part  of the Dual quaternion
     */
    void setRealQuaternionPart(U4DQuaternion &uqReal);
    
    /**
     @brief Method which sets the Pure part of the dual quaternion
     
     @param uqPure Pure part of the Dual quaternion
     */
    void setPureQuaternionPart(U4DQuaternion &uqPure);
    
    /**
     @brief Method which computes the sclerp between two dual quaternions
     
     @param uToDualQuaternion Dual quaternion to compute sclerp with
     @param t                 Scalar time value
     
     @return Returns the sclerp between the two dual quaternions
     */
    U4DDualQuaternion sclerp(U4DDualQuaternion& uToDualQuaternion,float t);
    
    /**
     @brief Method which prints the Real and Pure parts of the dual quaternion
     */
    void show();
    
};

}
#endif /* defined(__MathLibrary__U4DDualQuaternion__) */
