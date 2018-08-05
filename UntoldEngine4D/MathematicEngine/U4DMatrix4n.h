//
//  U4DMatrix4n.h
//  MathLibrary
//
//  Created by Harold Serrano on 4/20/13.
//  Copyright (c) 2013 Untold Engine Studios. All rights reserved.
//

#ifndef __MathLibrary__U4DMatrix4n__
#define __MathLibrary__U4DMatrix4n__

#include <iostream>

namespace U4DEngine {
class U4DMatrix3n;
class U4DVector3n;
class U4DQuaternion;
}


namespace U4DEngine {

/**
 @brief The U4DMatrix4n class is in charge of implementing a representation of a 4x4 matrix. The class implements matrix operations such as addition, subtraction, transformation, inverse, transponse, etc.
 */
class U4DMatrix4n{
    
public:
    
    /**
     @brief Data elements of the 4x4 matrix. Note, the data elements are ordered in Column Major format.
     */
    float matrixData[16]={0};
    
    /**
     @brief Contructor which constructs a 4x4 identity matrix.
     */
    U4DMatrix4n();
    
    /**
     @brief Contructor which constructs a 4x4 matrix in column major format
     */
    U4DMatrix4n(float m0,float m4,float m8,float m12,float m1,float m5,float m9,float m13,float m2,float m6,float m10,float m14,float m3,float m7, float m11,float m15);
    
    /**
     @brief Copy constructor for a 4x4 matrix
     
     @param value 4x4 matrix to copy
     
     @return Returns a copy of the 4x4 matrix
     */
    U4DMatrix4n& operator=(const U4DMatrix4n& value);
    
    /**
     @brief Desctructor for the 4x4 matrix
     */
    ~U4DMatrix4n();
    
    /**
     @brief Method which multiplies two 4x4 matrices
     
     @param m 4x4 matrix to multiply
     
     @return Returns the product of two 4x4 matrices
     */
    U4DMatrix4n operator*(const U4DMatrix4n& m)const;
    
    /**
     @brief Method which multiplies two 4x4 matrices
     
     @param m 4x4 matrix to multiply
     
     @return Returns the product of two 4x4 matrices
     */
    U4DMatrix4n multiply(const U4DMatrix4n& m)const;
    
    /**
     @brief Method which multiplies two 4x4 matrices
     
     @param m 4x4 matrix to multiply
     
     @return Returns the product of two 4x4 matrices
     */
    void operator*=(const U4DMatrix4n& m);
    
    /**
     @brief Method which transforms a 3D vector by the 4x4 matrix
     
     @param v 3D vector to transform
     
     @return Returns the transformation of the 3D vector
     */
    U4DVector3n operator*(const U4DVector3n& v) const;
    
    /**
     @brief Method which transforms a 3D vector by the 4x4 matrix
     
     @param v 3D vector to transform
     
     @return Returns the transformation of the 3D vector
     */
    U4DVector3n transform(const U4DVector3n& v) const;
    
    /**
     @brief Method which gets the determinant of the 4x4 matrix
     
     @return Returns the determinant of the 4x4 matrix
     */
    float getDeterminant() const;
    
    /**
     @brief Method that sets the inverse of a 4x4 matrix
     
     @param m 4x4 matrix to compute its inverse and apply it to the current 4x4 matrix
     */
    void setInverse(const U4DMatrix4n& m);
    
    /**
     @brief Method that computes the inverse of a 4x4 matrix
     
     @return Returns the inverse representation of the 4x4 matrix
     */
    U4DMatrix4n inverse()const;
    
    /**
     @brief Inverts the 4x4 matrix
     */
    void invert();
    
    /**
     @brief Method that returns a 3x3 representation of the 4x4 matrix
     
     @return Returns the rotational part of the 4x4 matrix
     */
    U4DMatrix3n extract3x3Matrix();
    
    /**
     @todo document this
     */
    U4DVector3n extractAffineVector();
    
    /**
     @brief Method that sets the transpose to a 4x4 matrix
     
     @param m 4x4 matrix to compute its transpose and set it to the current 4x4 matrix
     */
    void setTranspose(const U4DMatrix4n& m);
    
    /**
     @brief Method that computes the transpose of a 4x4 matrix
     
     @return Returns the transpose representation of a 4x4 matrix
     */
    U4DMatrix4n transpose() const;
    
    /**
     @brief Method that prints the 4x4 matrix components to the console log window
     */
    void show();
    
};
    
}

#endif /* defined(__MathLibrary__U4DMatrix4n__) */
