//
//  U4DBoundingBVH.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DBoundingBVH_hpp
#define U4DBoundingBVH_hpp

#include <stdio.h>
#include <cmath>
#include "U4DBoundingVolume.h"


namespace U4DEngine {
    
    /**
     @ingroup gameobjects
     @brief The U4DBoundingBVH represents an Boundary Volume Hierarchy bounding volumen entity
     */
    class U4DBoundingBVH:public U4DBoundingVolume{
      
    private:
        
        /**
         @brief number of aabbs in the bvh
         */
        int numberOfAABB;
        
    public:
        
        /**
         @brief Constructor of the class
         */
        U4DBoundingBVH();
        
        /**
         @brief Destructor of the class
         */
        ~U4DBoundingBVH();
       
        /**
         @brief Copy constructor
         */
        U4DBoundingBVH(const U4DBoundingBVH& value);
        
        /**
         @brief Copy constructor
         */
        U4DBoundingBVH& operator=(const U4DBoundingBVH& value);
        
        void computeBoundingVolume(std::vector<U4DPoint3n> &uMin,std::vector<U4DPoint3n> &uMax);
        
        void updateBoundingVolume(std::vector<U4DPoint3n> &uMin,std::vector<U4DPoint3n> &uMax);
        
        
    };

}
#endif /* U4DBoundingBVH_hpp */
