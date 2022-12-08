//
//  U4DPolygonMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/1/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPolygonMesh.h"
#include "U4DAABB.h"
#include "U4DRenderPolygon.h"

namespace U4DEngine {

    U4DPolygonMesh::U4DPolygonMesh(){
        setVisibility(true);
        setName("polygon");
        
        setEntityType(U4DEngine::PRIMITIVE);
        
        renderEntity=new U4DRenderPolygon(this);
        
        renderEntity->setPipelineForPass("geometrypipeline",U4DEngine::finalPass);
        
    }

    U4DPolygonMesh::~U4DPolygonMesh(){
        
    }

    void U4DPolygonMesh::computePolygon(std::vector<U4DSegment> uSegments){
        
        float height=2.0;
        
        for(int i=0;i<uSegments.size();i++){
            
            U4DVector3n v(uSegments[i].pointA.x,height,uSegments[i].pointA.y);
            U4DVector3n u(uSegments[i].pointB.x,height,uSegments[i].pointB.y);
            bodyCoordinates.addVerticesDataToContainer(v);
            bodyCoordinates.addVerticesDataToContainer(u);
        }
        
        for(int i=0; i<uSegments.size()-1;i++){
            float n=i*2;
            float m=n+2;
            float p=n+4;
            
            if(i==uSegments.size()-1) p=0;
            
            U4DIndex index(n,m,p);
            
            bodyCoordinates.addIndexDataToContainer(index);
            
        }
        
        loadRenderingInformation();
        U4DVector4n red(1.0,0.0,0.0,1.0);
        setLineColor(red);
    }

    void U4DPolygonMesh::updateComputePolygon(std::vector<U4DSegment> uSegments){
        
        float height=2.0;
        
        for(int i=0;i<uSegments.size();i++){
            
            U4DVector3n v(uSegments[i].pointA.x,height,uSegments[i].pointA.y);
            U4DVector3n u(uSegments[i].pointB.x,height,uSegments[i].pointB.y);
            bodyCoordinates.addVerticesDataToContainer(v);
            bodyCoordinates.addVerticesDataToContainer(u);
        }
        
        for(int i=0; i<uSegments.size()-1;i++){
            float n=i*2;
            float m=n+2;
            float p=n+4;
            
            if(i==uSegments.size()-1) p=0;
            
            U4DIndex index(n,m,p);
            
            bodyCoordinates.addIndexDataToContainer(index);
            
        }
        
        updateRenderingInformation();
    }
    
}
