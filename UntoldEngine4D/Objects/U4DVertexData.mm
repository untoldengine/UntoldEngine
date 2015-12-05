//
//  U4DVertexData.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 9/4/14.
//  Copyright (c) 2014 Untold Story Studio. All rights reserved.
//

#include "U4DVertexData.h"

namespace U4DEngine {
    
    void U4DVertexData::addVerticesDataToContainer(U4DVector3n& uData){
        
        verticesContainer.push_back(uData);
    }

    void U4DVertexData::addNormalDataToContainer(U4DVector3n& uData){
        
        normalContainer.push_back(uData);
    }

    void U4DVertexData::addUVDataToContainer(U4DVector2n& uData){
        
        uVContainer.push_back(uData);
    }

    void U4DVertexData::addTangetDataToContainer(U4DVector4n& uData){
        
        tangentContainer.push_back(uData);
    }

    void U4DVertexData::addIndexDataToContainer(U4DIndex& uData){
        
        indexContainer.push_back(uData);
    }

    void U4DVertexData::addVertexWeightsToContainer(U4DVector4n& uData){
        
        vertexWeightsContainer.push_back(uData);
        
    }

    void U4DVertexData::addBoneIndicesToContainer(U4DVector4n& uData){
        
        boneIndicesContainer.push_back(uData);
        
    }
    
    std::vector<U4DVector3n> U4DVertexData::getVerticesDataFromContainer(){
        
        return verticesContainer;
    
    }

}