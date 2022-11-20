//
//  U4DConvexHullMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/10/15.
//  Copyright © 2015 Untold Engine Studios. All rights reserved.
//

#include "U4DConvexHullMesh.h"
#include <float.h>

namespace U4DEngine {
    
    U4DConvexHullMesh::U4DConvexHullMesh(){
    
    }
    
    U4DConvexHullMesh::~U4DConvexHullMesh(){
        
        bodyCoordinates.convexHullVerticesContainer.clear();
        bodyCoordinates.convexHullEdgesContainer.clear();
        bodyCoordinates.convexHullFacesContainer.clear();
        
    }
    
    U4DConvexHullMesh::U4DConvexHullMesh(const U4DConvexHullMesh& value){
    
    }
    
    U4DConvexHullMesh& U4DConvexHullMesh::operator=(const U4DConvexHullMesh& value){
        
        return *this;
    
    }
    
    
    void U4DConvexHullMesh::setConvexHullVertices(CONVEXHULL &uConvexHull){
        
        
        //decompose the convex hull into vertices
        for(const auto& n:uConvexHull.vertex){
            
            U4DVector3n vertex=n.vertex;
            
            bodyCoordinates.addConvexHullVerticesToContainer(vertex);
            
        }
        
        //set vertices for rendering
        for (const auto& n:uConvexHull.faces) {
            
            U4DVector3n vertexA=n.triangle.pointA.toVector();
            U4DVector3n vertexB=n.triangle.pointB.toVector();
            U4DVector3n vertexC=n.triangle.pointC.toVector();
            
            bodyCoordinates.addVerticesDataToContainer(vertexA);
            bodyCoordinates.addVerticesDataToContainer(vertexB);
            bodyCoordinates.addVerticesDataToContainer(vertexC);
            
            
        }
        
        //set index for rendering
        for(int i=0;i<uConvexHull.faces.size()*3;){
            
            U4DIndex indexData(i,i+1,i+2);
            bodyCoordinates.addIndexDataToContainer(indexData);
            i=i+3;
        }
        
        //load rendering information
        loadRenderingInformation();
        
        
    }

    std::vector<U4DVector3n> U4DConvexHullMesh::getConvexHullVertices(){
        
        return bodyCoordinates.getConvexHullVerticesFromContainer();
    }
    
    U4DPoint3n U4DConvexHullMesh::getSupportPointInDirection(U4DVector3n& uDirection){
        
        int index=0;
        float dotProduct=-FLT_MAX;
        float support=0.0;
        
        U4DMatrix3n B=getAbsoluteMatrixOrientation();
        U4DMatrix3n BTranspose=B.transpose();
        
        U4DVector3n d=uDirection;
        d=BTranspose*d;
        
        std::vector<U4DVector3n> tempPolygonVertices;
        
        //copy polygon vertices into a temp container
        tempPolygonVertices=bodyCoordinates.convexHullVerticesContainer;
        
        //return the max dot product as the supporting vertex
        for(int i=0;i<tempPolygonVertices.size();i++){
            
            U4DVector3n vertex=tempPolygonVertices.at(i);
            
            support=vertex.dot(d);
            
            if(support>dotProduct){
                
                dotProduct=support;
                index=i;
            }
            
        }
        
        U4DVector3n supportVector=tempPolygonVertices.at(index);
        
        supportVector=B*supportVector+getAbsolutePosition();
        
        return supportVector.toPoint();
        
    }
}
