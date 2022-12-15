//
//  U4DCircleMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/12/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DCircleMesh.h"
#include "Constants.h"
#include "U4DRenderPolygon.h"

namespace U4DEngine {

    U4DCircleMesh::U4DCircleMesh():radius(1.0){
        setVisibility(true);
        setName("circle");
        
//        setEntityType(U4DEngine::PRIMITIVE);
//
//        renderEntity=new U4DRenderPolygon(this);
//
//        renderEntity->setPipelineForPass("geometrypipeline",U4DEngine::finalPass);
        
    }

    U4DCircleMesh::~U4DCircleMesh(){
       
    }

    void U4DCircleMesh::setMeshData(){

        int segment=300;
        
        for (int i=0; i<=segment; i++) {
            
            float angle=2*U4DEngine::PI*i/segment;
            float x=std::cos(angle)*radius;
            float y=std::sin(angle)*radius;
            
            U4DVector3n vec(x,0.0,y);
            
            bodyCoordinates.addVerticesDataToContainer(vec);
            
        }
        
        for(int i=0; i<=segment-1;i++){
            float n=i;
            float m=n+1;
            float p=n+2;
            
            if(i==segment-1){
                n=0;
                m=1;
                p=2;
            }
            
            U4DIndex index(n,m,p);
            
            bodyCoordinates.addIndexDataToContainer(index);
            
        }
    }

    void U4DCircleMesh::setCircle(float uRadius){
        radius=uRadius;
        
        setMeshData();
        loadRenderingInformation();
    }

    void U4DCircleMesh::updateCircle(float uRadius){
        
        radius=uRadius;
        setMeshData();
        updateRenderingInformation();
    }

}
