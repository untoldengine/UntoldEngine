//
//  U4DPlaneMesh.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/19/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPlaneMesh_hpp
#define U4DPlaneMesh_hpp

#include <stdio.h>
#include "U4DMesh.h"
#include "U4DPoint3n.h"

namespace U4DEngine {

    class U4DPlaneMesh: public U4DMesh {
    
    private:
        
        
        
        float xScale;
        float yScale;
        float zScale;
    
    public:
            
        U4DPoint3n minPoint;
        
        U4DPoint3n maxPoint;
        
        U4DPlaneMesh();
        
        ~U4DPlaneMesh();
        
        void setMeshData();
        
        void computePlane();
        
        void updateComputePlane(float uScaleX, float uScaleY, float uScaleZ);
        
    };

}

#endif /* U4DPlaneMesh_hpp */
