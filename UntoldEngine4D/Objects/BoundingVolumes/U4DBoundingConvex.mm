//
//  U4DBoundingConvex.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#include "U4DBoundingConvex.h"


namespace U4DEngine {
    
    void U4DBoundingConvex::computeConvexHullVertices(std::vector<U4DVector3n>& uVertices){
        
        for (auto vertex:uVertices) {
            
            //load vertices-THIS IS TEMPORARY VERTEX INFORMATION
            bodyCoordinates.addVerticesDataToContainer(vertex);
            
        }
        
    }
    
    void U4DBoundingConvex::initConvexHullRenderingVertices(){
        
        U4DVector3n xDirection(1,0,0);
        U4DVector3n yDirection(0,1,0);
        U4DVector3n zDirection(0,0,1);
        
        int currentVertexIndex=0;
        
        std::vector<U4DVector3n> uVertices=bodyCoordinates.getVerticesDataFromContainer();
        
        for (auto vertex:uVertices) {
            
             //Determine the index for drawing operation
             U4DIndex renderingIndex0(currentVertexIndex,determineRenderingIndex(uVertices, vertex, xDirection),currentVertexIndex);
             U4DIndex renderingIndex1(currentVertexIndex,determineRenderingIndex(uVertices, vertex, yDirection),currentVertexIndex);
             U4DIndex renderingIndex2(currentVertexIndex,determineRenderingIndex(uVertices, vertex, zDirection),currentVertexIndex);
             
             bodyCoordinates.addIndexDataToContainer(renderingIndex0);
             bodyCoordinates.addIndexDataToContainer(renderingIndex1);
             bodyCoordinates.addIndexDataToContainer(renderingIndex2);
             
             currentVertexIndex++;
            
        }
        
        
        setGeometry();
        
    }

    std::vector<U4DVector3n> U4DBoundingConvex::getConvexHullVertices(){
        
        return bodyCoordinates.getVerticesDataFromContainer();
    }


}