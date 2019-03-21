//
//  U4DPolygonData.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/20/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#ifndef U4DPolygonData_hpp
#define U4DPolygonData_hpp

#include <stdio.h>
#include "U4DVector3n.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"

namespace U4DEngine {

    class U4DPolygonData {
       
    private:
        
    public:
        
        std::vector<U4DVector3n> verticesContainer;
        
        std::vector<U4DSegment> edgesContainer;
        
        std::vector<U4DTriangle> facesContainer;
        
        U4DPolygonData();
        
        ~U4DPolygonData();
        
        void addVertexToContainer(U4DVector3n& uVertex);
        
        void addEdgeToContainer(U4DSegment& uEdge);
        
        void addFaceToContainer(U4DTriangle& uFace);
        
        std::vector<U4DVector3n> getVerticesDataFromContainer();
        
        std::vector<U4DSegment> getEdgesDataFromContainer();
        
        std::vector<U4DTriangle> getFacesDataFromContainer();
        
    };
    
}

#endif /* U4DPolygonData_hpp */
