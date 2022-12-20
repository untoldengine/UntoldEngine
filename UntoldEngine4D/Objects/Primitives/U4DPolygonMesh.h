//
//  U4DPolygonMesh.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPolygonMesh_hpp
#define U4DPolygonMesh_hpp

#include <stdio.h>
#include "U4DMesh.h"
#include "U4DPoint3n.h"

namespace U4DEngine {

    class U4DPolygonMesh: public U4DMesh {
    
    private:
        
    
    public:
            
        
        U4DPolygonMesh();
        
        ~U4DPolygonMesh();
        
        void computePolygon(std::vector<U4DSegment> uSegments);
        
        void updateComputePolygon(std::vector<U4DSegment> uSegments);
    };

}
#endif /* U4DPolygonMesh_hpp */
