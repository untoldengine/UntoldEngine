//
//  U4DIndex.h
//  UntoldEngine
//
//  Created by Harold Serrano on 7/13/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DIndex__
#define __UntoldEngine__U4DIndex__

#include <iostream>

namespace U4DEngine {
    
/**
 @brief The U4DIndex class implements a 3D integer-only index class. It is mainly used for organizational purposes. It does not implement any computational operations.
 */

class U4DIndex{
  
private:
    
public:
    
    /**
     @brief x-component index
     */
    int x;
    
    /**
     @brief y-component index
     */
    int y;
    
    /**
     @brief z-component index
     */
    int z;
    
    /**
     @brief Constructor which creates a 3D index with its components equal to zero.
     */
    U4DIndex();
    
    /**
     @brief Constructor which creates a 3D index with the given x, y and z components.
     */
    U4DIndex(int nx,int ny,int nz);
    
    /**
     @brief Destructor for the 3D index
     */
    ~U4DIndex();
    
    /**
     @brief Copy constructor for the class
     */
    U4DIndex(const U4DIndex& a);
    
    /**
     @brief Copy constructor for the class
     
     @param a 3D index to copy
     
     @return Returns a copy of the 3D index
     */
    U4DIndex& operator=(const U4DIndex& a);
    
    /**
     @brief Prints the 3D index components to the console log window
     */
    void show();
    
};
    
}
#endif /* defined(__UntoldEngine__U4DIndex__) */
