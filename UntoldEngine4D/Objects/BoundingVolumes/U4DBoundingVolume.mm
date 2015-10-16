//
//  U4DBoundingVolume.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/10/13.
//  Copyright (c) 2013 Untold Story Studio. All rights reserved.
//

#include "U4DBoundingVolume.h"
#include "U4DCamera.h"
#include "U4DDirector.h"
#include "U4DMatrix4n.h"
#include "U4DMatrix3n.h"
#import <GLKit/GLKit.h>

namespace U4DEngine {
    
    void U4DBoundingVolume::setGeometry(){

        openGlManager->loadRenderingInformation();
    }

    void U4DBoundingVolume::draw(){
     
        openGlManager->draw();
    }

    void U4DBoundingVolume::setGeometryColor(U4DVector4n& uColor){
        
        updateUniforms("Color", uColor);
        
    }

    void U4DBoundingVolume::setBoundingType(BOUNDINGTYPE uType){
        
        boundingType=uType;
    }

    BOUNDINGTYPE U4DBoundingVolume::getBoundingType(){
        
        return boundingType;
    }
    
    U4DPoint3n U4DBoundingVolume::getSupportPointInDirection(U4DVector3n& uDirection){
        
        int index=0;
        
        
        std::vector<U4DVector3n> tempPolygonVertices;
        
        //copy polygon vertices into a temp container
        tempPolygonVertices=bodyCoordinates.verticesContainer;
        
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
    
    int U4DBoundingVolume::determineRenderingIndex(std::vector<U4DVector3n>& uVertices, U4DVector3n& uVector, U4DVector3n& uDirection){
     
        
        float dotProduct=FLT_MAX;
        float support=0.0;
        int index=0;
        
        //determine the minimum dot product in direction of vector
        
        for(int i=0;i<uVertices.size();i++){
            
            U4DVector3n vertex=uVertices.at(i);
            
            support=vertex.dot(uDirection);
            
            if(support<dotProduct){
                
                dotProduct=support;
                index=i;
            }
            
        }
        
        return index;
        
    }
    

}