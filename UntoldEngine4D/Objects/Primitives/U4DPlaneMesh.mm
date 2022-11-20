//
//  U4DPlaneMesh.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 11/19/22.
//  Copyright © 2022 Untold Engine Studios. All rights reserved.
//

#include "U4DPlaneMesh.h"

namespace U4DEngine {

    U4DPlaneMesh::U4DPlaneMesh():minPoint(-1.0,0.0,-1.0),maxPoint(1.0,0.0,1.0){
        setVisibility(true);
    }

    U4DPlaneMesh::~U4DPlaneMesh(){
        
    }

    void U4DPlaneMesh::computePlane(){
        
        float width=(std::abs(maxPoint.x-minPoint.x))/2.0;
        float height=0.0;
        float depth=(std::abs(maxPoint.z-minPoint.z))/2.0;
        
        U4DVector3n v1(width,height,depth);
        U4DVector3n v2(width,height,-depth);
        U4DVector3n v3(-width,height,-depth);
        U4DVector3n v4(-width,height,depth);
        
        U4DVector3n v5(width,-height,depth);
        U4DVector3n v6(width,-height,-depth);
        U4DVector3n v7(-width,-height,-depth);
        U4DVector3n v8(-width,-height,depth);
        
        U4DIndex i1(0,1,2);
        U4DIndex i2(2,3,0);
        U4DIndex i3(4,5,6);
        U4DIndex i4(6,7,4);
        
        U4DIndex i5(5,6,2);
        U4DIndex i6(2,3,7);
        U4DIndex i7(7,4,5);
        U4DIndex i8(5,1,0);
        
        bodyCoordinates.addVerticesDataToContainer(v1);
        bodyCoordinates.addVerticesDataToContainer(v2);
        bodyCoordinates.addVerticesDataToContainer(v3);
        bodyCoordinates.addVerticesDataToContainer(v4);
        
        bodyCoordinates.addVerticesDataToContainer(v5);
        bodyCoordinates.addVerticesDataToContainer(v6);
        bodyCoordinates.addVerticesDataToContainer(v7);
        bodyCoordinates.addVerticesDataToContainer(v8);
        
        bodyCoordinates.addIndexDataToContainer(i1);
        bodyCoordinates.addIndexDataToContainer(i2);
        bodyCoordinates.addIndexDataToContainer(i3);
        bodyCoordinates.addIndexDataToContainer(i4);
        
        bodyCoordinates.addIndexDataToContainer(i5);
        bodyCoordinates.addIndexDataToContainer(i6);
        bodyCoordinates.addIndexDataToContainer(i7);
        bodyCoordinates.addIndexDataToContainer(i8);
        
        loadRenderingInformation();
    }

}
