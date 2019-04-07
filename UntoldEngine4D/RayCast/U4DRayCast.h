//
//  U4DRayCast.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 4/1/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRayCast_hpp
#define U4DRayCast_hpp

#include <stdio.h>
#include <vector>
#include <cmath>
#include <float.h>
#include "U4DRay.h"
#include "U4DStaticModel.h"
#include "U4DTriangle.h"

namespace U4DEngine{
 
    /**
     @brief the U4DRayCast class test intersections between a ray and 3D objects
     */
    class U4DRayCast {
        
    private:
        
    public:
        
        /**
         @brief Ray Cast constructor
         */
        U4DRayCast();
        
        /**
         @brief Ray Cast destructor
         */
        ~U4DRayCast();
        
        /**
         @brief Tests intersection between a ray and a 3D model and returns the face (triangle) hit
         @param uRay Ray used for the intersection
         @param uModel 3D model to test intersection with ray. You must enable the mesh Manager on the model before using this method.
         @param uTriangle face (triangl) of the 3D model intersection with the ray
         @return face of 3d model intersecting with the given ray
         */
        bool hit(U4DRay &uRay,U4DStaticModel *uModel,U4DTriangle &uTriangle);
        
    };
    
}

#endif /* U4DRayCast_hpp */
