//
//  U4DVector4n.h
//  UntoldEngine
//
//  Created by Harold Serrano on 5/22/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVector4n__
#define __UntoldEngine__U4DVector4n__

#include <iostream>

namespace U4DEngine {
    
/**
 @brief The U4DVector4n class represents a 4D vector in space. Note: This class does not perform any linear algebra operations. It simply serves as a representation and is used as a helper in class.
 */
    
class U4DVector4n{
    
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
     @brief z-component
     */
    float z;
    
    /**
     @brief w-component
     */
    float w;
    
    /**
     @brief Constructor which creates a default 4D vector. That is, it creates a 4D vector with x, y, z and w components equal to zero.
     */
    U4DVector4n();
    
    /**
     @brief Constructor which creates a 4D vector with x, y, z and w components
     
     @param nx x component
     @param ny y component
     @param nz z component
     @param nw w component
     
     @return Constructs a vector with the given x,y, z and w components
     */
    U4DVector4n(float nx,float ny,float nz,float nw);
    
    /**
     @brief Default destructor for a 4D vector
     */
    ~U4DVector4n();
    
    /**
     @brief Copy constructor
     
     @param a 4D vector to copy
     
     @return A copy of the 4D vector
     */
    U4DVector4n(const U4DVector4n& a);
    
    /**
     @brief Copy constructor
     
     @param a 4D vector to copy
     
     @return A copy of the 4D vector
     */
    U4DVector4n& operator=(const U4DVector4n& a);
    
    /**
     @brief Method that calculates the dot product between two 4D vectors
     
     @param v A 4D vector to compute the dot product with
     
     @return Returns the dot product between two 4D vectors
     */
    float dot(const U4DVector4n& v) const;
    
    /**
     @brief Method which prints the components of the 4D vector
     */
    void show();
    
    /**
     @brief Method to get the x component value of the vector
     
     @return returns the x-component value
     */
    float getX();
    
    /**
     @brief Method to get the y component value of the vector
     
     @return returns the y-component value
     */
    float getY();
    
    /**
     @brief Method to get the z component value of the vector
     
     @return returns the z-component value
     */
    float getZ();
    
    /**
     @brief Method to get the y component value of the vector
     
     @return returns the w-component value
     */
    float getW();
    
};
    
}

#endif /* defined(__UntoldEngine__U4DVector4n__) */
