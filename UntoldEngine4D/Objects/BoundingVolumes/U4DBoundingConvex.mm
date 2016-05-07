//
//  U4DBoundingConvex.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Game Studio. All rights reserved.
//

#include "U4DBoundingConvex.h"


namespace U4DEngine {
    
    U4DBoundingConvex::U4DBoundingConvex(){
        
    }
    
    U4DBoundingConvex::~U4DBoundingConvex(){
    
    }
    
    U4DBoundingConvex::U4DBoundingConvex(const U4DBoundingConvex& value){
    
    }
    
    U4DBoundingConvex& U4DBoundingConvex::operator=(const U4DBoundingConvex& value){
        
        return *this;
    
    }
    
    
    void U4DBoundingConvex::setConvexHullVertices(std::vector<U4DVector3n>& uVertices){
        
        
        for (auto vertex:uVertices) {
            
            bodyCoordinates.addConvexHullDataToContainer(vertex);
            
        }
        
    }
    
    void U4DBoundingConvex::computeBoundingVolume(){
        
        U4DVector3n xDirection(1,0,0);
        U4DVector3n yDirection(0,1,0);
        U4DVector3n zDirection(0,0,1);
        
        int currentVertexIndex=0;
        
        std::vector<U4DVector3n> uVertices=bodyCoordinates.getConvexHullDataFromContainer();
        
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
        
        
        loadRenderingInformation();
        
    }

    std::vector<U4DVector3n> U4DBoundingConvex::getConvexHullVertices(){
        
        return bodyCoordinates.getConvexHullDataFromContainer();
    }
    
    U4DPoint3n U4DBoundingConvex::getSupportPointInDirection(U4DVector3n& uDirection){
        
        int index=0;
        
        std::vector<U4DVector3n> tempPolygonVertices;
        
        //copy polygon vertices into a temp container
        tempPolygonVertices=bodyCoordinates.convexHullContainer;
        
        //update the vertices with the orientation and translation
        for (auto& vertex:tempPolygonVertices) {
            
            vertex=getAbsoluteMatrixOrientation()*vertex;
            vertex=vertex+getAbsolutePosition();
            
        }
        
        float dotProduct=-FLT_MAX;
        float support=0.0;
        
        //return the max dot product as the supporting vertex
        for(int i=0;i<tempPolygonVertices.size();i++){
            
            U4DVector3n vertex=tempPolygonVertices.at(i);
            
            support=vertex.dot(uDirection);
            
            if(support>dotProduct){
                
                dotProduct=support;
                index=i;
            }
            
        }
        
        U4DVector3n supportVector=tempPolygonVertices.at(index);
        
        return supportVector.toPoint();
        
    }


}