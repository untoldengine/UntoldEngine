//
//  U4DConvexPolygon.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 8/15/15.
//  Copyright (c) 2015 Untold Game Studio. All rights reserved.
//

#include "U4DConvexPolygon.h"


namespace U4DEngine {
    
    U4DConvexPolygon::U4DConvexPolygon(){
        
    }
    
    U4DConvexPolygon::~U4DConvexPolygon(){
        
    }
    
    void U4DConvexPolygon::setVerticesInConvexPolygon(std::vector<U4DVector3n> uPolygonVertices){
        
        polygonVertices=uPolygonVertices;
        
    }
    
    std::vector<U4DVector3n> U4DConvexPolygon::getVerticesInConvexPolygon(){
        
        return polygonVertices;
    }

    U4DPoint3n U4DConvexPolygon::getSupportPointInDirection(U4DVector3n& uDirection){
        
        int index=0;
        
        std::vector<U4DVector3n> tempPolygonVertices;
        
        //copy polygon vertices into a temp container
        tempPolygonVertices=polygonVertices;
        
        //update the vertices with the orientation and translation
        for (auto& vertex:tempPolygonVertices) {
            
            vertex=orientation*vertex;
            vertex=vertex+center;
            
        }
        
        float dotProduct=tempPolygonVertices.at(0).dot(uDirection);
        float support=0.0;
        
        //return the max dot product as the supporting vertex
        for(int i=1;i<tempPolygonVertices.size();i++){
            
            U4DVector3n vertex=tempPolygonVertices.at(i);
            
            support=vertex.dot(uDirection);
            
            if(support>=dotProduct){
                
                dotProduct=support;
                index=i;
            }
            
        }
        
        U4DVector3n supportVector=tempPolygonVertices.at(index);
        
        return supportVector.toPoint();
        
    }

    
}