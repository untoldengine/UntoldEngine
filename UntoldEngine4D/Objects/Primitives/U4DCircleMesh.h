//
//  U4DCircleMesh.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/12/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCircleMesh_hpp
#define U4DCircleMesh_hpp

#include <stdio.h>
#include "U4DMesh.h"
#include "U4DPoint3n.h"

namespace U4DEngine {

    class U4DCircleMesh: public U4DMesh {
    
    private:
        
        float radius;
    
    public:
        
        U4DCircleMesh();
        
        ~U4DCircleMesh();
        
        void setMeshData();
        
        void setCircle(float uRadius);
        
        void updateCircle(float uRadius);
        
    };

}

#endif /* U4DCircleMesh_hpp */
