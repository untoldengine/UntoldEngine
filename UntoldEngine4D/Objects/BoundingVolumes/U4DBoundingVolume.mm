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
    
    
    U4DBoundingVolume::U4DBoundingVolume(){
        
        openGlManager=new U4DOpenGLGeometry(this);
        openGlManager->setShader("geometricShader");
        
        U4DVector4n color(1.0,0.0,0.0,1.0);
        addCustomUniform("Color", color);
    };
    
    
    U4DBoundingVolume::~U4DBoundingVolume(){};
    
    
    U4DBoundingVolume::U4DBoundingVolume(const U4DBoundingVolume& value){};
    
    
    U4DBoundingVolume& U4DBoundingVolume::operator=(const U4DBoundingVolume& value){
        
        return *this;
        
    };
    
    void U4DBoundingVolume::loadRenderingInformation(){

        openGlManager->loadRenderingInformation();
    }

    void U4DBoundingVolume::draw(){
     
        openGlManager->draw();
    }

    void U4DBoundingVolume::setBoundingVolumeColor(U4DVector4n& uColor){
        
        updateUniforms("Color", uColor);
        
    }

    void U4DBoundingVolume::setBoundingType(BOUNDINGTYPE uType){
        
        boundingType=uType;
    }

    BOUNDINGTYPE U4DBoundingVolume::getBoundingType(){
        
        return boundingType;
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