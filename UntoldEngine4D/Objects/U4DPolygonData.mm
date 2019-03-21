//
//  U4DPolygonData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 3/20/19.
//  Copyright © 2019 Untold Engine Studios. All rights reserved.
//

#include "U4DPolygonData.h"

namespace U4DEngine {
    
    U4DPolygonData::U4DPolygonData(){
        
    }
    
    U4DPolygonData::~U4DPolygonData(){
        
    }
    
    void U4DPolygonData::addVertexToContainer(U4DVector3n& uVertex){
        
        verticesContainer.push_back(uVertex);
    }
    
    void U4DPolygonData::addEdgeToContainer(U4DSegment& uEdge){
        
        edgesContainer.push_back(uEdge);
        
    }
    
    void U4DPolygonData::addFaceToContainer(U4DTriangle& uFace){
        
        facesContainer.push_back(uFace);
        
    }
    
    std::vector<U4DVector3n> U4DPolygonData::getVerticesDataFromContainer(){
        
        return verticesContainer;
    }
    
    std::vector<U4DSegment> U4DPolygonData::getEdgesDataFromContainer(){
        
        return edgesContainer;
    }
    
    std::vector<U4DTriangle> U4DPolygonData::getFacesDataFromContainer(){
        
        return facesContainer;
        
    }
    
}
