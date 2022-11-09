//
//  U4DVoronoiPlane.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/29/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DVoronoiPlane.h"
#include "U4DVector4n.h"

namespace U4DEngine{

    U4DVoronoiPlane::U4DVoronoiPlane(){
        
    }

    U4DVoronoiPlane::~U4DVoronoiPlane(){
        
    }

    //init method. It loads all the rendering information among other things.
    bool U4DVoronoiPlane::init(const char* uModelName){
        
        if (loadModel(uModelName)) {
            
            setPipeline("voronoiPipeline");
            
            loadRenderingInformation();
            
            return true;
        }
        
        return false;
        
    }

    void U4DVoronoiPlane::update(double dt){
        
    }
    void U4DVoronoiPlane::shade(std::vector<U4DSegment> uSegments){

        int shaderIndex=0;
        U4DVector4n count(uSegments.size(),0.0,0.0,0.0);
        
        updateShaderParameterContainer(shaderIndex,count);
        
        shaderIndex++;
        
        for(int i=0;i<uSegments.size();i++){
            
            U4DVector4n line(uSegments[i].pointA.x,uSegments[i].pointA.y,uSegments[i].pointB.x,uSegments[i].pointB.y);
            
            updateShaderParameterContainer(shaderIndex, line);
            shaderIndex++;
        }
        
        
    }

}
