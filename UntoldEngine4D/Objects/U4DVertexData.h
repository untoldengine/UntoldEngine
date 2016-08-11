//
//  U4DVertexData.h
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#ifndef __UntoldEngine__U4DVertexData__
#define __UntoldEngine__U4DVertexData__

#include <iostream>
#include <vector>
#include "U4DVector2n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DIndex.h"
#include "U4DSegment.h"
#include "U4DTriangle.h"
#include "U4DBoneIndices.h"

namespace U4DEngine {
    
    class U4DVertexData{
        
    private:
       
    public:
        
        U4DVertexData(){};
        ~U4DVertexData(){};
      
        std::vector<U4DVector3n> verticesContainer;
        std::vector<U4DVector3n> normalContainer;
        std::vector<U4DVector2n> uVContainer;
        std::vector<U4DVector4n> tangentContainer;
        std::vector<U4DIndex> indexContainer;
        std::vector<U4DVector3n> convexHullVerticesContainer;
        std::vector<U4DVector4n> vertexWeightsContainer;
        std::vector<U4DVector4n> boneIndicesContainer;
        std::vector<U4DSegment> convexHullEdgesContainer;
        std::vector<U4DTriangle> convexHullFacesContainer;
        std::vector<U4DVector3n> preConvexHullVerticesContainer;
        U4DVector3n modelDimension;
        
        void addVerticesDataToContainer(U4DVector3n& uData);
        void addNormalDataToContainer(U4DVector3n& uData);
        void addUVDataToContainer(U4DVector2n& uData);
        void addTangetDataToContainer(U4DVector4n& uData);
        void addIndexDataToContainer(U4DIndex& uData);
        void addConvexHullVerticesToContainer(U4DVector3n& uData);
        void addVertexWeightsToContainer(U4DVector4n& uData);
        void addBoneIndicesToContainer(U4DVector4n& uData);
        void addConvexHullEdgesDataToContainer(U4DSegment& uData);
        void addConvexHullFacesDataToContainer(U4DTriangle& uData);
        void addPreConvexHullVerticesDataToContainer(U4DVector3n& uData);
        void setModelDimension(U4DVector3n& uData);
        
        std::vector<U4DVector3n> getVerticesDataFromContainer();
        std::vector<U4DVector3n> getConvexHullVerticesFromContainer();
        std::vector<U4DSegment> getConvexHullEdgesDataFromContainer();
        std::vector<U4DTriangle> getConvexHullFacesDataFromContainer();
        std::vector<U4DVector3n> getPreConvexHullVerticesDataFromContainer();
        U4DVector3n getModelDimension();
    };
    
}

#endif /* defined(__UntoldEngine__U4DVertexData__) */
