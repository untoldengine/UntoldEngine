//
//  U4DBoneIndices.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/21/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DBoneIndices__
#define __UntoldEngine__U4DBoneIndices__

#include <iostream>

namespace U4DEngine {
    
/**
 @brief The U4DBoneIndices class implements the indexes of bone-armature used in a 3D character animation. This class is only used for organizational purposes. It does not implement any mathematical operations.
 */
class U4DBoneIndices{
    
private:
    
public:
    
    /**
     @brief x-component
     */
    int x;
    
    /**
     @brief y-component
     */
    int y;
    
    /**
     @brief z-component
     */
    int z;
    
    /**
     @brief w-component
     */
    int w;
    
    /**
     @brief Constructor which creates a Bone-Index class with zero components.
     */
    U4DBoneIndices();
    
    /**
     @brief Constructor which creates a Bone-Index class with the given components.
     */
    U4DBoneIndices(int nx,int ny,int nz,int nw);
    
    /**
     @brief Destructor of the class
     */
    ~U4DBoneIndices();
    
    /**
     @brief Copy Constructor of the class
     */
    U4DBoneIndices(const U4DBoneIndices& a);
    
    /**
     @brief Copy Constructor of the class
     
     @param a Bone-Index object to copy
     
     @return Returns a copy of the Bone-Index object
     */
    U4DBoneIndices& operator=(const U4DBoneIndices& a);
    
    /**
     @brief Prints the Bone-Index components to the console log window
     */
    void show();
};

}

#endif /* defined(__UntoldEngine__U4DBoneIndices__) */
